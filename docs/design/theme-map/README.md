---
tags: [design, theme, visual-direction, animation, archive]
date: 2026-10-17
category: plan
status: in-progress
---

# DUNE 테마 맵

[테마 맵 열기](index.html) · [8개 테마 전체 구현 맵](../full-redesign-map/index.html) · [7개 테마 앱 적용 맵](app-contract.md) · [UX·비주얼 명세](../2026-10-17-ux-visual-spec.md) · [실제 화면 디자인맵 열기](../phone-design-map/actual/index.html)

[4탭 레이아웃 기준맵](../layout-map/index.html)은 배치와 정보 순서의 별도 기준이다. 이 테마 맵은 색·장면·링·움직임을 정의한다.

2026-10-17까지 논의한 **8개 테마 방향 시안**과 공통 능선 표현 연구안을 저장소에 보존한다. 이 자료는 움직이는 디자인 제안이며 앱의 현재 구현이나 실제 시뮬레이터 캡처가 아니다. 시안의 컨디션 수치와 문구는 예시다.

2026-10-19 [전체 디자인 개편 맵](../full-redesign-map/index.html)은 이 8개 시안을 앱의 4탭과 전체 화면군에 구현하기 위한 새 목표다. 기존 `app-contract.md`는 7개 구현 테마의 당시 적용 기록이며, WATER LILIES는 새 맵에서 구현 대상으로 확장했다. 시안 자체가 구현 완료를 뜻하지 않는다.

| 테마 | 시안 | 핵심 표현 |
|---|---|---|
| DUNE | [Desert Horizon](themes/dune-design-direction.html) | 끊임없이 흐르는 모래 능선과 금빛 링 |
| OCEAN | [Ocean Current](themes/ocean-cool-direction.html) | 두꺼운 밝은 포말과 교차하는 해류 |
| FOREST | [Forest Canopy](themes/forest-green-direction.html) | 안개와 깊은 숲 능선, 금빛 링 |
| SAKURA | [Spring Haze](themes/sakura-calm-direction.html) | 벚꽃 군집과 얇은 가지, 적은 꽃잎 |
| ARCTIC | [Aurora Drift](themes/arctic-dawn-direction.html) | 고요한 배경 위로 이동하는 오로라 |
| SOLAR | [Solar Pulse](themes/solar-pop-direction.html) | 고정된 태양 코어 주변의 빛 궤적 |
| CONTOUR | [Contour Field](themes/contour-atlas-direction.html) | 석회색 지형과 호흡하는 등고선 |
| WATER LILIES | [Lily Reverie](themes/water-lilies-direction.html) | 푸른 수면, 겹친 초록 붓질, 작은 보랏빛 꽃점 |

[공통 능선 표현 연구안](themes/theme-crest-language.html)은 초기 시각 언어 탐색으로 별도 보존한다. 수련 시안은 현재 방향으로 두고 세부 표현은 추후 개선하기로 했다.

## 갱신 방법

테마의 색, 능선·배경, 링, 그래프, 움직임, 화면별 표현을 바꿀 때 **같은 작업에서** 아래를 갱신한다.

1. `themes/`의 해당 HTML을 수정하거나 새 시안을 복사한다. 이 저장소 안의 파일을 보존본으로 취급한다. 대화용 시안 파일을 따로 수정했다면 최신 내용을 다시 복사한다.
2. `manifest.json`에서 설명·색상·수정일을 갱신한다. 새 테마라면 항목을 추가한다.
3. `python3 docs/design/theme-map/build-theme-map.py`를 실행해 `index.html`을 재생성한다.
4. `python3 docs/design/theme-map/build-theme-map.py --check`로 동기화를 확인하고, 맵에서 해당 시안과 비교 화면의 링크·움직임을 확인한다.
5. 테마 목록이나 방향이 바뀌면 이 README의 표와 결정 상태도 갱신한다.

앱 화면에 테마를 **구현하거나 변경**했다면 별도로 [실제 화면 디자인맵 갱신 절차](../phone-design-map/README.md#화면-수정-시-갱신)를 수행한다. 방향 시안은 실제 앱 화면의 증거로 사용하지 않는다.

`index.html`이 실제로 여는 맵이다. `template.html.in`은 생성용 원본이고, 옛 `template.html` 주소는 `index.html`로 이동한다. 생성된 맵은 스크립트가 실행되지 않아도 테마 목록과 첫 시안, 각 원본 링크를 표시한다.
