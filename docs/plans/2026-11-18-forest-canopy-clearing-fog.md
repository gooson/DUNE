---
tags: [forest, theme, animation]
date: 2026-11-18
category: plan
status: implemented
---
# FOREST · 목판 소나무와 걷히는 안개

승인된 [Forest Canopy 시안](../design/theme-map/themes/forest-green-direction.html)을 앱의 T03·A01·H01·L01에 적용한다. 테마 선택 샘플은 같은 Today 장식의 정지 화면을 쓴다. 알림과 운동 목록은 기존 숲 실루엣을 유지하고, 상세·시트와 Watch 화면은 이 네 탭의 장식을 소비하지 않는다.

## 영향 파일

| 경로 | 역할 |
|---|---|
| `DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | 숲 원화, 24초 안개와 재생 정책 |
| `DUNE/Presentation/Shared/Components/ForestHeroArtwork.swift` | 카드의 장식 영역과 좁은 폭·큰 글씨 배치 |
| `DUNE/Presentation/Activity/ActivityView.swift`, `WellnessHeroCard.swift`, `LifeHabitHeroView.swift` | 탭별 실제 점수·링·행동과 원화 연결 |
| `DUNE/Resources/Assets.xcassets` | 원화·솔잎 마스크·안개 에셋 |
| `DUNETests/ForestSilhouetteShapeTests.swift` | 모션·재생·에셋 회귀 검사 |
| `docs/design/theme-map`, `docs/design/phone-design-map` | 브라우저 시안과 새 네이티브 캡처 |

## 구현 순서

1. 시안에 쓰인 소나무와 안개 원본으로 앱 에셋을 만들고, 두 묶음의 솔잎 마스크를 원화 좌표에 고정한다.
2. ForestWaveBackground와 세 히어로 카드에 하나의 숲 장식을 연결한다. Today는 상단 전경, 나머지 세 탭은 수관·능선·줄기 순서로 잘라 보여준다. 네이티브 카드의 점수, 데이터, 버튼과 큰 글씨의 읽기 공간을 보존한다.
3. 24초 동안 앞안개와 골안개의 위치·농도를 달리해 소나무부터 드러나게 하고 다시 채운다. 기존 장식 재생 정책을 사용하고 동작 줄이기에서는 중간 농도를 고정한다.
4. 전용 시뮬레이터에서 Forest 테마 행렬 selector와 핵심 모션 검사를 수행한다. 밝음·어두움과 iPhone·iPad·Duo 두 자세의 새 캡처를 실제 디자인맵에 연결한다. 원화나 브라우저 캡처를 기기 증거로 사용하지 않는다.

검증 위험은 글자와 장식 겹침, 넓은 화면의 잘림, 탭 재진입 뒤 정지, 불필요한 반복 렌더링이다. 기존 Ocean 배치 계약과 Forest Today 애니메이션 재진입 기록을 참고한다. 기기 실행은 한 번에 하나로 제한하고 이미 통과한 브라우저 시안 검증은 재사용한다.
