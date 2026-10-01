"""Train regularized classifier heads on TRAIN features; select on validation only."""
import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image, ImageOps
from sklearn.linear_model import LogisticRegression
from torchvision import transforms

from evaluate_identification_candidates import summarize
from train_corrected_classifier import build_model, write_json, checkpoint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    config = json.loads((args.run/'config.json').read_text())
    source = Path(config['source']).resolve()
    manifest = args.run/'split_manifest.csv'
    assert hashlib.sha256(manifest.read_bytes()).hexdigest() == config['manifest_sha256']
    frame = pd.read_csv(manifest)
    assert frame.groupby('group')['split'].nunique().max() == 1
    saved = torch.load(args.run/'efficientnet_b0_best.pth',map_location='cpu',weights_only=True)
    classes = saved['classes']
    assert classes == config['classes']
    assert all(classes[int(row.label)] == row.class_name for row in frame.itertuples())
    torch.set_num_threads(2)
    model,_,_ = build_model('efficientnet_b0',len(classes),pretrained=False)
    model.load_state_dict(saved['model_state_dict'],strict=True)
    model.eval()
    transform = transforms.Compose([transforms.Resize(256),transforms.CenterCrop(224),transforms.ToTensor(),
                                    transforms.Normalize([.485,.456,.406],[.229,.224,.225])])
    features, labels = {}, {}
    started = time.monotonic()
    for split in ['train','val']:
        rows = frame[frame.split==split]
        parts = []
        with torch.inference_mode():
            for start in range(0,len(rows),8):
                batch = []
                for row in rows.iloc[start:start+8].itertuples():
                    path = (source/row.saved_path).resolve()
                    assert path.is_relative_to(source)
                    with Image.open(path) as im:
                        batch.append(transform(ImageOps.exif_transpose(im).convert('RGB')))
                output = model.avgpool(model.features(torch.stack(batch))).flatten(1)
                parts.append(output.numpy())
                if start % 400 == 0:
                    print(f'{split} features {min(start+8,len(rows))}/{len(rows)}',flush=True)
                    write_json(args.output/'status.json',dict(state='extracting',split=split,completed=start+len(batch),total=len(rows)))
        features[split] = np.concatenate(parts)
        labels[split] = rows.label.to_numpy()
        np.savez_compressed(args.output/f'{split}_features.npz',features=features[split],labels=labels[split])
    with torch.inference_mode():
        baseline_prob = model.classifier(torch.from_numpy(features['val'])).softmax(1).numpy()
    baseline,_ = summarize(baseline_prob,labels['val'],classes)
    assert abs(baseline['macro_f1']-saved['validation']['macro_f1']) < 1e-6
    summary = dict(baseline=baseline,candidates={},selected_candidate='baseline',deployed=False,test_evaluated=False,
                   manifest_sha256=config['manifest_sha256'],
                   limitation='Validation-selected experiment; independent field evaluation required.')
    best = baseline
    for strength in [.01,.1,1.]:
        name = f'head_C_{strength}'
        write_json(args.output/'status.json',dict(state='fitting',candidate=name))
        estimator = LogisticRegression(C=strength,class_weight='balanced',max_iter=1000,solver='lbfgs',random_state=42)
        estimator.fit(features['train'],labels['train'])
        assert np.array_equal(estimator.classes_,np.arange(len(classes)))
        probabilities = estimator.predict_proba(features['val'])
        metrics,report = summarize(probabilities,labels['val'],classes)
        metrics['converged'] = bool(estimator.n_iter_.max() < estimator.max_iter)
        summary['candidates'][name] = metrics
        write_json(args.output/f'{name}_per_class.json',report)
        print(name,metrics,flush=True)
        # Preserve fitted heads for reproducibility, including unsuccessful experiments.
        np.savez(args.output/f'{name}_head.npz',weight=estimator.coef_,bias=estimator.intercept_)
        if (metrics['converged'] and metrics['accuracy'] > baseline['accuracy'] and metrics['macro_f1'] > best['macro_f1']
                and metrics['unknown_false_accepts'] <= baseline['unknown_false_accepts']):
            best = metrics
            summary['selected_candidate'] = name
            state = {k:v.clone() for k,v in saved['model_state_dict'].items()}
            state['classifier.1.weight'] = torch.tensor(estimator.coef_,dtype=torch.float32)
            state['classifier.1.bias'] = torch.tensor(estimator.intercept_,dtype=torch.float32)
            model.load_state_dict(state,strict=True)
            with torch.inference_mode():
                actual = model.classifier(torch.from_numpy(features['val'])).softmax(1).numpy()
            np.testing.assert_allclose(actual,probabilities,atol=1e-5,rtol=1e-4)
            checkpoint(args.output/'candidate.pth',dict(model_state_dict=state,classes=classes,image_size=224,
                       model_name='efficientnet_b0',validation=metrics,training_config=config,
                       head_refit=dict(C=strength,class_weight='balanced',source_checkpoint_sha256=hashlib.sha256((args.run/'efficientnet_b0_best.pth').read_bytes()).hexdigest())))
    summary['elapsed_seconds'] = time.monotonic()-started
    write_json(args.output/'comparison.json',summary)
    write_json(args.output/'status.json',dict(state='complete',selected_candidate=summary['selected_candidate']))
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':
    main()
