---
tags: [app-icon, apple-hig, dribbble, branding, stroke-weight]
date: 2026-11-03
category: brainstorm
status: draft
---

# 3차 아이콘 탐색 · Apple과 Dribbble

## 사용자 교정

‘꽉 찬 느낌’을 색면 채우기만으로 해석한 2차 방향을 보완한다. 선을 더 굵게 하거나 테마 키컬러를 사용하며 다양한 관점의 50개를 요청했다. 새로운 50개는 단순 재색칠이 아니라 선 굵기, 끝 처리, 위상과 간격, 곡률, 크기와 방향, 연결과 여백, 레이어의 관계를 각각 탐색한다. 번호는 이전 이력을 보존해21–70이다.

## Apple 근거와 적용

2026-11-03 [Apple HIG · App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)와 공식 Markdown 본문을 확인했다. 아래는 DUNE에 대한 적용 판단이며 Apple이 DUNE 시안을 검토·승인했다는 뜻이 아니다.

- 한눈에 남는 하나의 중심 개념: 사구·생체 리듬이라는 곡선의 정체성을 유지한다.
- 간결함과 명확한 가장자리: 작은 장식 대신 굵은 곡선과 충분한 간격으로 무게를 만든다.
- 플랫폼 간 일관성: 동일 심볼이 정사각형·원형 영역에서도 살아남을 여유를 둔다.
- 레이어 실험은 선명한 앞면과 관계를 우선한다. 생성한 입체·반투명 표현은 재질 제안이며 시스템 Liquid Glass의 실제 렌더링·검증이 아니다.
- 원본 PNG에 앱 모서리를 굽지 않는다. 비교판·홈 화면에서만 CSS 마스크를 근사한다. 실제 제작은 후보 선택 후 foreground/background 분리와 Icon Composer 검증을 거친다.

## Dribbble 레퍼런스

개별 작품의 구조·설명만 참고하며 심볼을 복제하지 않는다. 출처·디자이너·수집일·이미지 확인 여부를 `../references/dribbble/sources.json`에 보존했다. Dribbble 웹 원문의 이미지가 직접 제공되지 않은 항목은 원문 설명을 참고했다고 표시한다.

| 작품 | 참고 관점 | 확인 수준 |
|---|---|---|
| [wave monoline logo · Muh Iqbal Kholili](https://dribbble.com/shots/15732362-wave-monoline-logo) | 유기 곡선의 등굵기와 간격. DUNE에서는 거품·태양·상세선을 사용하지 않는다. | 원본 이미지 확인·보존 |
| [DROP WAVE · Make Patel](https://dribbble.com/shots/26384596-DROP-WAVE-Minimal-Line-Art-Logo-with-Bold-Box-Subtle-Wave) | 굵기 대비와 파동을 조합하는 방향 | 원문 설명 |
| [Mirano · George MadeToBeTapped](https://dribbble.com/shots/27768564-Mirano-Liquid-Glass-App-Icon) | 겹친 레이어와 홈 화면 문맥에서의 인지성 | 원문 설명 |
| [Liquid glass / Minimal · ktnr.23](https://dribbble.com/shots/27477796-App-icon-design-Liquid-glass-Minimal) | 절제된 재질 탐색과 앱 아이콘의 완성도 | 원문 설명 |
| [Flow · Dil Nawaz / The Lion Studios](https://dribbble.com/shots/27577823-Flow-Minimal-Wellness-Symbol-Circle-Wave-Logo) | 적은 기하 요소로 움직임과 균형을 암시 | 원문 설명 |

Dribbble은 창작 방향을 넓히는 참고 자료다. 플랫폼 규격과 동적 효과 판단은 Apple 공식 근거를 따른다. 시각 해석을 사용자 인지성 실험 결과나 객관적인 ‘최고’ 평가로 표현하지 않는다.

## 50개 구성

| 번호 | 관점 | 핵심 변화 |
|---|---|---|
|21–30|A 굵은 선|같은 DUNE 골드로 선 굵기·끝·길이·간격을 비교|
|31–40|B 비율과 실루엣|세로 비중·기울기·중심 골짜기·D·열린 렌즈|
|41–50|C 테마 키컬러|8개 테마와 아이보리·단색의 굵은 곡선|
|51–60|D 연결과 여백|연속 경로·열린 궤도·교차·끊김·연결된 층|
|61–70|E 레이어와 재질|평면 겹침·매트·리본·얕은 두께·반투명 제안|

기본 팔레트는 `../../../../manifest.json`의 8개 테마에서 가져왔다. 아이보리·단색은 아이콘 탐색용 대안이며 앱 신규 테마가 아니다. 50개 전체 프롬프트와 번호·이름·배경·키컬러는 `prompts.json`을 따른다.
