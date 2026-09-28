# %% Setup: run in Colab with a GPU, using the original Drive account.
import os
LOCAL = bool(os.environ.get('SILVAMANG_TRAIN_SOURCE'))
if not LOCAL:
    from google.colab import drive
    drive.mount('/content/drive')

from pathlib import Path
import hashlib
import json
import random
import shutil
from datetime import datetime, timezone
import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torchvision import models, transforms
from PIL import Image, ImageOps
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
from tqdm.auto import tqdm
import matplotlib.pyplot as plt
if LOCAL:
    plt.switch_backend('Agg')
    torch.set_num_threads(2)
    display = print

# Change this only if your existing completed run is at a different location.
SOURCE = Path(os.environ.get('SILVAMANG_TRAIN_SOURCE', '/content/drive/MyDrive/candidates/Trained Model/EfficientNet-B0/rebuild_20260926'))
CHECKPOINT = Path(os.environ.get('SILVAMANG_INITIAL_CHECKPOINT', str(SOURCE / 'efficientnet_b0_last.pth')))
BALANCED = os.environ.get('SILVAMANG_BALANCED', '0') == '1'
# Use a previous candidate run directory here to resume an interrupted run.
RESUME_RUN = os.environ.get('SILVAMANG_RESUME_RUN', '')
SEED = 42
EPOCHS = 15 if BALANCED else 25
PATIENCE = 5 if BALANCED else 6
BATCH_SIZE = 8 if LOCAL else 32
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
assert LOCAL or DEVICE.type == 'cuda', 'Select Runtime > Change runtime type > GPU first.'
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
torch.cuda.manual_seed_all(SEED)

for path in [SOURCE / 'split_manifest.csv', SOURCE / 'class_order.json', CHECKPOINT]:
    assert path.is_file(), f'Missing original artifact: {path}. Do not create a different split.'
CLASSES = json.loads((SOURCE / 'class_order.json').read_text())
assert len(CLASSES) == 29 and len(set(CLASSES)) == 29
frame = pd.read_csv(SOURCE / 'split_manifest.csv')
assert {'saved_path', 'label', 'class_name', 'split', 'sha256_rgb', 'group'} <= set(frame.columns)
assert set(frame['split']) == {'train', 'val', 'test'}
assert not frame['sha256_rgb'].duplicated().any(), 'Duplicate image hashes in original manifest.'
assert frame.groupby('group')['split'].nunique().max() == 1, 'Source groups cross splits.'
assert all(CLASSES[int(r.label)] == r.class_name for r in frame.itertuples())
counts = pd.crosstab(frame['class_name'], frame['split']).reindex(CLASSES, fill_value=0)
assert (counts[['train', 'val', 'test']] > 0).all().all()
display(counts)

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

OUTPUT_ROOT = Path(os.environ.get('SILVAMANG_TRAIN_OUTPUT', str(SOURCE.parent)))
RUN = Path(RESUME_RUN) if RESUME_RUN else OUTPUT_ROOT / (
    ('balanced_' if BALANCED else 'regularized_') + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
RUN.mkdir(parents=True, exist_ok=True)
FIGURES = RUN / 'figures'
FIGURES.mkdir(exist_ok=True)

def save_json(name, value):
    temp = RUN / (name + '.pending')
    temp.write_text(json.dumps(value, indent=2), encoding='utf-8')
    temp.replace(RUN / name)

def save_checkpoint(path, value):
    temp = path.with_suffix('.pending')
    torch.save(value, temp)
    temp.replace(path)

config = dict(source=str(SOURCE), checkpoint_sha256=sha(CHECKPOINT),
              manifest_sha256=sha(SOURCE / 'split_manifest.csv'), classes=CLASSES,
              epochs=EPOCHS, patience=PATIENCE, batch_size=BATCH_SIZE,
              seed=SEED, image_size=224, dropout=0.4, label_smoothing=0.05,
              weight_decay=0.01, backbone_lr=1e-5, head_lr=5e-5)
if BALANCED:
    config.update(initial_checkpoint=str(CHECKPOINT), sampling='equal_class_probability',
                  loss_class_weights=False)
if RESUME_RUN:
    assert json.loads((RUN / 'config.json').read_text()) == config, 'Resume configuration differs.'
    assert (RUN / 'last.pth').is_file(), 'Resume checkpoint missing.'
else:
    save_json('config.json', config)
    save_json('class_order.json', CLASSES)
    shutil.copy2(SOURCE / 'split_manifest.csv', RUN / 'source_split_manifest.csv')
print('Candidate run:', RUN)
print('Original prepared dataset stays at:', SOURCE / 'dataset')

# %% Cache train/validation data and evaluate the current checkpoint first.
MEAN, STD = [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]
train_transform = transforms.Compose([
    transforms.RandomResizedCrop(224, scale=(0.7, 1.0), ratio=(0.9, 1.1)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(12, interpolation=transforms.InterpolationMode.BILINEAR),
    transforms.ColorJitter(brightness=0.12, contrast=0.12, saturation=0.1, hue=0.01),
    transforms.ToTensor(), transforms.Normalize(MEAN, STD),
    transforms.RandomErasing(p=0.15, scale=(0.02, 0.08)),
])
eval_transform = transforms.Compose([
    transforms.Resize(256), transforms.CenterCrop(224),
    transforms.ToTensor(), transforms.Normalize(MEAN, STD),
])
save_json('preprocessing.json', dict(image_size=224, resize_size=256, mean=MEAN, std=STD,
                                   training=str(train_transform), evaluation=str(eval_transform)))
CACHE = None if LOCAL else Path('/content/silvamang_retrain') / config['manifest_sha256'][:16]
if CACHE is not None:
    CACHE.mkdir(parents=True, exist_ok=True)

def cache_split(split):
    subset = frame[frame['split'] == split].copy()
    paths = []
    for row in tqdm(subset.itertuples(), total=len(subset), desc=f'Caching {split}'):
        original = (SOURCE / row.saved_path).resolve()
        assert original.is_relative_to(SOURCE.resolve()), f'Invalid saved path: {row.saved_path}'
        assert original.is_file(), f'Missing image: {original}'
        if LOCAL:
            paths.append(str(original))
            continue
        dest = CACHE / f'{row.sha256_rgb}{original.suffix}'
        if not dest.exists() or dest.stat().st_size != original.stat().st_size:
            temp = dest.with_suffix('.pending')
            shutil.copyfile(original, temp)
            temp.replace(dest)
        paths.append(str(dest))
    subset['path'] = paths
    return subset

class Images(Dataset):
    def __init__(self, rows, transform):
        self.rows, self.transform = rows.reset_index(drop=True), transform
    def __len__(self):
        return len(self.rows)
    def __getitem__(self, index):
        row = self.rows.iloc[index]
        with Image.open(row['path']) as image:
            tensor = self.transform(ImageOps.exif_transpose(image).convert('RGB'))
        return tensor, int(row['label'])

train_rows, val_rows = cache_split('train'), cache_split('val')
sampler = None
if BALANCED:
    train_frequencies = train_rows['label'].value_counts()
    sample_weights = train_rows['label'].map(lambda label: 1.0 / train_frequencies[label])
    sampler = WeightedRandomSampler(torch.as_tensor(sample_weights.to_numpy(), dtype=torch.double),
                                    num_samples=len(train_rows), replacement=True)
    mass = sample_weights.groupby(train_rows['label']).sum()
    assert np.allclose(mass.to_numpy(), 1.0), 'Sampler does not balance the classes.'
    pd.DataFrame({'class_name': CLASSES,
                  'train_images': train_frequencies.reindex(range(len(CLASSES))).values,
                  'expected_samples_per_epoch': len(train_rows) / len(CLASSES)}).to_csv(
                      RUN / 'sampling_plan.csv', index=False)
train_loader = DataLoader(Images(train_rows, train_transform), batch_size=BATCH_SIZE,
                          shuffle=sampler is None, sampler=sampler, num_workers=0, pin_memory=DEVICE.type == 'cuda')
val_loader = DataLoader(Images(val_rows, eval_transform), batch_size=BATCH_SIZE,
                        shuffle=False, num_workers=0, pin_memory=DEVICE.type == 'cuda')

def make_model():
    net = models.efficientnet_b0(weights=None, dropout=config['dropout'])
    net.classifier[1] = nn.Linear(net.classifier[1].in_features, len(CLASSES))
    return net.to(DEVICE)

model = make_model()
initial = torch.load(CHECKPOINT, map_location='cpu', weights_only=True)
initial_classes = initial.get('classes', initial.get('training_config', {}).get('classes'))
assert initial_classes == CLASSES, 'Checkpoint labels do not match original split.'
recorded_manifest = initial.get('training_config', {}).get('manifest_sha256')
assert recorded_manifest == config['manifest_sha256'], 'Checkpoint belongs to a different dataset split.'
model.load_state_dict(initial['model_state_dict'], strict=True)
del initial

@torch.inference_mode()
def evaluate(net, loader):
    net.eval()
    truth, predicted = [], []
    total_loss = 0.0
    for images, labels in tqdm(loader, desc='Evaluating', leave=False):
        images, labels = images.to(DEVICE), labels.to(DEVICE)
        logits = net(images)
        total_loss += nn.functional.cross_entropy(logits, labels, reduction='sum').item()
        truth.extend(labels.cpu().tolist())
        predicted.extend(logits.argmax(1).cpu().tolist())
    metrics = dict(loss=total_loss / len(truth), accuracy=accuracy_score(truth, predicted),
                   macro_f1=f1_score(truth, predicted, labels=list(range(len(CLASSES))),
                                     average='macro', zero_division=0))
    return metrics, truth, predicted

baseline, baseline_truth, baseline_predictions = evaluate(model, val_loader)
save_json('current_model_validation.json', baseline)
save_json('current_per_class_validation.json', classification_report(
    baseline_truth, baseline_predictions, labels=list(range(len(CLASSES))),
    target_names=CLASSES, output_dict=True, zero_division=0))
print('Current checkpoint validation:', baseline)

# %% Train a separate candidate. BatchNorm statistics stay frozen during training.
frequencies = train_rows['label'].value_counts().reindex(range(len(CLASSES))).values
weights = np.sqrt(frequencies.sum() / (len(CLASSES) * frequencies))
weights = torch.tensor(weights / weights.mean(), dtype=torch.float32, device=DEVICE)
criterion = nn.CrossEntropyLoss(weight=None if BALANCED else weights, label_smoothing=config['label_smoothing'])
optimizer = torch.optim.AdamW([
    {'params': model.features.parameters(), 'lr': config['backbone_lr']},
    {'params': model.classifier.parameters(), 'lr': config['head_lr']},
], weight_decay=config['weight_decay'])
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-6)
best_score, stale, start, history = -1.0, 0, 0, []
if RESUME_RUN:
    state = torch.load(RUN / 'last.pth', map_location='cpu', weights_only=True)
    model.load_state_dict(state['model_state_dict'])
    optimizer.load_state_dict(state['optimizer'])
    scheduler.load_state_dict(state['scheduler'])
    best_score, stale, start, history = state['best_score'], state['stale'], state['epoch'], state['history']
    torch.set_rng_state(state['torch_rng'])
    if DEVICE.type == 'cuda':
        torch.cuda.set_rng_state_all(state['cuda_rng'])
    del state

for epoch in range(start, EPOCHS):
    if stale >= PATIENCE:
        break
    model.train()
    for module in model.modules():
        if isinstance(module, nn.modules.batchnorm._BatchNorm):
            module.eval()
    running_loss, correct, total = 0.0, 0, 0
    for images, labels in tqdm(train_loader, desc=f'Epoch {epoch+1}/{EPOCHS}'):
        images, labels = images.to(DEVICE), labels.to(DEVICE)
        optimizer.zero_grad(set_to_none=True)
        logits = model(images)
        loss = criterion(logits, labels)
        assert torch.isfinite(loss), 'Non-finite loss; stop and inspect data.'
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        running_loss += loss.item() * len(labels)
        correct += (logits.argmax(1) == labels).sum().item()
        total += len(labels)
    metrics, val_truth, val_predictions = evaluate(model, val_loader)
    history.append(dict(epoch=epoch+1, train_loss=running_loss/total, train_accuracy=correct/total,
                        val_loss=metrics['loss'], val_accuracy=metrics['accuracy'], val_macro_f1=metrics['macro_f1']))
    if metrics['macro_f1'] > best_score + 1e-4:
        best_score, stale = metrics['macro_f1'], 0
        save_checkpoint(RUN / 'efficientnet_b0_best.pth', dict(
            model_state_dict=model.state_dict(), classes=CLASSES, image_size=224,
            model_name='efficientnet_b0', epoch=epoch+1, validation=metrics, training_config=config))
        save_json('best_per_class_validation.json', classification_report(
            val_truth, val_predictions, labels=list(range(len(CLASSES))),
            target_names=CLASSES, output_dict=True, zero_division=0))
    else:
        stale += 1
    scheduler.step()
    save_checkpoint(RUN / 'last.pth', dict(model_state_dict=model.state_dict(), optimizer=optimizer.state_dict(),
        scheduler=scheduler.state_dict(), best_score=best_score, stale=stale, epoch=epoch+1, history=history,
        torch_rng=torch.get_rng_state(), cuda_rng=torch.cuda.get_rng_state_all() if DEVICE.type == 'cuda' else []))
    pd.DataFrame(history).to_csv(RUN / 'training_history.csv', index=False)
    print(history[-1])

best = torch.load(RUN / 'efficientnet_b0_best.pth', map_location='cpu', weights_only=True)
comparison = dict(current=baseline, candidate=best['validation'],
                  improved_validation_macro_f1=best['validation']['macro_f1'] > baseline['macro_f1'] + 1e-4,
                  deployed=False, test_used_for_selection=False)
save_json('validation_comparison.json', comparison)
chart = pd.DataFrame(history)
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
chart.plot(x='epoch', y=['train_accuracy', 'val_accuracy'], ax=axes[0])
chart.plot(x='epoch', y='val_macro_f1', ax=axes[1])
axes[1].axhline(baseline['macro_f1'], color='red', linestyle='--', label='Current model')
axes[1].legend()
fig.tight_layout()
fig.savefig(FIGURES / 'training_curves.png', dpi=160)
if not LOCAL:
    plt.show()
print(json.dumps(comparison, indent=2))
print('Saved candidate:', RUN / 'efficientnet_b0_best.pth')
print('The app has NOT been changed. Review validation_comparison.json before testing/exporting.')

# %% Optional final evaluation: run once after selecting this candidate by validation.
RUN_FINAL_TEST = False
if RUN_FINAL_TEST:
    assert comparison['improved_validation_macro_f1'], 'Candidate did not improve validation macro-F1.'
    assert not (RUN / 'test_metrics.json').exists(), 'Test report already exists; avoid repeated test selection.'
    model.load_state_dict(best['model_state_dict'])
    test_rows = cache_split('test')
    test_loader = DataLoader(Images(test_rows, eval_transform), batch_size=BATCH_SIZE, num_workers=0)
    metrics, truth, predicted = evaluate(model, test_loader)
    save_json('test_metrics.json', metrics)
    save_json('classification_report.json', classification_report(truth, predicted,
        labels=list(range(len(CLASSES))), target_names=CLASSES, output_dict=True, zero_division=0))
    pd.DataFrame(confusion_matrix(truth, predicted, labels=list(range(len(CLASSES)))),
                 index=CLASSES, columns=CLASSES).to_csv(RUN / 'confusion_matrix.csv')
    print('Final held-out test:', metrics)
else:
    print('Test set untouched. Set RUN_FINAL_TEST=True only after selecting the candidate.')
