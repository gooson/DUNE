#!/usr/bin/env python3
"""Append actual native evidence to this staging directory only; no native/Git execution.
Native: --bundle PATH --key ipad-normal --tier ipad --names-start screen- --filenames ID.png --pair ID.png
Host: --bundle PATH --key duo --tier duo --host --sequences 2 3 --pair 002-1398x2034.png --host-size 1398x2034
Always manually inspect state identity and raw pose/checkpoints before invoking.
"""
import argparse, datetime, hashlib, html, json, re, shutil
from pathlib import Path
from PIL import Image
parser=argparse.ArgumentParser()
parser.add_argument('--bundle',type=Path,required=True);parser.add_argument('--key',required=True)
parser.add_argument('--tier',choices=['regular','ipad','duo','duo-open'],required=True)
parser.add_argument('--names-start');parser.add_argument('--filenames',nargs='*');parser.add_argument('--pair')
parser.add_argument('--host',action='store_true');parser.add_argument('--sequences',nargs='*',type=int);parser.add_argument('--host-size')
a=parser.parse_args();stage=Path(__file__).resolve().parent
assert stage.name=='staged-gallery' and 'pr885' in stage.parts, 'Staging only'
d=json.loads((stage/'evidence.json').read_text());assert not d['installed'];assert a.key not in d['bundles'],'Already imported; review before updating'
src=a.bundle.resolve();result=json.loads((src/'result.json').read_text());prov=json.loads((src/'provenance.json').read_text())
assert result['status']=='passed' and result['run_exit_status']==0 and result['counts']['failed']==0 and result['counts']['passed']>0
assert not result.get('required_selectors_missing') and not result.get('skipped_selectors')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
proof=stage/'assets/proofs'/a.key;proof.mkdir(parents=True,exist_ok=True)
def copyproof(p):
 if p.exists():
  target=proof/p.name;shutil.copy2(p,target);d['proof_sha256'][str(target.relative_to(stage))]=sha(target)
for n in ['result.json','provenance.json','summary.json','tests.json']:copyproof(src/n)
items=[]
if a.host:
 host=src/'paired-host';pose=json.loads((host/'pose-proof.json').read_text());cks=[json.loads(x) for x in(host/'checkpoints.jsonl').read_text().splitlines()]
 assert a.sequences and a.host_size and a.pair
 assert all(x['acknowledged'] and x['valid_evidence'] and not x['error'] for x in cks)
 expected=(0,'LCD') if a.tier=='duo' else (180,'LCD-1');assert pose['angle_before']==pose['angle_after']==expected[0] and pose['active_display']==expected[1]
 for n in ['pose-proof.json','runner-result.json','checkpoints.jsonl','captures.tsv','angle-before.txt','angle-after.txt','displays-before.json','displays-after.json']:copyproof(host/n)
 for n in a.sequences:
  p=host/f'{n:03}-{a.host_size}.png';copyproof(host/f'{n:03}-hierarchy.txt')
  items.append((p,dict(capture_timestamp=p.stat().st_mtime,timestamp_kind='host-file-mtime of native paired PNG; not attachment time or checkpoint deadline',selector=result['requested_selectors'][0],action=cks[n-1]['action'],sequence=n,angle_before=expected[0],angle_after=expected[0],active_display=expected[1],pose_readback_verified=True,strict_ack_count=len(cks),device_udid=prov.get('device_udid'))))
else:
 manifest=json.loads((src/'attachments/manifest.json').read_text());copyproof(src/'attachments/manifest.json')
 for group in manifest:
  for m in group['attachments']:
   name=m['exportedFileName']
   if not name.endswith('.png'):continue
   if a.filenames and name not in a.filenames:continue
   if a.names_start and not m['suggestedHumanReadableName'].startswith(a.names_start):continue
   assert not m['isAssociatedWithFailure']
   items.append((src/'attachments'/name,dict(capture_timestamp=m['timestamp'],timestamp_kind='native-XCTest-attachment',selector='DUNEUITests/'+group['testIdentifier'].removesuffix('()'),action=m['suggestedHumanReadableName'],native_attachment=m,device_udid=m['deviceId'])))
assert items,'No chosen images'
records=[]
for p,meta in items:
 target=stage/'assets'/f'{a.key}-{p.name}';shutil.copy2(p,target);im=Image.open(p);x=dict(meta);x.update(image=str(target.relative_to(stage)),source_file=str(p),sha256=sha(p),pixels=list(im.size),exif_orientation=im.getexif().get(274,1),revision=prov.get('revision',prov.get('executed_revision')),source_worktree_dirty=prov.get('source_worktree_dirty'),label=a.key+' · '+meta['action'].split('_0_')[0],kind='actual-native-supplement',caveat='Exact executed revision preserved. Review action/viewport state; no wholeHEAD or fullsuite claim.')
 x['capture_time_kst']=datetime.datetime.fromtimestamp(x['capture_timestamp'],datetime.timezone(datetime.timedelta(hours=9))).isoformat();records.append(x)
pair=None
if a.pair:
 pair=next(x for x in records if Path(x['source_file']).name==a.pair);assert d['pairs'][a.tier]['after'] is None,'Preserve existing historical preferred pair'
 d['pairs'][a.tier]['after']=pair;d['pairs'][a.tier]['status']='actual native after available in stated scope'
d['extra_states'] += [x for x in records if x is not pair]
d['bundles'][a.key]=dict(source_directory=str(src),result=result,provenance=prov,included_files=[Path(x['source_file']).name for x in records])
def fig(x):
 label=html.escape(x['label']);return f'<figure><figcaption>{label}</figcaption><a href="{x["image"]}"><img loading="lazy" src="{x["image"]}" alt="{label}"></a><small>{x["revision"]} · {x["capture_time_kst"]}<br>{x["pixels"][0]}×{x["pixels"][1]} · SHA256 {x["sha256"]}<br>{html.escape(x["timestamp_kind"])}</small></figure>'
s=(stage/'index.html').read_text()
if pair:
 match=re.search(r'<section id="'+a.tier+r'">.*?</section>',s);assert match
 z=match[0].replace('<div class="pending">개편 실제 촬영 자료 연결 대기<br>완료된 캡처가 아닙니다.</div>',fig(pair));s=s[:match.start()]+z+s[match.end():]
extra='<section id="'+html.escape(a.key)+'"><h2>'+html.escape(a.key)+' · 추가 실제 상태</h2><div class="extras">'+''.join(fig(x) for x in records if x is not pair)+'</div></section>'
s=s.replace('<section id="sources">',extra+'<section id="sources">')
(stage/'index.html').write_text(s);(stage/'evidence.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
# Current assembly statuses/README must be reviewed explicitly by parent after each import.
ids=re.findall(r'\bid="([^"]+)"',s);links=re.findall(r'(?:href|src)="([^"]+)"',s);missing=sorted(set(x for x in links if not x.startswith(('#','http')) and not(stage/x).exists()));assert not missing and len(ids)==len(set(ids))
assert all(sha(stage/x['image'])==x['sha256'] for x in records);assert all(sha(stage/p)==h for p,h in d['proof_sha256'].items())
c=json.loads((stage/'static-checks.json').read_text());c.update(png_count=len(list((stage/'assets').glob('*.png'))),png_sha256={str(p.relative_to(stage)):sha(p) for p in(stage/'assets').glob('*.png')},all_metadata_hashes_verified=True,all_proof_hashes_verified=True,missing_local_links=missing,duplicate_ids=False);(stage/'static-checks.json').write_text(json.dumps(c,indent=2)+'\n')
print('Imported',len(records),'actual PNGs; staging only. Review statuses and captions before publication.')
