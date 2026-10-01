"""Conservative automated screening; source labels are not expert verification."""
import argparse
import csv
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'dataset/retraining/EfficientNet-B0/rebuild_20260926'


def read_csv(path):
    with path.open(encoding='utf-8-sig',newline='') as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    if not rows:
        return
    with path.open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]))
        writer.writeheader();writer.writerows(rows)


def image_info(path):
    with Image.open(path) as raw:
        im=ImageOps.exif_transpose(raw).convert('RGB')
        im.load()
        exact=hashlib.sha256(str(im.size).encode()+im.tobytes()).hexdigest()
        gray=np.asarray(im.convert('L').resize((9,8),Image.Resampling.LANCZOS))
        bits=(gray[:,1:]>gray[:,:-1]).ravel()
        dhash=sum(int(b)<<i for i,b in enumerate(bits))
        return exact,dhash,im.size


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--queue',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    classes=json.loads((SOURCE/'class_order.json').read_text())
    baseline=read_csv(ROOT/'artifacts/dataset_quality_review/proposed_split_manifest.csv')
    original=read_csv(SOURCE/'split_manifest.csv')
    metadata=read_csv(ROOT/'dataset/metadata/candidate_image_manifest.csv')
    by_id={r['candidate_id']:r for r in metadata}
    group_observations=defaultdict(set)
    for row in metadata:
        match=re.search(r'inaturalist\.org/observations/(\d+)',row['source_record_url'])
        if match:
            record=row['source_record_id']
            key=record if ':' in record else 'gbif:'+record
            group_observations[key].add('inat:'+match[1])
    existing_observations=set()
    for row in original:
        existing_observations.update(group_observations[row['group']])
        if row['group'].startswith('inat:'):
            existing_observations.add(row['group'])
    exacts={r['sha256_rgb'] for r in original}
    fingerprints=[]
    for index,row in enumerate(original):
        path=(SOURCE/row['saved_path']).resolve()
        assert path.is_relative_to(SOURCE.resolve())
        exact,fingerprint,_=image_info(path)
        exacts.add(exact)
        fingerprints.append((fingerprint,row['source'],row['split']))
        if index%500==0: print(f'Checking existing image fingerprints {index}/{len(original)}',flush=True)
    fields=list(baseline[0])
    for row in baseline:
        row['saved_path']=(SOURCE/row['saved_path']).relative_to(ROOT).as_posix()
    write_csv(args.output/'baseline_manifest.csv',baseline)
    combined=list(baseline)
    audit=[]
    for candidate in read_csv(args.queue):
        row=dict(candidate)
        reasons=[]
        current=by_id.get(row['candidate_id'],{})
        name=row['scientific_name'].replace(' ','_')
        path=(ROOT/row['file_path']).resolve()
        if not path.is_relative_to(ROOT/'dataset/candidates'):
            raise ValueError('Candidate path outside candidates directory')
        if current.get('review_status') in {'flagged','rejected'}: reasons.append('existing_manual_rejection_or_flag')
        if row['source']!='iNaturalist research-grade observation': reasons.append('source_not_research_grade')
        if row['license'] not in {'cc0','cc-by','cc-by-sa'}: reasons.append('license_not_allowed')
        if name not in classes: reasons.append('unsupported_species')
        if row['source_record_id'] in existing_observations: reasons.append('observation_already_in_existing_dataset')
        nearest='';distance=''
        try:
            if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']: reasons.append('file_hash_changed')
            exact,fingerprint,size=image_info(path)
            if min(size)<224: reasons.append('image_too_small')
            if exact in exacts: reasons.append('exact_duplicate')
            distance,nearest,split=min(((fingerprint^value).bit_count(),source,split) for value,source,split in fingerprints)
            if distance<=6: reasons.append('possible_visual_duplicate')
        except (OSError,ValueError) as error:
            reasons.append('unreadable_image')
        row.update(auto_decision='excluded' if reasons else 'eligible_source_labeled',
                   auto_reasons=';'.join(reasons),nearest_existing_image=nearest,dhash_distance=distance,
                   botanical_verification='not_performed',plant_part_verification='not_performed')
        audit.append(row)
        if reasons: continue
        combined.append(dict(source=row['file_path'],label=str(classes.index(name)),class_name=name,
                             sha256_rgb=exact,group=row['source_record_id'],split='train',saved_path=row['file_path']))
        exacts.add(exact)
        fingerprints.append((fingerprint,row['file_path'],'new_train'))
    assert len({r['sha256_rgb'] for r in combined})==len(combined)
    groups=defaultdict(set)
    for row in combined: groups[row['group']].add(row['split'])
    assert all(len(splits)==1 for splits in groups.values())
    for split in ['val','test']:
        assert [r for r in combined if r['split']==split]==[r for r in baseline if r['split']==split]
    write_csv(args.output/'split_manifest.csv',combined)
    write_csv(args.output/'screening.csv',audit)
    (args.output/'class_order.json').write_text(json.dumps(classes,indent=2))
    additions=combined[len(baseline):]
    summary=dict(state='prepared',candidates=len(audit),added_to_training=len(additions),excluded=len(audit)-len(additions),
                 source_root=str(ROOT),baseline_images=len(baseline),combined_images=len(combined),
                 added_observations=len({r['group'] for r in additions}),validation_unchanged=True,test_unchanged=True,
                 model_trained=False,deployed=False,expert_verified=False,
                 limitation='Source research-grade labels only. Perceptual hash screening is heuristic, not proof of independence or label correctness.')
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':main()
