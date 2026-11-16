"""Append palette tests; preserve historical images and browser identifiers."""
import json, shutil, hashlib
from pathlib import Path
from PIL import Image
here=Path(__file__).resolve().parent
root=here.parent
manifest=json.loads((here/'prompts.json').read_text())
data=json.loads((root/'data.js').read_text().removeprefix('window.duneIconData = ').strip().rstrip(';'))
previous=[c for c in data['concepts'] if c['version']!='v5']
assert len(previous)==94
checks=[]
for c in manifest['concepts']:
    receipt=json.loads((here/'receipts'/f"{c['id']}.json").read_text())
    dest=here/f"{c['id']}.png"
    shutil.copy2(receipt['generated_path'],dest)
    with Image.open(dest) as im:
        assert im.width==im.height and im.width>=1024
        assert 'A' not in im.getbands() or im.getchannel('A').getextrema()==(255,255)
        checks.append(dict(id=c['id'],size=list(im.size),opaque=True,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),cornerRGB=list(im.convert('RGB').getpixel((0,0)))))
assert len(checks)==9 and len({c['sha256'] for c in checks})==9
manifest['status']='generated-palette-test-not-approved'
manifest['clarification']='사용자가 투톤 허용. 밝은 골드와 짙은 앰버의 공통 조합. 하이라이트와 음영은 유지.'
manifest['palette']['description']='밝은 골드 + 짙은 앰버 / 차콜 배경'
for c in manifest['concepts']:
    c['name']=c['parentName']+' · 투톤'
    c['variant']='골드·앰버 투톤'
    c['themeName']='DUNE · 골드 + 앰버'
    c['desc']=str(c['sourceNumber'])+'번을 골드·앰버 공통 투톤으로 비교'
    c['image']='v5/'+c['id']+'.png'
data['concepts']=previous+[{k:v for k,v in c.items() if k not in ['prompt','reference']} for c in manifest['concepts']]
data['latestVersion']='v5'
(root/'data.js').write_text('window.duneIconData = '+json.dumps(data,ensure_ascii=False,indent=2)+';\n')
(here/'prompts.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(here/'asset-qa.json').write_text(json.dumps(dict(count=9,checks=checks),ensure_ascii=False,indent=2)+'\n')
print('9 originals copied; 103 concepts; opaque square unique PNGs')
