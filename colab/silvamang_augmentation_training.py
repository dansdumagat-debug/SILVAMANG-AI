# %% [markdown]
# SILVAMANG: candidates → augmentation → EfficientNet-B0
# Open the accompanying notebook in Google Colab and select a GPU runtime.
# Run cells in order. Drive files are read; outputs go into new timestamped runs.
# This trains classification only. Detection needs boxes, segmentation needs
# polygons/masks, and supervised depth fine-tuning needs depth targets.
# An unknown class is a learned background class, not guaranteed novel-species detection.

# %%
from google.colab import drive
drive.mount('/content/drive')
from pathlib import Path
from datetime import datetime, timezone
import json, random, hashlib, re, shutil, os
from collections import defaultdict
import numpy as np
import pandas as pd
from PIL import Image, ImageOps
import matplotlib.pyplot as plt
import torch
from torch import nn
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from tqdm.auto import tqdm

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
ROOT = Path('/content/drive/MyDrive/candidates')
assert ROOT.is_dir(), f'Folder not found: {ROOT}'
OUTPUT = ROOT / 'Trained Model'
for folder in ['EfficientNet-B0', 'YOLOv8-Detector', 'YOLOv8-Seg', 'MiDaS']:
    (OUTPUT / folder).mkdir(parents=True, exist_ok=True)
RUN_ID = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
RUN = OUTPUT / 'EfficientNet-B0' / RUN_ID
RUN.mkdir(parents=True, exist_ok=False)
DATASET = RUN / 'dataset'
FIGURES = RUN / 'figures'
DATASET.mkdir(exist_ok=True)
FIGURES.mkdir(exist_ok=True)
CACHE = Path('/content/silvamang_cache') / RUN_ID
CACHE.mkdir(parents=True, exist_ok=False)

def save_json(name, value):
    (RUN / name).write_text(json.dumps(value, indent=2), encoding='utf-8')

def save_figure(fig, name):
    fig.savefig(FIGURES / f'{name}.png', dpi=180, bbox_inches='tight')
    fig.savefig(FIGURES / f'{name}.pdf', bbox_inches='tight')

save_json('environment.json', {
    'torch': str(torch.__version__), 'device': str(DEVICE), 'seed': SEED,
    'source': str(ROOT), 'run_id': RUN_ID,
})
print('Device:', DEVICE)
print('Results will be saved to:', RUN)
print('Use Runtime → Change runtime type → GPU before training.')

# %% [markdown]
# Audit and cache images. Only the 29 listed class folders are scanned, so
# Trained Model can never become a class. Readability is checked and identical
# decoded RGB images are deduplicated before splitting. Conflicting labels stop
# the workflow and are reported. No source images are deleted.

# %%
CLASSES = sorted('''Acanthus_ebracteatus Acanthus_ilicifolius Aegiceras_corniculatum
Avicennia_alba Avicennia_marina Avicennia_officinalis Avicennia_rumphiana
Bruguiera_cylindrica Bruguiera_gymnorrhiza Bruguiera_sexangula
Camptostemon_philippinensis Ceriops_tagal Ceriops_zippeliana Excoecaria_agallocha
Heritiera_littoralis Lumnitzera_littorea Lumnitzera_racemosa Nypa_fruticans
Osbornia_octodonta Pemphis_acidula Rhizophora_apiculata Rhizophora_mucronata
Rhizophora_stylosa Scyphiphora_hydrophylacea Sonneratia_alba Sonneratia_ovata
Xylocarpus_granatum Xylocarpus_moluccensis unknown'''.split())
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff', '.gif'}
missing = [c for c in CLASSES if not (ROOT / c).is_dir()]
assert not missing, f'Missing class folders: {missing}'
records, rejected, duplicates, conflicts = [], [], [], []
seen = {}
for label, name in enumerate(tqdm(CLASSES, desc='Auditing class folders')):
    paths = sorted(p for p in (ROOT / name).rglob('*') if p.is_file())
    for path in paths:
        if path.suffix.lower() not in EXTENSIONS:
            continue
        relative = path.relative_to(ROOT).as_posix()
        try:
            with Image.open(path) as source:
                rgb = ImageOps.exif_transpose(source).convert('RGB')
                rgb.load()
            digest = hashlib.sha256(str(rgb.size).encode() + rgb.tobytes()).hexdigest()
        except Exception as exc:
            rejected.append({'source': relative, 'error': str(exc)})
            continue
        if digest in seen:
            previous = seen[digest]
            item = {'source': relative, 'same_as': previous['source']}
            if previous['class_name'] != name:
                conflicts.append(item)
            else:
                duplicates.append(item)
            continue
        cached = CACHE / f'{digest}.jpg'
        # Cache once on Colab disk to avoid repeatedly reading images from Drive.
        rgb.save(cached, quality=95)
        row = {'source': relative, 'path': str(cached), 'label': label,
               'class_name': name, 'sha256_rgb': digest}
        seen[digest] = row
        records.append(row)

save_json('audit.json', {'unreadable': rejected, 'duplicates': duplicates,
                         'label_conflicts': conflicts})
assert not conflicts, f'Conflicting labels found. Review {RUN}/audit.json before training.'
df = pd.DataFrame(records)
assert not df.empty, 'No readable images found.'
counts = df.groupby('class_name').size().reindex(CLASSES, fill_value=0)
display(counts.to_frame('usable_images'))
assert counts.min() >= 10, 'A class has fewer than 10 usable images; review the audit.'
print(f'Usable: {len(df)}; duplicates skipped: {len(duplicates)}; unreadable: {len(rejected)}')

# %% [markdown]
# Split originals BEFORE augmentation, approximately 70% train / 15% validation /
# 15% test per class. Known GBIF observation IDs and Commons file IDs stay together.
# Optional source_groups.csv at candidates/source_groups.csv must have source and
# group columns, with source relative to candidates. Use it to keep the same tree,
# capture session, or related web images together. Automatic IDs cannot identify
# all near-duplicates or photographs of the same specimen: review the split before
# treating test scores as field performance. The manifest is saved for inspection.

# %%
manual_groups = {}
group_file = ROOT / 'source_groups.csv'
if group_file.exists():
    group_df = pd.read_csv(group_file, dtype=str)
    assert {'source', 'group'} <= set(group_df.columns)
    assert not group_df[['source', 'group']].isna().any().any()
    assert not group_df.source.duplicated().any()
    manual_groups = dict(zip(group_df.source, group_df.group))

def source_group(row):
    if row['source'] in manual_groups:
        return 'manual:' + manual_groups[row['source']]
    match = re.search(r'(gbif|commons)_(?:[a-z]+_)?(\d+)', Path(row['source']).name)
    if match:
        return ':'.join(match.groups())
    return 'image:' + row['sha256_rgb']

df['group'] = df.apply(source_group, axis=1)
group_classes = df.groupby('group').class_name.nunique()
assert group_classes.max() == 1, 'A source group has multiple labels; review groups/labels.'
df['split'] = ''
rng = np.random.default_rng(SEED)
for name in CLASSES:
    groups = df.loc[df.class_name == name, 'group'].unique().copy()
    assert len(groups) >= 7, f'{name}: too few independent source groups.'
    rng.shuffle(groups)
    n_test = max(1, round(len(groups) * .15))
    n_val = max(1, round(len(groups) * .15))
    assignments = {g: ('test' if i < n_test else 'val' if i < n_test + n_val else 'train')
                   for i, g in enumerate(groups)}
    mask = df.class_name == name
    df.loc[mask, 'split'] = df.loc[mask, 'group'].map(assignments)
assert df.groupby('group').split.nunique().max() == 1
# Persist the prepared dataset on Drive; local copies remain for faster training.
saved_paths = []
for row in tqdm(df.itertuples(), total=len(df), desc='Saving split dataset to Drive'):
    destination = DATASET / row.split / row.class_name / f'{row.sha256_rgb}.jpg'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(row.path, destination)
    assert destination.stat().st_size == Path(row.path).stat().st_size
    saved_paths.append(destination.relative_to(RUN).as_posix())
df['saved_path'] = saved_paths
df.drop(columns='path').to_csv(RUN / 'split_manifest.csv', index=False)
save_json('class_order.json', CLASSES)
distribution = pd.crosstab(df.class_name, df.split).reindex(columns=['train', 'val', 'test'])
distribution.to_csv(RUN / 'split_counts.csv')
display(distribution)
ax = distribution.plot.barh(stacked=True, figsize=(11, 12))
ax.set_xlabel('Images')
ax.set_title('Prepared dataset split by class')
save_figure(ax.figure, 'dataset_distribution')
plt.show()
print('Prepared images saved to:', DATASET)
print('Review source groups before proceeding. Splits are approximate by image count.')

# %% [markdown]
# Training augmentation: crop retaining 75–100% area, horizontal flip, rotation
# up to 15°, and mild brightness/contrast/saturation changes. Avoid vertical flips
# and strong hue changes. Validation and test use the app's fixed 256-resize /
# 224-center-crop preprocessing and ImageNet normalization.
# Preview images are saved; augmented training images are generated afresh each
# epoch, so thousands of duplicate files are not written to Drive.

# %%
MEAN, STD = [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]
augmentation = transforms.Compose([
    transforms.RandomResizedCrop(224, scale=(.75, 1.), ratio=(.9, 1.1)),
    transforms.RandomHorizontalFlip(p=.5),
    transforms.RandomRotation(15, interpolation=transforms.InterpolationMode.BILINEAR),
    transforms.ColorJitter(brightness=.15, contrast=.15, saturation=.10, hue=.02),
])
train_transform = transforms.Compose([
    augmentation, transforms.ToTensor(), transforms.Normalize(MEAN, STD),
])
eval_transform = transforms.Compose([
    transforms.Resize(256), transforms.CenterCrop(224),
    transforms.ToTensor(), transforms.Normalize(MEAN, STD),
])
save_json('preprocessing.json', {
    'image_size': 224, 'resize_size': 256, 'mean': MEAN, 'std': STD,
    'train_augmentation': str(augmentation), 'eval_transform': str(eval_transform),
})
sample = df[df.split == 'train'].sample(1, random_state=SEED).iloc[0]
with Image.open(sample.path) as image:
    original = image.convert('RGB')
fig, axes = plt.subplots(2, 4, figsize=(14, 7))
for i, ax in enumerate(axes.flat):
    ax.imshow(original if i == 0 else augmentation(original))
    ax.set_title('Original' if i == 0 else f'Augmented {i}')
    ax.axis('off')
fig.suptitle(sample.class_name)
fig.tight_layout()
save_figure(fig, 'augmentation_preview')
plt.show()

# %%
class MangroveDataset(Dataset):
    def __init__(self, frame, transform):
        self.frame = frame.reset_index(drop=True)
        self.transform = transform
    def __len__(self):
        return len(self.frame)
    def __getitem__(self, index):
        row = self.frame.iloc[index]
        with Image.open(row.path) as image:
            tensor = self.transform(image.convert('RGB'))
        return tensor, int(row.label)

BATCH_SIZE = 32
loaders = {
    split: DataLoader(
        MangroveDataset(df[df.split == split], train_transform if split == 'train' else eval_transform),
        batch_size=BATCH_SIZE, shuffle=split == 'train', num_workers=2,
        pin_memory=DEVICE.type == 'cuda',
    ) for split in ['train', 'val', 'test']
}
# Use weighted loss to address class imbalance; do not combine with oversampling.
train_counts = df[df.split == 'train'].label.value_counts().reindex(range(len(CLASSES)))
class_weights = torch.tensor(len(df[df.split == 'train']) / (len(CLASSES) * train_counts.values),
                             dtype=torch.float32, device=DEVICE)
criterion = nn.CrossEntropyLoss(weight=class_weights)
eval_criterion = nn.CrossEntropyLoss()
model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
model.classifier[1] = nn.Linear(model.classifier[1].in_features, len(CLASSES))
model = model.to(DEVICE)
print('Model ready:', len(CLASSES), 'classes')

# %% [markdown]
# Train the classification head for 3 epochs, then fine-tune all weights for up
# to 20 epochs. Select the best checkpoint by validation macro-F1, with patience
# of 5 fine-tuning epochs. The test split is used only in the final evaluation.
# GPU is recommended. If memory runs out, reduce BATCH_SIZE to 16 and rerun from
# the preceding cell. New full runs should start at the setup cell.

# %%
assert DEVICE.type == 'cuda', 'Enable a GPU runtime and rerun the notebook for training.'
history, best_f1 = [], -1.
BEST = RUN / 'efficientnet_b0_best.pth'

def epoch_pass(split, optimizer=None, frozen=False):
    training = optimizer is not None
    model.train(training)
    if training and frozen:
        model.features.eval()  # Keep frozen batch-normalization statistics fixed.
    truth, predictions = [], []
    loss_sum, loss_weight = 0., 0.
    with torch.set_grad_enabled(training):
        for images, labels in tqdm(loaders[split], desc=split, leave=False):
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            if training:
                optimizer.zero_grad(set_to_none=True)
            logits = model(images)
            loss = (criterion if training else eval_criterion)(logits, labels)
            if training:
                loss.backward()
                optimizer.step()
            denominator = float(class_weights[labels].sum()) if training else len(labels)
            loss_sum += float(loss.detach()) * denominator
            loss_weight += denominator
            truth.extend(labels.cpu().tolist())
            predictions.extend(logits.argmax(1).detach().cpu().tolist())
    metrics = {
        'loss': loss_sum / loss_weight,
        'accuracy': float(np.mean(np.array(truth) == np.array(predictions))),
        'macro_f1': float(f1_score(truth, predictions, labels=list(range(len(CLASSES))),
                                   average='macro', zero_division=0)),
    }
    return metrics, truth, predictions

for phase, epochs, learning_rate, frozen in [('head', 3, 1e-3, True), ('finetune', 20, 1e-4, False)]:
    if phase == 'finetune':
        model.load_state_dict(torch.load(BEST, map_location=DEVICE, weights_only=True)['model_state_dict'])
    for parameter in model.features.parameters():
        parameter.requires_grad = not frozen
    optimizer = torch.optim.AdamW(filter(lambda p: p.requires_grad, model.parameters()),
                                  lr=learning_rate, weight_decay=1e-4)
    stale = 0
    for epoch in range(1, epochs + 1):
        train_metrics, _, _ = epoch_pass('train', optimizer, frozen)
        val_metrics, _, _ = epoch_pass('val')
        row = {'phase': phase, 'epoch': epoch,
               **{f'train_{k}': v for k, v in train_metrics.items()},
               **{f'val_{k}': v for k, v in val_metrics.items()}}
        history.append(row)
        pd.DataFrame(history).to_csv(RUN / 'history.csv', index=False)
        print(f'{phase} {epoch}: val accuracy={val_metrics["accuracy"]:.4f}, macro-F1={val_metrics["macro_f1"]:.4f}')
        if val_metrics['macro_f1'] > best_f1:
            best_f1, stale = val_metrics['macro_f1'], 0
            checkpoint = {
                'model_state_dict': {k: v.detach().cpu() for k, v in model.state_dict().items()},
                'classes': CLASSES, 'image_size': 224, 'model_name': 'efficientnet_b0',
                'validation_metrics': val_metrics, 'phase': phase, 'epoch': epoch,
            }
            # Write locally first, then copy a complete checkpoint to Drive.
            torch.save(checkpoint, CACHE / 'best.pth')
            shutil.copy2(CACHE / 'best.pth', RUN / 'best.pending')
            os.replace(RUN / 'best.pending', BEST)
        else:
            stale += 1
        if phase == 'finetune' and stale >= 5:
            print('Early stopping.')
            break

# %% [markdown]
# Evaluate once on held-out test images. Save the confusion matrix, per-class
# metrics, predictions, checkpoint hash, and training curves next to the model.
# Scores describe this split only; source/session leakage and the small rare-class
# test sets can make field performance differ. Saving to Drive does not activate
# the app endpoints. Deploy the checkpoint and class_order.json together, then
# verify the backend species mapping and record the evaluation.

# %%
checkpoint = torch.load(BEST, map_location=DEVICE, weights_only=True)
model.load_state_dict(checkpoint['model_state_dict'])
test_metrics, truth, predictions = epoch_pass('test')
report = classification_report(truth, predictions, labels=list(range(len(CLASSES))),
                                target_names=CLASSES, output_dict=True, zero_division=0)
save_json('test_metrics.json', test_metrics)
save_json('classification_report.json', report)
pd.DataFrame(report).T.to_csv(RUN / 'classification_report.csv')
pd.DataFrame(confusion_matrix(truth, predictions, labels=list(range(len(CLASSES)))),
             index=CLASSES, columns=CLASSES).to_csv(RUN / 'confusion_matrix.csv')
test_rows = df[df.split == 'test'][['source', 'class_name']].copy()
test_rows['predicted_class'] = [CLASSES[i] for i in predictions]
test_rows.to_csv(RUN / 'test_predictions.csv', index=False)
digest = hashlib.sha256()
with BEST.open('rb') as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b''):
        digest.update(chunk)
save_json('model_metadata.json', {
    'model': 'efficientnet_b0', 'classes': len(CLASSES), 'checkpoint_sha256': digest.hexdigest(),
    'test_metrics': test_metrics, 'best_validation_macro_f1': best_f1,
    'status': 'trained_and_evaluated_on_notebook_split_not_deployed',
})
plot = pd.DataFrame(history)[['train_accuracy', 'val_accuracy', 'train_macro_f1', 'val_macro_f1']].plot(figsize=(10, 5))
plot.set_xlabel('Epoch index (head followed by fine-tuning)')
save_figure(plot.figure, 'training_curves')
plt.show()
ax = pd.DataFrame(history)[['train_loss', 'val_loss']].plot(figsize=(10, 5))
ax.set_xlabel('Epoch index')
ax.set_title('Training loss (class weighted) and validation loss (unweighted)')
save_figure(ax.figure, 'loss_curves')
plt.show()
cm = confusion_matrix(truth, predictions, labels=list(range(len(CLASSES))))
normalized = cm / np.maximum(cm.sum(axis=1, keepdims=True), 1)
fig, ax = plt.subplots(figsize=(16, 14))
im = ax.imshow(normalized, cmap='Blues', vmin=0, vmax=1)
ax.set_xticks(range(len(CLASSES)), CLASSES, rotation=90)
ax.set_yticks(range(len(CLASSES)), CLASSES)
ax.set_xlabel('Predicted class')
ax.set_ylabel('True class')
ax.set_title('Test confusion matrix: proportion within each true class')
fig.colorbar(im, ax=ax)
save_figure(fig, 'confusion_matrix')
plt.show()
ax = pd.Series({name: report[name]['f1-score'] for name in CLASSES}).plot.barh(figsize=(11, 12))
ax.set_xlim(0, 1)
ax.set_xlabel('Test F1 score')
ax.set_title('Per-class test F1')
save_figure(ax.figure, 'per_class_f1')
plt.show()
display(pd.DataFrame(report).T)
print('Test metrics:', test_metrics)
print('Saved model:', BEST)
print('Saved labels:', RUN / 'class_order.json')
print('Saved dataset:', DATASET)
print('Saved figures:', FIGURES)
print('The other model folders are placeholders; no YOLO or MiDaS training was performed.')
