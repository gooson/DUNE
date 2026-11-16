"""Build palette metadata and lazy export sources without changing source PNG bytes."""
from pathlib import Path
import json, base64, hashlib
root=Path(__file__).resolve().parent
specs=[
('lilac-peach','라일락 × 피치','파스텔','#B6A0FF','#F4C6A4','#1E2030','부드러운 보라와 따뜻한 살구'),
('mint-periwinkle','민트 × 페리윙클','파스텔','#7DD9CA','#A9C6FF','#142A35','청량한 민트와 옅은 블루'),
('sage-cream','세이지 × 크림','자연','#7CB7A0','#F1D9A4','#1C302B','차분한 녹색과 따뜻한 크림'),
('coral-sand','코럴 × 샌드','웜톤','#F08F7F','#F1CF9A','#342A2B','코럴과 모래빛의 낮은 대비'),
('ice-denim','아이스 × 데님','쿨톤','#C7E9F7','#7B9EE7','#1C283E','얼음빛과 깊이 있는 블루'),
('moss-jade','모스 × 제이드','자연','#C6D68E','#6CA89B','#202E29','밝은 이끼색과 비취색'),
('rose-plum','로즈 × 플럼','파스텔','#E6A7BD','#AF9AE0','#2D2333','분홍과 보라의 은은한 대비'),
('terracotta-teal','테라코타 × 틸','보색','#D88D6B','#7DB6B3','#292E31','흙빛과 흐린 청록'),
('sand-slate','샌드 × 슬레이트','자연','#E5C391','#718CB4','#1C2431','따뜻한 모래와 회청색'),
('peach-sage','피치 × 세이지','파스텔','#EDB9A1','#A9C6A4','#2B2E29','살구와 연한 잎빛'),
('ultra-coral','울트라마린 × 코럴','보색','#7386F1','#F7A28C','#202239','푸른 보라와 코럴의 대비'),
('lagoon-lemon','라군 × 레몬','보색','#69C6BC','#E4D77D','#183032','청록과 부드러운 레몬빛'),
('violet-mint','바이올렛 × 민트','쿨톤','#B29BDD','#8FD8C4','#24283A','보라와 민트의 차가운 대비'),
('copper-ice','코퍼 × 아이스','보색','#C88E6D','#B4DDE7','#262B32','구릿빛과 얼음빛의 온도 차이'),
('ivory-ink','아이보리 × 잉크','뉴트럴','#EFE5D5','#9FAFD0','#292B31','오프화이트와 잉크 블루'),
('amber-moss','앰버 × 모스','웜톤','#E7B466','#8DBA9D','#2B3028','앰버와 밝은 숲빛'),
('paper-lilac','페이퍼 라일락','밝은 배경','#796CB5','#C37673','#F4F0EB','밝은 종이 위 보라와 로즈'),
('cream-ocean','크림 오션','밝은 배경','#348A94','#CC9565','#F5F0E6','크림 바탕의 해류와 황토빛'),
('white-forest','화이트 포레스트','밝은 배경','#407F6A','#AC7E63','#EEF2EB','옅은 바탕의 숲과 흙빛'),
('pink-blue','핑크 × 블루','선명한 대비','#EC82B5','#7DADEB','#252639','분홍과 블루의 또렷한 대비')]
palettes=[dict(id=s[0],number=i,name=s[1],category=s[2],a=s[3],b=s[4],background=s[5],desc=s[6]) for i,s in enumerate(specs,1)]
data={'version':'palette-lab','created':'2026-11-03','palettes':palettes,'sourceVersion':'v6','sourceAnchors':{'background':'#302b2a','a':'#e1b453','b':'#4fc3d5','highlight':'#ffffff'},'method':'Browser SVG color matrix, same source bitmap and geometry across palettes; target anchors with tonal shading. Runtime UI, not 180 new AI generations.','scope':'9 selected forms ×20 palettes; output is color study, not app asset replacement.'}
(root/'palettes.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(root/'palettes.js').write_text('window.dunePaletteData = '+json.dumps(data,ensure_ascii=False,indent=2)+';\n')
source=json.loads((root.parent/'v6/prompts.json').read_text());export=root/'export-sources';export.mkdir(exist_ok=True)
receipts=[]
for c in source['concepts']:
 p=root.parent/c['image'];raw=p.read_bytes();uri='data:image/png;base64,'+base64.b64encode(raw).decode()
 (export/(c['id']+'.js')).write_text('window.duneLabExportSources=window.duneLabExportSources||{};window.duneLabExportSources['+json.dumps(c['id'])+']='+json.dumps(uri)+';\n')
 receipts.append({'id':c['id'],'image':c['image'],'sha256':hashlib.sha256(raw).hexdigest()})
(root/'source-manifest.json').write_text(json.dumps(receipts,indent=2)+'\n')
print('20 unique palettes; 9 byte-preserving lazy export sources')
