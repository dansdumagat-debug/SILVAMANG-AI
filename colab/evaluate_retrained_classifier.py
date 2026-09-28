"""Evaluate a validation-selected candidate and the previous checkpoint once."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageOps
import torch
from torchvision import models, transforms
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
from tqdm import tqdm


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True, type=Path)
    args = parser.parse_args()
    run = args.run.resolve()
    out = run / 'heldout_evaluation'
    if out.exists():
        raise RuntimeError(f'Evaluation directory already exists: {out}. Review it before rerunning.')
    config = json.loads((run / 'config.json').read_text())
    comparison = json.loads((run / 'validation_comparison.json').read_text())
    assert comparison['improved_validation_macro_f1'], 'Candidate was not selected by validation.'
    source = Path(config['source'])
    assert sha(source / 'split_manifest.csv') == config['manifest_sha256']
    classes = config['classes']
    frame = pd.read_csv(source / 'split_manifest.csv')
    assert frame.groupby('group')['split'].nunique().max() == 1
    frame = frame.loc[frame['split'] == 'test'].reset_index(drop=True)
    assert not frame.empty and not frame['sha256_rgb'].duplicated().any()
    transform = transforms.Compose([
        transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    torch.set_num_threads(2)
    networks, hashes = {}, {}
    for name, path in [('previous', source / 'efficientnet_b0_last.pth'),
                       ('candidate', run / 'efficientnet_b0_best.pth')]:
        checkpoint = torch.load(path, map_location='cpu', weights_only=True)
        assert checkpoint.get('classes', checkpoint.get('training_config', {}).get('classes')) == classes
        if name == 'previous':
            assert sha(path) == config['checkpoint_sha256']
        model = models.efficientnet_b0(weights=None)
        model.classifier[1] = torch.nn.Linear(1280, len(classes))
        model.load_state_dict(checkpoint['model_state_dict'], strict=True)
        model.eval()
        networks[name] = model
        hashes[name] = sha(path)
    predictions = {name: [] for name in networks}
    losses = dict.fromkeys(networks, 0.0)
    out.mkdir()
    with torch.inference_mode():
        for start in tqdm(range(0, len(frame), 8), desc='Held-out test, both models'):
            batch = frame.iloc[start:start+8]
            images = []
            for row in batch.itertuples():
                path = (source / row.saved_path).resolve()
                assert path.is_relative_to(source.resolve())
                with Image.open(path) as image:
                    images.append(transform(ImageOps.exif_transpose(image).convert('RGB')))
            tensor = torch.stack(images)
            labels = torch.tensor(batch['label'].tolist())
            for name, model in networks.items():
                logits = model(tensor)
                assert torch.isfinite(logits).all()
                losses[name] += torch.nn.functional.cross_entropy(logits, labels, reduction='sum').item()
                predictions[name].extend(logits.argmax(1).tolist())
    truth = frame['label'].tolist()
    summary = {'test_images': len(frame), 'manifest_sha256': config['manifest_sha256'],
               'checkpoint_sha256': hashes, 'deployed': False,
               'selection': 'Candidate selected using validation macro-F1 before this evaluation', 'models': {}}
    for name, predicted in predictions.items():
        summary['models'][name] = {
            'loss': losses[name] / len(truth),
            'accuracy': accuracy_score(truth, predicted),
            'macro_f1': f1_score(truth, predicted, labels=list(range(len(classes))), average='macro', zero_division=0),
        }
        report = classification_report(truth, predicted, labels=list(range(len(classes))),
                                       target_names=classes, output_dict=True, zero_division=0)
        (out / f'{name}_classification_report.json').write_text(json.dumps(report, indent=2))
        pd.DataFrame(confusion_matrix(truth, predicted, labels=list(range(len(classes)))),
                     index=classes, columns=classes).to_csv(out / f'{name}_confusion_matrix.csv')
        frame[f'{name}_prediction'] = [classes[i] for i in predicted]
    old_correct = np.array(predictions['previous']) == np.array(truth)
    new_correct = np.array(predictions['candidate']) == np.array(truth)
    summary['paired_changes'] = {'corrected': int((~old_correct & new_correct).sum()),
                                'regressed': int((old_correct & ~new_correct).sum())}
    frame.to_csv(out / 'test_predictions.csv', index=False)
    (out / 'comparison.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == '__main__':
    main()
