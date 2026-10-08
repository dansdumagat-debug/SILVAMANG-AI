"""CPU-limited candidate training. Never changes production or mobile models."""
import argparse
import hashlib
import json
import os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ALIASES = {'Avicennia_marina_var_rumphiana': 'Avicennia_rumphiana', 'Xylocarpus_rumphii': 'Xylocarpus_moluccensis'}
PARTS = {'leaves', 'bark', 'roots', 'flowers'}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.pending')
    tmp.write_text(json.dumps(data, indent=2), encoding='utf-8')
    tmp.replace(path)


def eligible_rows(rows, classes, baseline_hashes):
    """Reject duplicates, unsupported labels and conflicting annotations."""
    labels = {}
    for row in rows:
        labels.setdefault(row['sha256'], set()).add(ALIASES.get(row['species'], row['species']))
    accepted, seen = [], set(baseline_hashes)
    for row in rows:
        species = ALIASES.get(row['species'], row['species'])
        sha = row['sha256']
        if species not in classes or row['plant_part'] not in PARTS or sha in seen or len(labels[sha]) != 1:
            continue
        seen.add(sha)
        accepted.append({**row, 'species': species, 'label': classes.index(species)})
    return accepted


def gate(candidate, baseline):
    return (candidate['accuracy'] > baseline['accuracy'] and
            candidate['macro_f1'] >= baseline['macro_f1'] and
            all(c >= b - .05 for c, b in zip(candidate['recall'], baseline['recall'])))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, default=Path('/training'))
    p.add_argument('--feed', type=Path, default=Path('/var/www/html/storage/app/retraining-feed/manifest.json'))
    p.add_argument('--checkpoint', type=Path, default=Path('/app/models/EfficientNet-B0/efficientnet_b0_runtime.pth'))
    p.add_argument('--classes', type=Path, default=Path('/app/models/EfficientNet-B0/class_order.json'))
    p.add_argument('--minimum-new', type=int, default=20)
    args = p.parse_args()
    root = args.root
    def status(state, **data):
        write_json(root/'status.json', {'state': state, 'updated_at': datetime.now(timezone.utc).isoformat(), **data})
    try:
        classes = json.loads(args.classes.read_text())
        feed_hash = digest(args.feed)
        manifest = json.loads(args.feed.read_text())
        base_manifest = root/'baseline/manifest.json'
        if not base_manifest.exists():
            status('waiting_for_baseline', approved=len(manifest['images']))
            return
        base = json.loads(base_manifest.read_text())
        if base['classes'] != classes:
            raise ValueError('Baseline class order differs from deployed model')
        selected = eligible_rows(manifest['images'], classes, {r['original_sha256'] for r in base['images']})
        previous = json.loads((root/'completed.json').read_text()) if (root/'completed.json').exists() else {}
        signatures = sorted(f"{r['sha256']}:{r['species']}:{r['plant_part']}" for r in selected)
        config_hash = hashlib.sha256((digest(args.checkpoint)+digest(base_manifest)).encode()).hexdigest()
        previous_signatures = previous.get('signatures', []) if previous.get('config_hash') == config_hash else []
        new_count = len(set(signatures) - set(previous_signatures))
        counts = Counter(r['species'] for r in selected)
        if new_count < args.minimum_new or sum(n >= 5 for n in counts.values()) < 2:
            status('waiting_for_approved_photos', approved=len(selected), new_photos=new_count,
                   minimum_new=args.minimum_new, minimum_species=2, minimum_per_species=5,
                   previous_candidate=previous.get('candidate'),
                   previous_candidate_needs_review=bool(set(previous_signatures)-set(signatures)))
            return
        # Libraries load only when there is a sufficiently diverse approved batch.
        import torch
        from torch import nn
        from torchvision import models, transforms
        from PIL import Image, ImageOps
        torch.set_num_threads(1)
        torch.manual_seed(42)
        checkpoint = torch.load(args.checkpoint, map_location='cpu', weights_only=True)
        if [ALIASES.get(c, c) for c in checkpoint['classes']] != classes:
            raise ValueError('Checkpoint class order mismatch')
        model = models.efficientnet_b0(weights=None)
        model.classifier[1] = nn.Linear(model.classifier[1].in_features, len(classes))
        model.load_state_dict(checkpoint['model_state_dict'])
        model.eval()
        transform = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(),
            transforms.Normalize([.485,.456,.406],[.229,.224,.225])])
        cache = root/'features'/digest(args.checkpoint)
        cache.mkdir(parents=True, exist_ok=True)
        status('extracting_features', approved=len(selected), new_photos=new_count)
        def feature(path, sha):
            target = cache/(sha+'.pt')
            if target.exists():
                return torch.load(target, weights_only=True)
            if digest(path) != sha:
                raise ValueError('Training photo checksum mismatch')
            with Image.open(path) as im:
                tensor = transform(ImageOps.exif_transpose(im).convert('RGB')).unsqueeze(0)
            with torch.inference_mode():
                value = model.avgpool(model.features(tensor)).flatten(1).squeeze(0).clone()
            tmp = target.with_suffix('.pending')
            torch.save(value, tmp)
            tmp.replace(target)
            return value
        def dataset(rows, parent):
            return (torch.stack([feature(parent/r['path'], r['sha256']) for r in rows]),
                    torch.tensor([r['label'] for r in rows], dtype=torch.long))
        train_rows = [r for r in base['images'] if r['split']=='train']
        val_rows = [r for r in base['images'] if r['split']=='val']
        if set(r['label'] for r in val_rows) != set(range(len(classes))):
            raise ValueError('Validation must cover every model class')
        # Compare decoded/cropped pixel hashes too; re-encoded copies must not cross splits.
        validation_pixels = {r['pixel_sha256'] for r in val_rows}
        train_pixels = {r['pixel_sha256'] for r in train_rows}
        if validation_pixels & train_pixels:
            raise ValueError('Baseline train/validation pixels overlap')
        clean = []
        for r in selected:
            path = args.feed.parent/r['path']
            if digest(path) != r['sha256']:
                raise ValueError('Approved photo checksum mismatch')
            with Image.open(path) as im:
                image = transforms.CenterCrop(224)(transforms.Resize(256)(ImageOps.exif_transpose(im).convert('RGB')))
                pixels = hashlib.sha256(image.tobytes()).hexdigest()
            if pixels not in validation_pixels and pixels not in train_pixels:
                clean.append(r)
                train_pixels.add(pixels)
        signatures = sorted(f"{r['sha256']}:{r['species']}:{r['plant_part']}" for r in clean)
        new_count = len(set(signatures) - set(previous_signatures))
        if new_count < args.minimum_new or sum(n>=5 for n in Counter(r['species'] for r in clean).values())<2:
            status('waiting_for_unique_approved_photos', approved=len(clean), new_photos=new_count, minimum_new=args.minimum_new)
            return
        x, y = dataset(train_rows, root/'baseline')
        vx, vy = dataset(val_rows, root/'baseline')
        nx, ny = dataset(clean, args.feed.parent)
        x, y = torch.cat([x,nx]), torch.cat([y,ny])
        head = model.classifier[1]
        def metrics():
            with torch.no_grad():
                pred = head(vx).argmax(1)
            recall, f1 = [], []
            for i in range(len(classes)):
                tp = ((pred==i)&(vy==i)).sum().item()
                fp = ((pred==i)&(vy!=i)).sum().item()
                fn = ((pred!=i)&(vy==i)).sum().item()
                recall.append(tp/max(1,tp+fn))
                f1.append(2*tp/max(1,2*tp+fp+fn))
            return {'accuracy': (pred==vy).float().mean().item(), 'macro_f1': sum(f1)/len(f1), 'recall': recall}
        baseline = metrics()
        optimizer = torch.optim.AdamW(head.parameters(), lr=1e-4, weight_decay=1e-4)
        loss_fn = nn.CrossEntropyLoss()
        best, best_state = baseline, None
        history = []
        for epoch in range(1,16):
            status('training', epoch=epoch, epochs=15, approved=len(clean), baseline=baseline)
            order = torch.randperm(len(y))
            for indices in order.split(64):
                optimizer.zero_grad()
                loss = loss_fn(head(x[indices]), y[indices])
                loss.backward()
                optimizer.step()
            result = metrics()
            history.append({'epoch':epoch, **result})
            if gate(result, baseline) and result['accuracy'] > best['accuracy']:
                best, best_state = result, {k:v.detach().clone() for k,v in head.state_dict().items()}
        if digest(args.feed) != feed_hash or digest(args.checkpoint) != cache.name:
            status('source_changed_retry_required')
            return
        run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        run = root/'runs'/run_id
        run.mkdir(parents=True)
        candidate = None
        if best_state is not None:
            head.load_state_dict(best_state)
            candidate = str(run/'candidate.pth')
            torch.save({'model_name':'efficientnet_b0', 'image_size':224, 'classes':classes,
                        'model_state_dict':model.state_dict()}, candidate)
        report = {'state':'candidate_ready_for_review' if candidate else 'no_improvement', 'candidate':candidate,
                  'baseline':baseline, 'candidate_metrics':best if candidate else None, 'history':history,
                  'approved_photos':len(clean), 'method':'frozen_backbone_classifier_finetune',
                  'validation':'original fixed validation split; not an independent test result',
                  'production_changed':False, 'config_hash':config_hash}
        write_json(run/'report.json', report)
        write_json(root/'completed.json', {'signatures':signatures, 'candidate':candidate, 'config_hash':config_hash})
        status(report['state'], report=report)
    except Exception as error:
        status('error', message=str(error))
        raise

if __name__ == '__main__':
    main()
