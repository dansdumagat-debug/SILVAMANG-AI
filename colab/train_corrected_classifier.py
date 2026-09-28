"""Fresh ImageNet experiment on corrected groups. Never deploys or tests automatically."""
import argparse
import hashlib
import json
import random
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image, ImageOps
from sklearn.metrics import accuracy_score, f1_score, classification_report
from tqdm import tqdm


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    tmp = path.with_suffix('.pending')
    tmp.write_text(json.dumps(data, indent=2), encoding='utf-8')
    tmp.replace(path)


def checkpoint(path, data):
    tmp = path.with_suffix('.pending')
    torch.save(data, tmp)
    tmp.replace(path)


class Images(Dataset):
    def __init__(self, frame, source, transform):
        self.rows = frame.reset_index(drop=True)
        self.source, self.transform = source, transform
    def __len__(self):
        return len(self.rows)
    def __getitem__(self, index):
        row = self.rows.iloc[index]
        with Image.open(self.source / row.saved_path) as im:
            tensor = self.transform(ImageOps.exif_transpose(im).convert('RGB'))
        return tensor, int(row.label)


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument('--resume', type=Path)
    args = parser.parse_args()
    source = root / 'dataset/retraining/EfficientNet-B0/rebuild_20260926'
    proposal = root / 'artifacts/dataset_quality_review/proposed_split_manifest.csv'
    classes = json.loads((source / 'class_order.json').read_text())
    frame = pd.read_csv(proposal)
    original = pd.read_csv(source / 'split_manifest.csv')
    assert len(classes) == 29 and len(set(classes)) == 29
    assert not frame.sha256_rgb.duplicated().any()
    assert frame.groupby('group')['split'].nunique().max() == 1
    assert set(frame.sha256_rgb) <= set(original.sha256_rgb)
    assert set(frame.loc[frame.split == 'test', 'sha256_rgb']) == set(original.loc[original.split == 'test', 'sha256_rgb'])
    merged = frame.merge(original, on='sha256_rgb', suffixes=('', '_original'), validate='one_to_one')
    for name in ['source', 'class_name', 'label', 'split', 'saved_path']:
        assert (merged[name] == merged[name + '_original']).all(), f'Unexpected changes to {name}'
    assert all(classes[int(r.label)] == r.class_name for r in frame.itertuples())
    counts = pd.crosstab(frame.class_name, frame.split).reindex(classes, fill_value=0)
    assert (counts[['train', 'val', 'test']] > 0).all().all()
    for row in frame.itertuples():
        path = (source / row.saved_path).resolve()
        assert path.is_relative_to(source.resolve()) and path.is_file(), path
    random.seed(42); np.random.seed(42); torch.manual_seed(42)
    torch.set_num_threads(2)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    run = args.resume or root / 'artifacts/classifier_corrected' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    run.mkdir(parents=True, exist_ok=True)
    config = dict(source=str(source), manifest_sha256=digest(proposal),
                  original_manifest_sha256=digest(source / 'split_manifest.csv'),
                  initialization='ImageNet EfficientNet_B0_Weights.DEFAULT; fresh 29-class head',
                  classes=classes, head_epochs=3, finetune_epochs=22, patience=6,
                  batch_size=8, seed=42, image_size=224, weight_decay=0.01,
                  head_lr=0.001, finetune_backbone_lr=0.00003, finetune_head_lr=0.0001,
                  label_smoothing=0.05, dropout=0.4,
                  evaluation_limit='Known burst grouping corrected; no claim of exhaustive source independence. Original test is development-exposed; acquire new independent final evaluation images.')
    if args.resume:
        assert json.loads((run / 'config.json').read_text()) == config
    else:
        write_json(run / 'config.json', config)
        (run / 'split_manifest.csv').write_bytes(proposal.read_bytes())
        write_json(run / 'class_order.json', classes)
        counts.to_csv(run / 'split_counts.csv')
    print('Run:', run, flush=True)
    print('Splits:', frame.split.value_counts().to_dict(), flush=True)
    print('Original images read in place; app model and test evaluation untouched.', flush=True)
    mean, std = [.485,.456,.406], [.229,.224,.225]
    train_transform = transforms.Compose([
        transforms.RandomResizedCrop(224, scale=(.75,1.), ratio=(.9,1.1)),
        transforms.RandomHorizontalFlip(), transforms.RandomRotation(12, interpolation=transforms.InterpolationMode.BILINEAR),
        transforms.ColorJitter(.12,.12,.1,.01), transforms.ToTensor(), transforms.Normalize(mean,std),
        transforms.RandomErasing(p=.1, scale=(.02,.06)),
    ])
    eval_transform = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224),
                                        transforms.ToTensor(), transforms.Normalize(mean,std)])
    write_json(run / 'preprocessing.json', dict(train=str(train_transform), evaluation=str(eval_transform)))
    train_rows = frame[frame.split == 'train']
    train_loader = DataLoader(Images(train_rows,source,train_transform),batch_size=8,shuffle=True,num_workers=0)
    val_loader = DataLoader(Images(frame[frame.split == 'val'],source,eval_transform),batch_size=8,num_workers=0)
    print('Loading fresh ImageNet initialization...', flush=True)
    model = models.efficientnet_b0(weights=None if args.resume else models.EfficientNet_B0_Weights.DEFAULT, dropout=.4)
    model.classifier[1] = nn.Linear(1280, len(classes))
    model.to(device)
    freq = train_rows.label.value_counts().reindex(range(len(classes))).to_numpy()
    weights = np.sqrt(freq.sum() / (len(classes)*freq)); weights /= weights.mean()
    criterion = nn.CrossEntropyLoss(weight=torch.tensor(weights,dtype=torch.float32,device=device),label_smoothing=.05)
    optimizer = torch.optim.AdamW([
        {'params':model.features.parameters(),'lr':0.},
        {'params':model.classifier.parameters(),'lr':.001}],weight_decay=.01)
    start,best,stale,history = 0,-1.,0,[]
    if args.resume:
        state = torch.load(run/'last.pth',map_location='cpu',weights_only=True)
        model.load_state_dict(state['model_state_dict']);optimizer.load_state_dict(state['optimizer'])
        start,best,stale,history = state['epoch'],state['best'],state['stale'],state['history']
        torch.set_rng_state(state['torch_rng']);random.setstate(state['python_rng'])
        if device.type == 'cuda':torch.cuda.set_rng_state_all(state['cuda_rng'])
    write_json(run/'status.json',dict(state='running',completed_epoch=start))
    for epoch in range(start,25):
        if stale >= 6:break
        head = epoch < 3
        for p in model.features.parameters():p.requires_grad_(not head)
        decay = (1 + np.cos(np.pi*max(0,epoch-3)/21))/2
        optimizer.param_groups[0]['lr'] = 0. if head else 1e-6+(3e-5-1e-6)*decay
        optimizer.param_groups[1]['lr'] = .001 if head else 1e-6+(1e-4-1e-6)*decay
        model.train()
        for m in model.modules():
            if isinstance(m,nn.modules.batchnorm._BatchNorm):m.eval()
        correct,total,loss_total=0,0,0.
        for images,labels in tqdm(train_loader,desc=f'Epoch {epoch+1}/25 '+('head' if head else 'finetune')):
            images,labels=images.to(device),labels.to(device)
            optimizer.zero_grad(set_to_none=True)
            logits=model(images);loss=criterion(logits,labels)
            assert torch.isfinite(loss)
            loss.backward();nn.utils.clip_grad_norm_(model.parameters(),1.);optimizer.step()
            total+=len(labels);correct+=(logits.argmax(1)==labels).sum().item();loss_total+=loss.item()*len(labels)
        model.eval();truth,predicted=[],[];val_loss=0.
        with torch.inference_mode():
            for images,labels in tqdm(val_loader,desc='Validation'):
                images,labels=images.to(device),labels.to(device);logits=model(images)
                assert torch.isfinite(logits).all()
                val_loss+=nn.functional.cross_entropy(logits,labels,reduction='sum').item()
                truth+=labels.cpu().tolist();predicted+=logits.argmax(1).cpu().tolist()
        metrics=dict(accuracy=accuracy_score(truth,predicted),macro_f1=f1_score(truth,predicted,labels=list(range(29)),average='macro',zero_division=0),loss=val_loss/len(truth))
        history.append(dict(epoch=epoch+1,phase='head' if head else 'finetune',train_accuracy=correct/total,train_loss=loss_total/total,**metrics))
        if metrics['macro_f1'] > best+1e-4:
            best,stale=metrics['macro_f1'],0
            checkpoint(run/'efficientnet_b0_best.pth',dict(model_state_dict=model.state_dict(),classes=classes,image_size=224,model_name='efficientnet_b0',epoch=epoch+1,validation=metrics,training_config=config))
            write_json(run/'best_per_class_validation.json',classification_report(truth,predicted,labels=list(range(29)),target_names=classes,output_dict=True,zero_division=0))
        elif not head:stale+=1
        checkpoint(run/'last.pth',dict(model_state_dict=model.state_dict(),optimizer=optimizer.state_dict(),epoch=epoch+1,best=best,stale=stale,history=history,torch_rng=torch.get_rng_state(),python_rng=random.getstate(),cuda_rng=torch.cuda.get_rng_state_all() if device.type=='cuda' else []))
        pd.DataFrame(history).to_csv(run/'training_history.csv',index=False)
        write_json(run/'status.json',dict(state='running',completed_epoch=epoch+1,stale_epochs=stale,best_validation_macro_f1=best))
        print(history[-1],flush=True)
    write_json(run/'status.json',dict(state='complete',completed_epoch=history[-1]['epoch'],reason='early_stopping' if stale>=6 else 'epoch_limit',best_validation_macro_f1=best,deployed=False,test_evaluated=False))
    print('Training complete; review corrected-split validation. No deployment or test evaluation performed.',flush=True)


if __name__ == '__main__':main()
