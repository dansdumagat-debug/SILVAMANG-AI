"""Compare one fixed equal-weight ensemble and create an offline validation review.

Consumes evaluate_identification_candidates.py outputs; never changes labels,
training splits, production weights, or evaluates the final test set.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageOps
from sklearn.metrics import confusion_matrix

from evaluate_identification_candidates import summarize


def load(run, evaluation):
    config = json.loads((run / 'config.json').read_text())
    summary = json.loads((evaluation / 'comparison.json').read_text())
    checkpoint = run / 'efficientnet_b0_best.pth'
    assert summary['split'] == 'val'
    assert summary['checkpoint_sha256'] == hashlib.sha256(checkpoint.read_bytes()).hexdigest()
    assert summary['manifest_sha256'] == hashlib.sha256((run / 'split_manifest.csv').read_bytes()).hexdigest()
    frame = pd.read_csv(evaluation / 'center_predictions.csv')
    manifest = pd.read_csv(run / 'split_manifest.csv')
    expected = manifest.loc[manifest.split == 'val'].set_index('sha256_rgb')
    assert frame.sha256_rgb.is_unique and set(frame.sha256_rgb) == set(expected.index)
    assert frame.label.tolist() == expected.loc[frame.sha256_rgb, 'label'].tolist()
    probabilities = np.load(evaluation / 'center_probabilities.npy')
    assert probabilities.shape == (len(frame), len(config['classes']))
    assert np.isfinite(probabilities).all() and (probabilities >= 0).all()
    assert np.allclose(probabilities.sum(1), 1, atol=1e-5)
    return config, frame, probabilities, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ['reference-run', 'reference-evaluation', 'candidate-run', 'candidate-evaluation', 'output']:
        parser.add_argument('--' + arg, type=Path, required=True)
    args = parser.parse_args()
    rc, rf, rp, _ = load(args.reference_run, args.reference_evaluation)
    cc, cf, cp, manifest = load(args.candidate_run, args.candidate_evaluation)
    assert rc['classes'] == cc['classes']
    assert set(rf.sha256_rgb) == set(cf.sha256_rgb)
    order = rf.reset_index().set_index('sha256_rgb').loc[cf.sha256_rgb, 'index'].to_numpy()
    rp = rp[order]
    assert rf.iloc[order].label.tolist() == cf.label.tolist()
    classes, truth = cc['classes'], cf.label.to_numpy()
    probabilities = {'reference': rp, 'expanded': cp, 'equal_weight_ensemble': (rp + cp) / 2}
    metrics, reports = {}, {}
    for name, values in probabilities.items():
        metrics[name], reports[name] = summarize(values, truth, classes)
        metrics[name]['coverage'] = metrics[name]['accepted_count'] / len(truth)
    base, blend = metrics['reference'], metrics['equal_weight_ensemble']
    eligible = (blend['accuracy'] > base['accuracy'] and blend['macro_f1'] > base['macro_f1']
                and blend['unknown_false_accepts'] <= base['unknown_false_accepts'])
    selected = 'equal_weight_ensemble' if eligible else 'reference'
    args.output.mkdir(parents=True, exist_ok=False)
    thumbnails = args.output / 'thumbnails'
    thumbnails.mkdir()
    summary = dict(split='val', images=len(truth), metrics=metrics, selected=selected,
                   deployed=False, test_evaluated=False,
                   references=[str(args.reference_evaluation), str(args.candidate_evaluation)],
                   limitation='Validation experiment only. Ensemble requires two models and extra inference time. '
                   'Accepted accuracy uses confidence >= 0.70 and excludes unknown predictions; it is not overall accuracy. '
                   'Dataset labels and source independence still need review. No guarantee of 85-90% accuracy.')
    (args.output / 'comparison.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    # Review latest expanded checkpoint to explain the regression, even if another recipe wins.
    matrix = confusion_matrix(truth, cp.argmax(1), labels=range(len(classes)))
    pd.DataFrame(matrix, index=classes, columns=classes).to_csv(args.output / 'expanded_confusion_matrix.csv')
    pairs = [{'actual': classes[i], 'predicted': classes[j], 'count': int(matrix[i, j])}
             for i in range(len(classes)) for j in range(len(classes)) if i != j and matrix[i, j]]
    pd.DataFrame(pairs).sort_values('count', ascending=False).to_csv(args.output / 'confusion_pairs.csv', index=False)
    review = cf.loc[cp.argmax(1) != truth].copy().sort_values('confidence', ascending=False)
    review['review_status'] = 'unreviewed'
    review['notes'] = ''
    review['usage'] = 'validation_only_do_not_move_to_training'
    review.to_csv(args.output / 'validation_error_review.csv', index=False)
    priority = []
    for name in classes:
        score = reports['expanded'][name]
        training = manifest[(manifest.split == 'train') & (manifest.class_name == name)]
        priority.append(dict(species=name, train_photos=len(training), train_groups=training.group.nunique(),
                             validation_photos=int(score['support']), recall=score['recall'], f1=score['f1-score']))
    pd.DataFrame(priority).sort_values('f1').to_csv(args.output / 'species_priorities.csv', index=False)
    # Separate training examples from evaluation errors; a prediction is never a new label.
    weak = [p['species'] for p in priority if p['recall'] < .6 or p['f1'] < .6]
    queues = []
    for name in weak:
        rows = manifest[(manifest.split == 'train') & (manifest.class_name == name)]
        queues.append(rows.sample(frac=1, random_state=42).drop_duplicates('group').head(20))
    queue = pd.concat(queues, ignore_index=True) if queues else manifest.iloc[:0].copy()
    assert not set(queue.sha256_rgb) & set(cf.sha256_rgb)
    queue['review_status'] = 'unreviewed'
    queue['proposed_label'] = ''
    queue['notes'] = ''
    queue['local_image'] = queue.saved_path.map(lambda p: str((Path(cc['source']) / p).resolve()))
    queue.to_csv(args.output / 'training_photo_review.csv', index=False)
    cards = []
    for row in review.itertuples():
        path = (Path(cc['source']) / row.saved_path).resolve()
        assert path.is_relative_to(Path(cc['source']).resolve())
        thumb = thumbnails / (row.sha256_rgb + '.jpg')
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image).convert('RGB')
            image.thumbnail((360, 260))
            image.save(thumb, quality=85)
        cards.append(f'<article><a href="{html.escape(path.as_uri())}"><img loading="lazy" src="thumbnails/{thumb.name}" alt="Validation example"></a>'
                     f'<p>Recorded: <b>{html.escape(row.class_name)}</b></p>'
                     f'<p>Predicted: {html.escape(row.prediction)} ({row.confidence:.1%})</p>'
                     f'<small>{row.sha256_rgb[:16]} — unreviewed</small></article>')
    page = ('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>SILVAMANG validation review</title><style>body{font:16px system-ui;background:#edf5f0;color:#143d30;padding:24px}'
            'main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}article{background:white;padding:16px;border-radius:12px;overflow-wrap:anywhere}'
            'img{width:100%;height:220px;object-fit:contain}table{border-collapse:collapse}td,th{padding:10px;border:1px solid #aabfb4}</style>'
            '<h1>Validation error review</h1><p>Latest expanded checkpoint. Recorded labels are not expert confirmations. '
            'Do not relabel from predictions alone or move validation photos into training. This page works offline.</p>'
            '<table><tr><th>Recipe</th><th>Overall accuracy</th><th>Macro F1</th></tr>' +
            ''.join(f'<tr><td>{name}</td><td>{m["accuracy"]:.2%}</td><td>{m["macro_f1"]:.2%}</td></tr>' for name, m in metrics.items()) +
            f'</table><p>{len(review)} misclassified photos. Click a photo to view the original.</p><main>' + ''.join(cards) + '</main></html>')
    (args.output / 'index.html').write_text(page, encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
