"""Compare fixed inference recipes on corrected validation; never deploy or use test images."""
import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image, ImageOps
from sklearn.metrics import classification_report, confusion_matrix
from torchvision import transforms

from train_corrected_classifier import build_model, write_json


def summarize(probabilities, truth, classes):
    predicted = probabilities.argmax(1)
    report = classification_report(truth, predicted, labels=list(range(len(classes))),
                                   target_names=classes, output_dict=True, zero_division=0)
    unknown = classes.index('unknown')
    accepted = (predicted != unknown) & (probabilities.max(1) >= .70)
    unknown_rows = truth == unknown
    return dict(accuracy=report['accuracy'], macro_f1=report['macro avg']['f1-score'],
                accepted_count=int(accepted.sum()),
                accepted_accuracy=float((predicted[accepted] == truth[accepted]).mean()) if accepted.any() else None,
                unknown_false_accepts=int((accepted & unknown_rows).sum()),
                unknown_count=int(unknown_rows.sum())), report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    config = json.loads((args.run / 'config.json').read_text())
    manifest = args.run / 'split_manifest.csv'
    assert hashlib.sha256(manifest.read_bytes()).hexdigest() == config['manifest_sha256']
    frame = pd.read_csv(manifest)
    assert frame.groupby('group')['split'].nunique().max() == 1
    frame = frame[frame.split == 'val'].reset_index(drop=True)
    source = Path(config['source']).resolve()
    path = args.run / 'efficientnet_b0_best.pth'
    state = torch.load(path, map_location='cpu', weights_only=True)
    classes = state['classes']
    assert classes == config['classes']
    assert all(classes[int(row.label)] == row.class_name for row in frame.itertuples())
    torch.set_num_threads(2)
    model, _, _ = build_model('efficientnet_b0', len(classes), pretrained=False)
    model.load_state_dict(state['model_state_dict'], strict=True)
    model.eval()
    normalize = transforms.Compose([transforms.ToTensor(), transforms.Normalize([.485,.456,.406],[.229,.224,.225])])
    center = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224), normalize])
    names = ['center', 'center_flip_average', 'center_full_average']
    scores = {name: [] for name in names}
    started = time.monotonic()
    with torch.inference_mode():
        for start in range(0, len(frame), 8):
            originals = []
            for row in frame.iloc[start:start+8].itertuples():
                image_path = (source / row.saved_path).resolve()
                assert image_path.is_relative_to(source)
                with Image.open(image_path) as image:
                    originals.append(ImageOps.exif_transpose(image).convert('RGB'))
            tensors = torch.stack([center(image) for image in originals])
            normal = model(tensors).softmax(1)
            flipped = model(tensors.flip(-1)).softmax(1)
            full = model(torch.stack([normalize(image.resize((224,224), Image.Resampling.BILINEAR)) for image in originals])).softmax(1)
            for name, values in zip(names, [normal, (normal+flipped)/2, (normal+full)/2]):
                scores[name].append(values.numpy())
            completed = min(start+8, len(frame))
            if start % 80 == 0 or completed == len(frame):
                write_json(args.output / 'status.json', dict(state='running',completed=completed,total=len(frame)))
                print(f'Validation {completed}/{len(frame)}', flush=True)
    truth = frame.label.to_numpy()
    summary = dict(split='val', images=len(frame), deployed=False, test_evaluated=False,
                   checkpoint_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                   manifest_sha256=config['manifest_sha256'], recipes={},
                   limitation='Selection on validation is not independent test evidence; no production replacement.')
    for name in names:
        probabilities = np.concatenate(scores[name])
        metrics, report = summarize(probabilities, truth, classes)
        summary['recipes'][name] = metrics
        write_json(args.output / f'{name}_per_class.json', report)
        pd.DataFrame(confusion_matrix(truth, probabilities.argmax(1), labels=list(range(len(classes)))),
                     index=classes, columns=classes).to_csv(args.output / f'{name}_confusion.csv')
        rows = frame[['sha256_rgb','saved_path','class_name','label']].copy()
        rows['prediction'] = [classes[i] for i in probabilities.argmax(1)]
        rows['confidence'] = probabilities.max(1)
        rows.to_csv(args.output / f'{name}_predictions.csv', index=False)
        np.save(args.output / f'{name}_probabilities.npy', probabilities)
    # Verify that the experiment reproduces the saved reference before comparing alternatives.
    assert abs(summary['recipes']['center']['macro_f1']-state['validation']['macro_f1']) < 1e-6
    baseline = summary['recipes']['center']
    eligible = [name for name in names[1:] if
                summary['recipes'][name]['macro_f1'] > baseline['macro_f1'] and
                summary['recipes'][name]['accuracy'] > baseline['accuracy'] and
                summary['recipes'][name]['unknown_false_accepts'] <= baseline['unknown_false_accepts']]
    summary['selected_candidate'] = max(eligible, key=lambda n: summary['recipes'][n]['macro_f1']) if eligible else 'center'
    summary['elapsed_seconds'] = time.monotonic()-started
    write_json(args.output / 'comparison.json', summary)
    write_json(args.output / 'status.json', dict(state='complete',completed=len(frame),total=len(frame)))
    print(json.dumps(summary,indent=2),flush=True)


if __name__ == '__main__':
    main()
