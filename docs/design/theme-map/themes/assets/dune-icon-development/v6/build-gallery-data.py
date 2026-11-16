"""Append different-hue palette tests and label prior tonal experiment accurately."""
import json, shutil, hashlib
from pathlib import Path
from PIL import Image
here=Path(__file__).resolve().parent
root=here.parent
m=json.loads((here/'prompts.json').read_text())
d=json.loads((root/'data.js').read_text().removeprefix('window.duneIconData = ').strip().rstrip(';'))
previous=[c for c in d['concepts'] if c['version']!='v6']
assert len(previous)==103
for c in previous:
    if c['version']=='v5':
        c['name']=c['parentName']+' · 골드 명도차'
        c['variant']='골드 명도차 실험'
        c['desc']=str(c['sourceNumber'])+'번의 이전 골드·앰버 명도차 실험 (사용자 교정 전)'
checks=[]
for c in m['concepts']:
    receipt=json.loads((here/'receipts'/f"{c['id']}.json").read_text())
    dest=here/f"{c['id']}.png"
    shutil.copy2(receipt['generated_path'],dest)
    with Image.open(dest) as im:
        assert im.width==im.height and im.width>=1024
        assert 'A' not in im.getbands() or im.getchannel('A').getextrema()==(255,255)
        checks.append(dict(id=c['id'],size=list(im.size),opaque=True,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),cornerRGB=list(im.convert('RGB').getpixel((0,0)))))
assert len(checks)==9 and len({c['sha256'] for c in checks})==9
m['status']='generated-different-hue-test-not-approved'
d['concepts']=previous+[{k:v for k,v in c.items() if k not in ['prompt','reference']} for c in m['concepts']]
d['latestVersion']='v6'
(root/'data.js').write_text('window.duneIconData = '+json.dumps(d,ensure_ascii=False,indent=2)+';\n')
(here/'prompts.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(here/'asset-qa.json').write_text(json.dumps(dict(count=9,checks=checks),ensure_ascii=False,indent=2)+'\n')
p=root/'v5/prompts.json';old=json.loads(p.read_text());old['status']='superseded-misinterpretation-preserved';old['clarification']='assistant가 투톤을 골드·앰버 명도 차이로 해석한 실험. 이후 사용자가 다른 컬러도 사용 가능하다는 뜻이라고 교정했다. 기존 프롬프트와 결과는 이력으로 보존.';p.write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
print('9 different-hue edits copied; total112; square/opaque/unique verified')
