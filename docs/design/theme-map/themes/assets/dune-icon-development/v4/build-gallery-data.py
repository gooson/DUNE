"""Preserve historical gallery data and append the 24 reference-based studies."""
import json, shutil, hashlib
from pathlib import Path
from PIL import Image
v4 = Path(__file__).resolve().parent
root = v4.parent
manifest = json.loads((v4/'prompts.json').read_text())
data = json.loads((root/'data.js').read_text().removeprefix('window.duneIconData = ').strip().rstrip(';'))
previous = [c for c in data['concepts'] if c['version'] != 'v4']
assert len(previous) == 70
checks = []
for c in manifest['concepts']:
    receipt = json.loads((v4/'receipts'/f"{c['id']}.json").read_text())
    dest = v4/f"{c['id']}.png"
    shutil.copy2(receipt['generated_path'], dest)
    with Image.open(dest) as im:
        assert im.width == im.height and im.width >= 1024
        assert 'A' not in im.getbands() or im.getchannel('A').getextrema() == (255,255)
        checks.append(dict(id=c['id'],size=list(im.size),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),opaque=True))
assert len(checks) == 24 and len({c['sha256'] for c in checks}) == 24
fields = ['id','number','version','group','groupName','parentId','parentNumber','parentName','themeName','palette','name','variant','desc']
data['concepts'] = previous + [dict({k:c[k] for k in fields},image=f"v4/{c['id']}.png") for c in manifest['concepts']]
data['families'] = manifest['families']
data['latestVersion'] = 'v4'
(root/'data.js').write_text('window.duneIconData = '+json.dumps(data,ensure_ascii=False,indent=2)+';\n')
manifest['status'] = 'generated-exploration-not-approved'
(v4/'prompts.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(v4/'asset-qa.json').write_text(json.dumps(dict(count=24,checks=checks),ensure_ascii=False,indent=2)+'\n')
print('24 opaque square original PNGs; 94 gallery concepts; 24 unique hashes')
