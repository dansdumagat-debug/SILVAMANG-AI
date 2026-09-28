"""Compare fixed preprocessing alternatives on validation only, not test."""
import json
import hashlib
from pathlib import Path
import numpy as np
import pandas as pd
from PIL import Image, ImageOps
import torch
from torchvision import models, transforms
from sklearn.metrics import accuracy_score, f1_score, classification_report
from tqdm import tqdm

root = Path(__file__).resolve().parents[1]
source = root / 'dataset/retraining/EfficientNet-B0/rebuild_20260926'
run = root / 'artifacts/classifier_balanced/balanced_20260928T103555259036Z'
out = run / 'preprocessing_validation'
out.mkdir(exist_ok=True)
torch.set_num_threads(2)
checkpoint_path = run / 'efficientnet_b0_best.pth'
c = torch.load(checkpoint_path, map_location='cpu', weights_only=True)
classes = c['classes']
model = models.efficientnet_b0(weights=None)
model.classifier[1] = torch.nn.Linear(1280, len(classes))
model.load_state_dict(c['model_state_dict'], strict=True)
model.eval()
frame = pd.read_csv(source / 'split_manifest.csv')
assert hashlib.sha256((source / 'split_manifest.csv').read_bytes()).hexdigest() == c['training_config']['manifest_sha256']
frame = frame[frame['split'] == 'val'].reset_index(drop=True)
normalize = transforms.Compose([transforms.ToTensor(), transforms.Normalize([.485,.456,.406],[.229,.224,.225])])
center = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224)])
def letterbox(image):
    resized = ImageOps.contain(image, (224,224), method=Image.Resampling.BILINEAR)
    result = Image.new('RGB', (224,224), (124,116,104))
    result.paste(resized, ((224-resized.width)//2, (224-resized.height)//2))
    return result
methods = {'center_crop': center, 'full_resize': lambda image: image.resize((224,224), Image.Resampling.BILINEAR), 'letterbox': letterbox}
preds = {name: [] for name in methods}
with torch.inference_mode():
    for start in tqdm(range(0,len(frame),8), desc='Validation preprocessing'):
        images = []
        for row in frame.iloc[start:start+8].itertuples():
            with Image.open(source / row.saved_path) as image:
                images.append(ImageOps.exif_transpose(image).convert('RGB'))
        for name, method in methods.items():
            logits = model(torch.stack([normalize(method(image)) for image in images]))
            assert torch.isfinite(logits).all()
            preds[name].extend(logits.argmax(1).tolist())
truth = frame['label'].tolist()
summary = {'split': 'val', 'images': len(frame), 'checkpoint_sha256': hashlib.sha256(checkpoint_path.read_bytes()).hexdigest(), 'deployed': False, 'methods': {}}
for name, values in preds.items():
    summary['methods'][name] = dict(accuracy=accuracy_score(truth,values),macro_f1=f1_score(truth,values,average='macro',labels=list(range(29)),zero_division=0))
    (out / f'{name}_per_class.json').write_text(json.dumps(classification_report(truth,values,target_names=classes,labels=list(range(29)),output_dict=True,zero_division=0),indent=2))
(out / 'comparison.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2),flush=True)
