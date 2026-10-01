"""One predeclared 320px experiment against a verified 224px validation baseline.

This does not change the production input contract or evaluate test images.
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageOps
from torchvision import transforms

from compare_classifier_ensemble import load
from evaluate_identification_candidates import summarize
from train_corrected_classifier import build_model, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--baseline-evaluation', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config, frame, baseline_probabilities, _ = load(args.run, args.baseline_evaluation)
    classes = config['classes']
    source = Path(config['source']).resolve()
    torch.set_num_threads(2)
    state = torch.load(args.run / 'efficientnet_b0_best.pth', map_location='cpu', weights_only=True)
    assert state['classes'] == classes
    model, _, _ = build_model('efficientnet_b0', len(classes), pretrained=False)
    model.load_state_dict(state['model_state_dict'], strict=True)
    model.eval()
    transform = transforms.Compose([
        transforms.Resize(366), transforms.CenterCrop(320), transforms.ToTensor(),
        transforms.Normalize([.485, .456, .406], [.229, .224, .225]),
    ])
    args.output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    parts = []
    with torch.inference_mode():
        for start in range(0, len(frame), 8):
            tensors = []
            for row in frame.iloc[start:start + 8].itertuples():
                path = (source / row.saved_path).resolve()
                assert path.is_relative_to(source)
                with Image.open(path) as image:
                    tensors.append(transform(ImageOps.exif_transpose(image).convert('RGB')))
            parts.append(model(torch.stack(tensors)).softmax(1).numpy())
            if start % 80 == 0 or start + 8 >= len(frame):
                completed = min(start + 8, len(frame))
                write_json(args.output / 'status.json', dict(state='running', completed=completed, total=len(frame)))
                print(f'Validation {completed}/{len(frame)}', flush=True)
    probabilities = np.concatenate(parts)
    baseline, _ = summarize(baseline_probabilities, frame.label.to_numpy(), classes)
    candidate, report = summarize(probabilities, frame.label.to_numpy(), classes)
    assert abs(baseline['macro_f1'] - state['validation']['macro_f1']) < 1e-6
    improved = (candidate['accuracy'] > baseline['accuracy'] and candidate['macro_f1'] > baseline['macro_f1']
                and candidate['unknown_false_accepts'] <= baseline['unknown_false_accepts'])
    comparison = dict(baseline_224=baseline, candidate_320=candidate, improved=improved,
                      split='val', test_evaluated=False, deployed=False, elapsed_seconds=time.monotonic() - started,
                      reference_run=str(args.run), manifest_sha256=config['manifest_sha256'],
                      limitation='Validation-only experiment; current production contract remains 224px. '
                      'Independent field evaluation and latency testing required before deployment.')
    rows = frame[['sha256_rgb', 'saved_path', 'class_name', 'label']].copy()
    rows['prediction'] = [classes[i] for i in probabilities.argmax(1)]
    rows['confidence'] = probabilities.max(1)
    rows.to_csv(args.output / 'predictions.csv', index=False)
    np.save(args.output / 'probabilities.npy', probabilities)
    write_json(args.output / 'per_class.json', report)
    write_json(args.output / 'comparison.json', comparison)
    write_json(args.output / 'status.json', dict(state='complete', completed=len(frame), total=len(frame)))
    print(json.dumps(comparison, indent=2), flush=True)


if __name__ == '__main__':
    main()
