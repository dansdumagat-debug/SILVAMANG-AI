"""Collect a small licensed, unreviewed expansion batch without changing training data."""
import collections
import csv
import html
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'silvamang_ai_service/scripts'))
import collect_inaturalist_candidates as collector


def rows():
    with collector.MANIFEST_PATH.open(encoding='utf-8-sig',newline='') as handle:
        return list(csv.DictReader(handle))


def main():
    names=['Ceriops zippeliana','Camptostemon philippinensis','Avicennia officinalis',
           'Rhizophora mucronata','Avicennia alba','Xylocarpus moluccensis']
    before=rows()
    ids={r['candidate_id'] for r in before}
    counts=collections.Counter(r['scientific_name'] for r in before)
    output=ROOT/'artifacts/additional_photo_candidates'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output.mkdir(parents=True)
    (output/'collection_plan.json').write_text(json.dumps(dict(species=names,additional_target_per_species=20,
          licenses=sorted(collector.ALLOWED_PHOTO_LICENSES),quality_grade='research',existing_counts=dict(counts)),indent=2))
    errors={}
    print('Review output:',output,flush=True)
    for name in names:
        try:
            collector.collect_species(name,counts[name]+20,max_pages=2,workers=3)
        except Exception as error:
            errors[name]=str(error)
            print(name,':',error,flush=True)
    new=[r for r in rows() if r['candidate_id'] not in ids and r['scientific_name'] in names]
    for row in new:
        row['source_group_id']=row['source_record_id']
        row['review_status']='pending'
        row['split']='unassigned'
    if new:
        with (output/'review_queue.csv').open('w',encoding='utf-8',newline='') as handle:
            writer=csv.DictWriter(handle,fieldnames=list(new[0]))
            writer.writeheader();writer.writerows(new)
    totals=dict(collections.Counter(r['scientific_name'] for r in new))
    summary=dict(downloaded=len(new),counts=totals,errors=errors,trained=False,
                 note='Source-provided species labels; verify species and plant parts. Check duplicates against all existing splits before use. Keep observation groups together.')
    (output/'summary.json').write_text(json.dumps(summary,indent=2))
    cards=[]
    for row in new:
        image=(ROOT/row['file_path']).resolve()
        assert image.is_relative_to(ROOT/'dataset') and image.is_file()
        cards.append('<article><img loading="lazy" src="'+html.escape(image.as_uri(),quote=True)+'"><h2>'+html.escape(row['scientific_name'])+
                     '</h2><p>'+html.escape(row['candidate_id'])+'</p><p>'+html.escape(row['creator'])+' — '+html.escape(row['license'])+
                     '</p><a target="_blank" rel="noopener noreferrer" href="'+html.escape(row['source_record_url'],quote=True)+'">Source observation</a><p>Pending review · Unassigned split</p></article>')
    (output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Mangrove photo review</title><style>body{font:16px sans-serif;background:#edf4ef;padding:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}article{background:white;padding:16px}img{width:100%;height:240px;object-fit:contain}h2{font-size:18px}</style><h1>Additional mangrove photo candidates</h1><p>Research-grade source labels are not a guarantee. Review before training. Keep photos from each observation in one split.</p><main>'+''.join(cards)+'</main>',encoding='utf-8')
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':main()
