"""Prepare compact deterministic 256px reference images; preserve existing split groups."""
import csv,hashlib,json,argparse
from pathlib import Path
from PIL import Image,ImageOps

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--classes',type=Path,required=True);a=p.parse_args()
 classes=json.loads(a.classes.read_text()); aliases={'Avicennia_marina_var_rumphiana':'Avicennia_rumphiana','Xylocarpus_rumphii':'Xylocarpus_moluccensis'}
 rows=list(csv.DictReader((a.source/'split_manifest.csv').open(encoding='utf-8-sig')))
 groups={}; output=[]; seen={}
 (a.output/'images').mkdir(parents=True,exist_ok=True)
 for r in rows:
  if r['split'] not in ('train','val') or 'canopy' in r['source'].lower(): continue
  name=aliases.get(r['class_name'],r['class_name'])
  if name not in classes: raise ValueError('Unknown baseline class '+name)
  g=r['group']; prior=groups.setdefault(g,r['split']);assert prior==r['split'],'Source group crosses splits'
  path=a.source/r['saved_path']; original=hashlib.sha256(path.read_bytes()).hexdigest()
  with Image.open(path) as src:
   im=ImageOps.exif_transpose(src).convert('RGB');w,h=im.size
   size=(256,int(256*h/w)) if w<=h else (int(256*w/h),256)
   im=im.resize(size,Image.Resampling.BILINEAR)
   left=round((im.width-224)/2);top=round((im.height-224)/2)
   pixels=hashlib.sha256(im.crop((left,top,left+224,top+224)).tobytes()).hexdigest()
   if pixels in seen:
    assert seen[pixels]==r['split'],'Duplicate pixels cross splits'
    continue
   seen[pixels]=r['split']
   target=a.output/'images'/(original+'.png')
   im.save(target)
  output.append(dict(path='images/'+target.name,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),original_sha256=original,pixel_sha256=pixels,label=classes.index(name),split=r['split'],group=g))
 (a.output/'manifest.json').write_text(json.dumps(dict(classes=classes,images=output,source_manifest_sha256=hashlib.sha256((a.source/'split_manifest.csv').read_bytes()).hexdigest()),indent=2))
 print('Prepared',len(output),'baseline reference images')
if __name__=='__main__':main()
