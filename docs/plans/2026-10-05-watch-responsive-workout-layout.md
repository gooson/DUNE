---
topic: watch-responsive-workout-layout
date: 2026-10-05
status: approved
confidence: medium
related_solutions:
  - general/2026-03-02-watchos-button-overflow-fix.md
  - testing/2026-09-27-life-menu-watch-offscreen-ui-tests.md
---

# Implementation Plan: 워치 운동 화면 크기 대응

## Context
천국의 계단 시작 화면의 아이콘, 이름, 레벨 선택, 시작 버튼 누적 높이가 작은 워치의 가용 영역을 초과한다. 기존 ScrollView는 접근성은 제공하지만 최초 화면의 시작 버튼 노출을 보장하지 않는다.

## Requirements
- 시작 액션은 기본 글자 크기에서 작은 워치에서도 온전히 노출한다.
- 화면 가용 크기에 비례해 장식과 간격을 조정하고 터치 영역과 Dynamic Type을 유지한다.
- 같은 고정 세로 스택 패턴인 운동 제어/휴식 화면을 조사하고 필요한 범위만 수정한다.
- 운동 시작, 레벨, 저장 로직은 유지한다.

## Approach
GeometryReader의 safe-area 내부 제안 크기와 유연한 레이아웃을 사용한다. 콘텐츠가 커지면 ScrollView로 접근 가능하게 하고 주요 액션은 별도로 확보한다. 전체 화면 scaleEffect나 기기명별 크기 하드코딩은 터치/글자 크기를 훼손하므로 사용하지 않는다.

## Affected Files
| File | Change |
|------|--------|
| DUNEWatch/Views/WorkoutPreviewView.swift | 시작 액션/레벨/헤더 적응형 배치 |
| DUNEWatch/Views/ControlsView.swift | 다중 제어 액션의 작은 화면 대응 |
| DUNEWatch/Views/RestTimerView.swift | 고정 링과 액션의 높이/폭 대응 |
| DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift | 천국의 계단과 유사 cardio 시작 화면 bounds 검증 |
| DUNEWatch/WatchConnectivityManager.swift | 필요 시 deterministic cardio fixture |

## Implementation Steps
1. 기존 watch UI/해결책을 조사하고 시작 화면을 수정한다. 버튼 전체 frame 및 hittability 확인.
2. 동일한 overflow 패턴의 제어/휴식 화면을 가용 영역 기반으로 수정한다. 순수 레이아웃만 변경.
3. 실제 화면 진입 테스트에 bounds assertion과 스크린샷을 추가한다.
4. 빌드, watch 전체 suite, 크기별 관련 suite 후 다관점 리뷰·문서화·Ship.

## Testing Strategy
- scripts/build-ios.sh 및 watch UI runner의 watch 빌드.
- scripts/plan-ui-tests.py --base origin/main 결과와 소비자 확인으로 watch full, iOS UI skip 판단.
- 40mm/42mm/44mm/49mm 중 최소·최대 및 중간 크기의 preview 회귀, 대표 크기의 watch full suite.
- 존재 확인뿐 아니라 frame 전체가 화면 안인지, hittable인지 확인하고 화면 캡처 검토.
- 레이아웃 전용 수정이므로 계산 로직을 복제하는 단위 테스트는 추가하지 않는다.

## Edge Cases / Risks
- 긴 운동명·큰 글자: 여러 줄 및 스크롤 fallback, 버튼 축소 금지.
- 실내/실외 2개 액션: 가로폭 부족 시 세로/스크롤 접근 보장.
- 레벨 조절 Crown focus와 ScrollView 충돌: 기존 동작 유지 및 터치 접근 확인.
- CoreSimulator sandbox 차단은 권한 확장 후 목록 조회 성공으로 해소. 같은 실패는 원인 변화 없이 반복하지 않는다.
- 로컬 main이 뒤쳐져 있으므로 실제 PR base origin/main(ea876722) 사용. 이전 PR 변경을 이번 범위에 포함하지 않는다.

## Research
- docs/brainstorms의 stair-climber/level 모델과 todos 검색: 이번 레이아웃 수정과 동일한 진행 항목 없음.
- Apple 공식 Supporting multiple watch sizes 및 ViewThatFits 문서 확인: safe area와 가용 공간 기반 배치.

## Execution
- Phase 0 완료: clean detached HEAD, 기준 simulator 목록 /tmp/watch-layout-baseline-devices.json.
- Phase 1 완료: 계획서 및 초기 UI 범위 /tmp/watch-layout-ui-plan-initial.json.
