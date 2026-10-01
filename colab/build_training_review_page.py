"""Build an offline training-photo review with downloadable decisions; never edit data."""
import argparse
import json
from pathlib import Path

import pandas as pd
from PIL import Image, ImageOps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--queue', type=Path, required=True)
    parser.add_argument('--quality', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--decisions', type=Path, help='Prefill a previous review without changing training data.')
    args = parser.parse_args()
    frame = pd.read_csv(args.queue).fillna('')
    assert set(frame.split) == {'train'} and frame.sha256_rgb.is_unique
    quality = pd.read_csv(args.quality).fillna('').set_index('sha256_rgb')
    assert quality.index.is_unique
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'thumbnails').mkdir()
    records = []
    for row in frame.itertuples():
        path = Path(row.local_image)
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image).convert('RGB')
            image.thumbnail((420, 320))
            image.save(args.output / 'thumbnails' / (row.sha256_rgb + '.jpg'), quality=85)
        flags = quality.loc[row.sha256_rgb, 'flags'] if row.sha256_rgb in quality.index else ''
        records.append(dict(id=row.sha256_rgb, species=row.class_name, source=row.source,
                            original=path.resolve().as_uri(), flags=flags,
                            decision='unreviewed', notes=''))
    if args.decisions:
        saved = json.loads(args.decisions.read_text(encoding='utf-8'))
        assert saved['schema'] == 1
        by_id = {r['id']: r for r in saved['decisions']}
        assert set(by_id) == {r['id'] for r in records}
        for record in records:
            decision = by_id[record['id']]
            assert decision['species'] == record['species']
            record.update(decision=decision['decision'], notes=decision['notes'])
    data = json.dumps(records).replace('<', '\\u003c')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Training photo review</title>
<style>body{font:16px system-ui;background:#eef5f0;color:#173f32;margin:24px}header{position:sticky;top:0;background:#eef5f0;padding:12px 0;z-index:1}
button,select,input,textarea{font:inherit;padding:10px;border:1px solid #829c8f;border-radius:8px}button{background:#205d45;color:white;cursor:pointer}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}article{background:white;border-radius:12px;padding:16px;overflow-wrap:anywhere}
img{width:100%;height:260px;object-fit:contain}label{display:block;margin:12px 0}textarea{box-sizing:border-box;width:100%}.flags{color:#8c4a00}small{display:block}</style>
<h1>Review training photos</h1><p>These are training photos only. No photos or labels are changed by this page.
Check whether identifying details are visible and the recorded species is correct. Use “Needs expert check” when unsure.
“Quality usable, label unverified” means only the visible image quality was assessed; it is not confirmation of species identity.
Quality flags are suggestions, not proof that a photo is bad. Do not exclude difficult photos simply because the model struggles with them.</p>
<header><label>Species <select id="species"><option value="">All species</option></select></label>
<button id="export">Download decisions</button> <label>Restore decisions <input id="import" type="file" accept="application/json"></label>
<span id="count"></span><p>Works offline. Download decisions before closing; browser storage is only a convenience.</p></header><main id="cards"></main>
<script>const rows=DATA;
const key='silvamang-training-review-'+rows.map(r=>r.id).join('').slice(0,64);
const decisions=['unreviewed','keep','quality_usable_label_unverified','exclude_quality','exclude_duplicate','needs_expert_check'];
function restore(saved){for(const r of rows){const s=saved.find(x=>x.id===r.id);if(s&&decisions.includes(s.decision)){r.decision=s.decision;r.notes=typeof s.notes==='string'?s.notes:'';}}}
try{restore(JSON.parse(localStorage.getItem(key)||'[]'));}catch(e){}
function save(){try{localStorage.setItem(key,JSON.stringify(rows.map(({id,decision,notes})=>({id,decision,notes}))));}catch(e){} count();}
function count(){document.getElementById('count').textContent=rows.filter(r=>r.decision!=='unreviewed').length+' / '+rows.length+' reviewed';}
const species=document.getElementById('species');for(const name of [...new Set(rows.map(r=>r.species))].sort()){const o=new Option(name.replaceAll('_',' '),name);species.add(o);}
function render(){const root=document.getElementById('cards');root.replaceChildren();for(const r of rows.filter(r=>!species.value||r.species===species.value)){
const card=document.createElement('article');const title=document.createElement('h2');title.textContent=r.species.replaceAll('_',' ');card.append(title);
const link=document.createElement('a');link.href=r.original;link.target='_blank';const img=document.createElement('img');img.src='thumbnails/'+r.id+'.jpg';img.alt=r.species;img.loading='lazy';link.append(img);card.append(link);
const source=document.createElement('small');source.textContent=r.source;card.append(source);const flags=document.createElement('p');flags.className='flags';flags.textContent=r.flags||'No automatic quality flag';card.append(flags);
const label=document.createElement('label');label.textContent='Decision ';const select=document.createElement('select');for(const d of decisions)select.add(new Option(d.replaceAll('_',' '),d));select.value=r.decision;select.onchange=()=>{r.decision=select.value;save();};label.append(select);card.append(label);
const noteLabel=document.createElement('label');noteLabel.textContent='Notes / identifying evidence';const notes=document.createElement('textarea');notes.value=r.notes;notes.oninput=()=>{r.notes=notes.value;save();};noteLabel.append(notes);card.append(noteLabel);root.append(card);}count();}
species.onchange=render;
document.getElementById('export').onclick=()=>{const payload={schema:1,usage:'training_review_only',decisions:rows.map(({id,species,decision,notes})=>({id,species,decision,notes}))};
const url=URL.createObjectURL(new Blob([JSON.stringify(payload,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='training_review_decisions.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
document.getElementById('import').onchange=async e=>{try{const payload=JSON.parse(await e.target.files[0].text());if(payload.schema!==1||!Array.isArray(payload.decisions))throw Error('Invalid review file');restore(payload.decisions);save();render();}catch(err){alert('Could not restore decisions: '+err.message);}};render();</script></html>'''
    (args.output / 'index.html').write_text(page.replace('const rows=DATA;', 'const rows=' + data + ';'), encoding='utf-8')
    (args.output / 'summary.json').write_text(json.dumps(dict(training_photos=len(records),
        quality_flags=sum(bool(r['flags']) for r in records), labels_changed=0, images_deleted=0), indent=2))
    print(args.output / 'index.html')


if __name__ == '__main__':
    main()
