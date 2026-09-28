"""Training-only quality flags; heuristics are review prompts, never label edits."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from PIL import Image, ImageOps
from tqdm import tqdm

root = Path(__file__).resolve().parents[1]
source = root / 'dataset/retraining/EfficientNet-B0/rebuild_20260926'
out = root / 'artifacts/dataset_quality_review'
out.mkdir(parents=True, exist_ok=True)
manifest = pd.read_csv(source / 'split_manifest.csv')
rows = []
for row in tqdm(manifest[manifest['split'] == 'train'].itertuples(), desc='Training quality'):
    record = dict(source=row.source, saved_path=row.saved_path, class_name=row.class_name,
                  sha256_rgb=row.sha256_rgb, group=row.group)
    try:
        with Image.open(source / row.saved_path) as image:
            image = ImageOps.exif_transpose(image).convert('RGB')
            image.load()
            width, height = image.size
            small = np.asarray(image.resize((128, 128)).convert('L'), dtype=float)
            diff = np.asarray(image.resize((9, 8)).convert('L'))
            dhash = ''.join('1' if x else '0' for x in (diff[:, 1:] > diff[:, :-1]).flat)
            record.update(width=width, height=height, contrast=float(small.std()),
                          gradient=float((np.abs(np.diff(small, axis=0)).mean()+np.abs(np.diff(small, axis=1)).mean())/2),
                          perceptual_hash=f'{int(dhash, 2):016x}')
            flags = []
            if min(width, height) < 224: flags.append('small_image')
            if max(width,height)/min(width,height) > 2: flags.append('wide_or_tall_center_crop_risk')
            if small.std() < 12: flags.append('low_contrast')
            if record['gradient'] < 3: flags.append('low_detail_review')
            record['flags'] = ';'.join(flags)
    except Exception as exc:
        record.update(flags='unreadable', error=str(exc))
    rows.append(record)
data = pd.DataFrame(rows)
data.to_csv(out / 'training_quality.csv', index=False)
data[data['flags'] != ''].to_csv(out / 'quality_review_queue.csv', index=False)
# Equal perceptual hashes are proposals only: unrelated low-detail images may collide.
matches = data[data['perceptual_hash'].notna() & data['perceptual_hash'].duplicated(keep=False)]
matches.sort_values('perceptual_hash').to_csv(out / 'possible_visual_duplicates.csv', index=False)
summary = dict(train_images=len(data), flagged_for_review=int((data['flags'] != '').sum()),
               unreadable=int((data['flags'] == 'unreadable').sum()),
               possible_duplicate_images=len(matches), labels_changed=0, images_deleted=0)
(out / 'summary.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
