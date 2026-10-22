---
tags: [design, life, hero, themes, actual-capture]
date: 2026-10-22
category: solution
status: reviewed
---

# Life 진행 설명 · 나머지 7개 테마

[실제 화면 14장](index.html) · [캡처 출처](capture-index.json) · [실행 결과](test-results.json)

Life L01의 완료 링·진행 설명·체크리스트 행동을 OCEAN, FOREST, SAKURA, ARCTIC, SOLAR, CONTOUR, WATER LILIES의 밝음·어두움에서 확인했다. 전용 iPhone 18 Pro의 402×874pt 화면을 새로 촬영했다. 앱 소스와 기존 번역은 변경하지 않았다.

## 실행과 판정

- `scripts/test-ui.sh --no-regen --stream-log --simulator-udid F7F01710-33E6-4F20-961C-A9B8C1FECF43 --test-plan DUNEUITests-DuoAudit --only-testing DUNEUITests/LifeSeededSmokeTests/testHeroNarrativeRemainingThemes`를 표준 host 캡처 도구로 실행했다.
- 단일 selector 안에서 7개 테마 × 밝음·어두움으로 앱을 재실행했다. 테스트 **1건 통과·실패 0건·건너뜀 0건**, runner와 host 모두 종료 코드 0이다. 14개 테스트를 실행한 것으로 계산하지 않는다.
- 14개 화면 모두 설명이 비어 있지 않고 히어로 안에 있으며, 기본 글씨에서 링 옆에 배치되고, 전체 링이 화면 안에 있고, 체크리스트 행동이 도달 가능한지 검사했다. 개별 습관 이름은 히어로에 다시 나열하지 않는다.
- 화면을 고정한 host checkpoint에서 1206×2622 PNG를 수집했다. 14장 모두 실제 픽셀과 402×874pt viewport를 확인하고 밝음·어두움의 링·설명·행동을 육안으로 대조했다. 해당 영역에서 잘림·겹침·배경 때문에 읽히지 않는 문구는 발견하지 않았다. 수치 대비 측정이나 고대비 모드 검증은 아니다.

## 디자인맵 동기화

전체 개편 맵 `actual/regular`의 나머지 7테마 L01 14장을 교체했다. 앞서 촬영한 [DESERT HORIZON의 같은 Life 소스 화면](../life-hero-narrative-2026-10-22/README.md)도 해당 iPhone·iPad·Duo 접힘·펼침 인덱스에 연결했다. 이전 캡처의 hash가 현재 `LifeView.swift`와 일치하는지 검사했으며, 이전 화면을 이번 새 실행으로 표시하지 않았다. 화면별 UDID·기기·시각·selector·출처를 보존한다.

DESERT HORIZON의 iPhone 402pt·440pt, iPad, Duo 접힘·펼침과 최대 접근성 글씨는 앞선 5건의 집중 검증을 참조한다. 이번 결과는 나머지 7테마의 iPhone 기본 글씨에 한정한다. 해당 테마의 iPad·Duo·최대 글씨, 다른 탭, 상세·시트·운동, Watch·Widget·Vision 전체 검증으로 확대하지 않는다.
