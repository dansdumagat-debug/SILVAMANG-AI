"""Read-only error analysis. Produces review queues; never edits labels or splits."""
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from PIL import Image


def main():
    root = Path(__file__).resolve().parents[1]
    run = root / 'artifacts/classifier_retraining/regularized_20260928T042515855122Z'
    config = json.loads((run / 'config.json').read_text())
    source = Path(config['source'])
    manifest = pd.read_csv(source / 'split_manifest.csv')
    evaluation = run / 'heldout_evaluation'
    report = json.loads((evaluation / 'candidate_classification_report.json').read_text())
    previous = json.loads((evaluation / 'previous_classification_report.json').read_text())
    predictions = pd.read_csv(evaluation / 'test_predictions.csv')
    matrix = pd.read_csv(evaluation / 'candidate_confusion_matrix.csv', index_col=0)
    classes = config['classes']
    out = run / 'data_improvement'
    figures = out / 'figures'
    figures.mkdir(parents=True, exist_ok=True)
    counts = pd.crosstab(manifest['class_name'], manifest['split'])
    records = []
    pairs = []
    for name in classes:
        scores = report[name]
        errors = matrix.loc[name].drop(name).sort_values(ascending=False)
        missed = int(errors.sum())
        top = errors[errors > 0].head(3)
        for target, count in errors.items():
            if count:
                pairs.append(dict(actual=name, predicted=target, count=int(count),
                                  fraction_of_actual=float(count / scores['support'])))
        train = manifest[(manifest['split'] == 'train') & (manifest['class_name'] == name)]
        records.append(dict(
            species=name, train_images=int(counts.loc[name, 'train']),
            train_source_groups=int(train['group'].nunique()), test_images=int(scores['support']),
            precision=scores['precision'], recall=scores['recall'], f1=scores['f1-score'],
            previous_f1=previous[name]['f1-score'], f1_change=scores['f1-score']-previous[name]['f1-score'],
            missed_images=missed, most_confused_with='; '.join(f'{s}: {int(n)}' for s, n in top.items()),
            review_priority='high' if scores['recall'] < 0.6 or scores['f1-score'] < 0.6 else 'normal',
            small_test_sample=int(scores['support']) < 20,
        ))
    table = pd.DataFrame(records).sort_values(['f1', 'recall'])
    table.to_csv(out / 'species_priorities.csv', index=False)
    pairs = pd.DataFrame(pairs).sort_values('count', ascending=False)
    pairs.to_csv(out / 'confusion_pairs.csv', index=False)
    wrong = predictions[predictions['class_name'] != predictions['candidate_prediction']].copy()
    wrong['review_status'] = 'unreviewed'
    wrong['label_issue_confirmed'] = ''
    wrong['reviewer_notes'] = ''
    wrong['usage'] = 'test_error_analysis_only_do_not_move_to_training'
    wrong['local_image'] = wrong['saved_path'].map(lambda p: str(source / p))
    wrong.to_csv(out / 'test_error_review.csv', index=False)

    # A manageable, reproducible TRAIN-only queue for expert label/quality review.
    high = table.loc[table['review_priority'] == 'high', 'species'].tolist()
    review = []
    for name in high:
        rows = manifest[(manifest['split'] == 'train') & (manifest['class_name'] == name)]
        rows = rows.sample(frac=1, random_state=42).drop_duplicates('group').head(20).copy()
        review.append(rows)
    queue = pd.concat(review, ignore_index=True) if review else manifest.iloc[:0].copy()
    queue['local_image'] = queue['saved_path'].map(lambda p: str(source / p))
    queue['review_status'] = 'unreviewed'
    queue['proposed_label'] = ''
    queue['reviewer_notes'] = ''
    queue.to_csv(out / 'training_label_review.csv', index=False)
    assert set(queue['split']) <= {'train'}
    assert not set(queue['sha256_rgb']) & set(predictions['sha256_rgb'])

    fig, ax = plt.subplots(figsize=(10, 10))
    ax.barh(table['species'], table['f1'], color='#247c6c')
    ax.invert_yaxis()
    ax.set(xlim=(0, 1), xlabel='Held-out macro component: per-class F1', title='Per-class performance (test supports vary)')
    fig.tight_layout()
    fig.savefig(figures / 'per_class_f1.png', dpi=160)
    plt.close(fig)
    normalized = matrix.to_numpy() / matrix.sum(axis=1).to_numpy()[:, None]
    fig, ax = plt.subplots(figsize=(15, 13))
    im = ax.imshow(normalized, vmin=0, vmax=1, cmap='Blues')
    ax.set_xticks(range(len(classes)), classes, rotation=90, fontsize=8)
    ax.set_yticks(range(len(classes)), classes, fontsize=8)
    ax.set(xlabel='Predicted', ylabel='Recorded actual label', title='Row-normalized held-out confusion matrix')
    fig.colorbar(im, ax=ax)
    fig.tight_layout()
    fig.savefig(figures / 'confusion_matrix.png', dpi=160)
    plt.close(fig)

    # Training examples only; no label is assumed wrong merely from low class F1.
    for name in high:
        examples = queue[queue['class_name'] == name].head(8)
        fig, axes = plt.subplots(2, 4, figsize=(14, 8))
        for ax in axes.flat:
            ax.axis('off')
        for ax, row in zip(axes.flat, examples.itertuples()):
            with Image.open(row.local_image) as image:
                ax.imshow(image.convert('RGB'))
            ax.set_title(row.sha256_rgb[:12], fontsize=9)
        fig.suptitle(f'TRAINING review: {name}\nRecorded labels, not expert-verified; IDs match training_label_review.csv')
        fig.tight_layout()
        fig.savefig(figures / f'train_review_{name}.jpg', dpi=100)
        plt.close(fig)

    lines = ['# Targeted classifier data-improvement plan', '',
        'This is error analysis, not evidence that any particular label is wrong. No dataset, label, split, or app model was modified.', '',
        '## Lowest-performing classes', '',
        '| Class | Train images | Test images | Recall | F1 | Main confusions |',
        '|---|---:|---:|---:|---:|---|']
    for row in table.head(10).itertuples():
        lines.append(f'| {row.species} | {row.train_images} | {row.test_images} | {row.recall:.1%} | {row.f1:.3f} | {row.most_confused_with} |')
    lines += ['', '## Work order', '',
        '1. Review training_label_review.csv with the matching training contact sheets. Confirm identity and flag blur, non-target subjects, ambiguous multi-species scenes, and labeling problems. Have botanical identities checked by a knowledgeable reviewer; do not relabel from model predictions alone.',
        '2. Collect additional independent trees/observations for the high-priority classes. Start with a manageable batch of 20 new observations per priority class; this is a collection starting point, not a statistically established sufficiency threshold. Include varied locations, lighting, cameras, and plant parts. Add matched examples of frequently confused classes.',
        '3. Review unknown separately: add verified non-mangroves and unrelated capture subjects to training. Avoid labeling uncertain mangrove species as unknown simply because they are difficult.',
        '4. Record observation/tree/source IDs and provenance for new photos. Keep related photos together. Existing image-hash-only groups do not guarantee independent trees; inspect near duplicates and shared sources before claiming independent evaluation.',
        '5. Preserve the original dataset and reports. Apply only reviewed training corrections to a versioned copy; do not move test errors into training.',
        '6. Select future experiments using validation only. Because this test set is now informing error analysis, obtain a new independently labeled final evaluation set before claiming unbiased improvement.',
        '7. Reassess per-class recall/F1 and the unknown rejection behavior, not only overall accuracy. Compare a new training candidate with the existing model before export.', '',
        '## Interpretation limits', '',
        'Classes with fewer than 20 test images are flagged in species_priorities.csv; their percentages are especially unstable. Source-group counts are recorded grouping units, not verified independent trees. Test metrics use top-1 predictions without the app confidence rejection threshold.', '',
        f'Training review queue: {len(queue)} examples. Test error review: {len(wrong)} examples. These queues are separate.',
    ]
    (out / 'README.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(table.head(10)[['species','train_images','test_images','recall','f1','most_confused_with']].to_string(index=False))
    print(f'Artifacts: {out}\nTrain review: {len(queue)}; test errors: {len(wrong)}')


if __name__ == '__main__':
    main()
