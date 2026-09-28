# Targeted classifier data-improvement plan

This is error analysis, not evidence that any particular label is wrong. No dataset, label, split, or app model was modified.

## Lowest-performing classes

| Class | Train images | Test images | Recall | F1 | Main confusions |
|---|---:|---:|---:|---:|---|
| Ceriops_zippeliana | 48 | 10 | 20.0% | 0.286 | Ceriops_tagal: 4; Rhizophora_mucronata: 2; Xylocarpus_granatum: 1 |
| Avicennia_alba | 86 | 15 | 46.7% | 0.438 | Avicennia_marina: 2; Avicennia_rumphiana: 2; Avicennia_officinalis: 1 |
| Xylocarpus_moluccensis | 66 | 17 | 41.2% | 0.467 | Xylocarpus_granatum: 2; Sonneratia_alba: 2; Heritiera_littoralis: 2 |
| Rhizophora_mucronata | 162 | 35 | 48.6% | 0.500 | Bruguiera_gymnorrhiza: 4; Excoecaria_agallocha: 3; Rhizophora_stylosa: 2 |
| Avicennia_officinalis | 132 | 36 | 44.4% | 0.571 | Avicennia_marina: 5; Heritiera_littoralis: 4; Excoecaria_agallocha: 2 |
| Bruguiera_cylindrica | 131 | 20 | 70.0% | 0.583 | Bruguiera_gymnorrhiza: 3; Avicennia_alba: 1; Avicennia_marina: 1 |
| Camptostemon_philippinensis | 22 | 4 | 75.0% | 0.600 | Sonneratia_alba: 1 |
| Xylocarpus_granatum | 123 | 26 | 65.4% | 0.607 | Excoecaria_agallocha: 4; Avicennia_alba: 1; Avicennia_rumphiana: 1 |
| Bruguiera_sexangula | 106 | 22 | 68.2% | 0.625 | Bruguiera_gymnorrhiza: 4; Avicennia_rumphiana: 1; Rhizophora_mucronata: 1 |
| Acanthus_ebracteatus | 88 | 18 | 72.2% | 0.650 | Acanthus_ilicifolius: 4; Avicennia_officinalis: 1 |

## Work order

1. Review training_label_review.csv with the matching training contact sheets. Confirm identity and flag blur, non-target subjects, ambiguous multi-species scenes, and labeling problems. Have botanical identities checked by a knowledgeable reviewer; do not relabel from model predictions alone.
2. Collect additional independent trees/observations for the high-priority classes. Start with a manageable batch of 20 new observations per priority class; this is a collection starting point, not a statistically established sufficiency threshold. Include varied locations, lighting, cameras, and plant parts. Add matched examples of frequently confused classes.
3. Review unknown separately: add verified non-mangroves and unrelated capture subjects to training. Avoid labeling uncertain mangrove species as unknown simply because they are difficult.
4. Record observation/tree/source IDs and provenance for new photos. Keep related photos together. Existing image-hash-only groups do not guarantee independent trees; inspect near duplicates and shared sources before claiming independent evaluation.
5. Preserve the original dataset and reports. Apply only reviewed training corrections to a versioned copy; do not move test errors into training.
6. Select future experiments using validation only. Because this test set is now informing error analysis, obtain a new independently labeled final evaluation set before claiming unbiased improvement.
7. Reassess per-class recall/F1 and the unknown rejection behavior, not only overall accuracy. Compare a new training candidate with the existing model before export.

## Interpretation limits

Classes with fewer than 20 test images are flagged in species_priorities.csv; their percentages are especially unstable. Source-group counts are recorded grouping units, not verified independent trees. Test metrics use top-1 predictions without the app confidence rejection threshold.

Training review queue: 160 examples. Test error review: 263 examples. These queues are separate.
