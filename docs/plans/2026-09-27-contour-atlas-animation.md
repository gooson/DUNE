---
tags: [swiftui, contour, animation, accessibility]
topic: contour-atlas-animation
date: 2026-09-27
category: plan
status: approved
confidence: high
related_solutions: [2026-09-20-contour-atlas-theme]
related_brainstorms: []
---

# Implementation Plan: Contour Atlas 애니메이션

## Context

사용자는 정적 Contour Atlas 테마에 움직임을 요청했다. 선행 작업의 미커밋 구현을 검증·보완하고 `/run` 전체 게이트를 거쳐 배포한다. 기존 2026-09-20 계획은 테마 최초 도입으로 범위가 달라 이번 후속 계획을 별도로 남긴다.

## Requirements

- Tab/Detail/Sheet의 등고선에 느린 이동·회전·확대/축소를 적용한다.
- Tab 보조 레이어는 다른 주기로 움직인다.
- Reduce Motion, 정적 미리보기, 비활성 scene, Watch는 정적으로 표시한다.
- 등고선 좌표 캐시, 불투명 배경, 장식 요소의 hit testing/접근성 제외를 유지한다.

## Approach

SwiftUI `phaseAnimator`로 캐시된 Shape의 transform만 움직인다. 8초/11초는 각 방향 전환 시간이며 왕복 주기는 각각 16초/22초다. Scene 상태 전환은 0.4초 opacity 전환을 사용하고 Reduce Motion에서는 생략한다.

공식 API 근거: [Apple PhaseAnimator](https://developer.apple.com/documentation/swiftui/phaseanimator). 별도 timer와 frame별 geometry 재계산 없이 반복 phase를 구성한다. 코드 검색은 rg/파일 읽기를 사용했다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| PhaseAnimator + transform | 기존 geometry 캐시 유지, 적은 상태 | 비활성 시 진행 phase 초기화 | 채택, opacity 전환으로 연결 |
| TimelineView + 매 프레임 path 변형 | 지형 자체 변화 가능 | 계산량과 상태 관리 증가 | 미채택 |
| repeatForever + State | 기존 wave와 유사 | lifecycle 시작/정지 관리 필요 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Shared/Components/ContourBackground.swift | 수정 | transform 기반 모션 및 접근성/lifecycle 정책 |
| DUNEUITests/Visual/ContourThemeTests.swift | 검토/보완 | 테마 화면, 재활성화 흐름 회귀 |
| docs/solutions/design/2026-09-20-contour-atlas-theme.md | 수정 | 기존 정적 계약 설명 동기화 |
| docs/solutions/general/2026-09-27-contour-atlas-animation.md | 추가 | 최종 구현·검증·제약 기록 |

## Implementation Steps

1. 선행 변경 diff와 호출부를 확인하고 작업 브랜치에 구현을 보존한다.
2. ui-test-expert로 기존 테스트를 검토하고 변경된 lifecycle 흐름에 필요한 검증을 보완한다.
3. 표준 스크립트로 iOS 빌드, 관련 UI 검증 및 DUNEUITests 전체 회귀를 실행한다.
4. 5관점 리뷰 및 SwiftUI/Apple UX 품질 검증을 수행하고 발견사항을 해결한다.
5. 해결책 문서를 생성하고 PR 생성·merge 후 브랜치를 정리한다.

## Edge Cases

| Case | Handling |
|------|----------|
| Reduce Motion 변경 | static branch 전환, scene transition animation 비활성 |
| 테마 미리보기 | 기존 waveReducedMotion 환경 정책 재사용 |
| background/foreground | static branch와 identity 시작 transform 사이 crossfade |
| Watch 공유 컴파일 | watchOS 전용 accessibility 환경키, watch style 정적 |
| iPad/회전 | GeometryReader 크기와 정규화 geometry 유지 |

## Testing Strategy

- 빌드: scripts/build-ios.sh (iOS + embedded Watch 컴파일).
- UI: ui-test-expert가 기존 seeded 테스트와 lifecycle 검증을 보완; scripts/test-ui.sh의 full suite 실행.
- 유닛: 데이터/수학 로직 변경이 없어 새 유닛 테스트는 불필요. SwiftUI body는 UI 검증 대상으로 분류.
- 시각 확인: 시뮬레이터에서 시간 간격 캡처로 움직임 확인, 라이트/다크 화면과 설정 미리보기 확인.
- 실기기 FPS/전력 측정은 이번 자동 검증 범위 밖이며 결과에서 제한을 명시한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| lifecycle 복귀 위치 튐 | 중간 | 시각 품질 | identity 시작 위치 + opacity 전환 |
| 반복 모션으로 테스트 idle 대기 | 낮음 | 테스트 지연 | 기존 theme UI 회귀 실제 실행 |
| unrelated full-suite 실패 | 중간 | ship 차단 | 로그 분석, 최대 2회 재현; 게이트 우회 금지 |
| 미리보기·Watch 불필요한 모션 | 낮음 | 전력/접근성 | 기존 환경키 및 style gating 유지 |

## Confidence Assessment

High: 단일 공유 View에 제한된 변경이며 앞선 빌드와 테마 UI 2개는 통과했다. 이번 실행에서 전체 UI 게이트와 다관점 리뷰를 추가한다.

## Execution Evidence (2026-09-27)

- 브랜치: `codex/contour-atlas-animation`.
- 구현: `8f478952`, lifecycle UI 테스트: `91d401b0`; origin에 push 완료.
- `scripts/build-ios.sh`: 통과. UI 타깃 pre-commit `build-for-testing`: 통과.
- Work의 `swift-ui-expert`, `apple-ux-expert`: 코드 수준 actionable P1/P2/P3 없음. 정식 Phase 3 리뷰와 별개다.
- 시각 검증: 독립 iPhone 18 Pro / iOS 27.0의 Today 라이트 화면 두 시점 캡처에서 등고선 위치 변화와 카드 위치 유지를 확인했다. 실기기 FPS/전력, 동작 줄이기 설정의 실제 전환은 미검증이다.
- 전체 UI 회귀: 첫 `ActivityExercisePickerRegressionTests/testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm`이 `activity-recent-seeall` 탭 뒤 app idle 대기에서 180초 제한을 초과했다. 정상 종료되지 않은 실행기를 정리했다.
- 관련 과거 기록: `docs/solutions/testing/2026-03-29-ui-test-force-kill-cascade-prevention.md`. 이 테스트는 컨투어 테마를 지정하지 않는다. 이번 결과만으로 컨투어 회귀로 판정하지 않는다.
- 복구 1: 시뮬레이터 재부팅 후 실패 케이스와 ContourThemeTests를 한정 실행했으나 테스트 런너 시작 전 멈춰 종료했다.
- 복구 2: 새 빈 시뮬레이터에서 동일 검증을 실행했으나 부팅·빌드 후 테스트 시작 전 대기가 반복되어 종료했다.
- 로그(로컬): `/tmp/contour-run-build.log`, `/tmp/contour-run-ui-full.log`, `/tmp/contour-run-ui-retry.log`, `/tmp/contour-run-ui-clean.log`.
- 게이트 상태: Phase 0/1 completed, Phase 2/2.5 failed(UI gate), Phase 3 이후 skipped(선행 UI 게이트 실패). 새 lifecycle 테스트는 컴파일됐지만 실행 통과 증거가 없다. PR 생성·merge는 수행하지 않았다.
- TODO 검색: 해당 애니메이션 작업에 대응하는 활성 TODO 없음. 기존 TODO의 상태를 임의 변경하지 않는다.
- 재개 조건: 시뮬레이터 런너/기존 운동 선택 회귀를 복구하고 full DUNEUITests를 통과시킨 뒤 Phase 3부터 진행한다. 관련 테스트만 통과한 결과로 full gate를 대체하지 않는다.

## Ship 재개 (2026-09-27)

- 위 기록은 최초 중단 시점의 상태다. 이후 시뮬레이터 경합을 수정했고 picker 회귀는 180초 제한 그대로 71.770초에 통과했다.
- 최신 `origin/main` 병합 및 문서 충돌 정리: `5d484e5f`. 병합 시 표준 `scripts/build-ios.sh` 빌드 성공.
- Work 품질 검토: SwiftUI, Apple UX, UI-test 전문가 모두 actionable findings 없음. 화면 캡처·조작 검증과 모션의 프레임 성능 검증을 구분한다.
- 실행기 잠금 5개 + 워크트리 식별 4개 회귀 테스트 재검증 통과.
- 로컬 동시 테스트 경합을 피하려 기존 전체 CI 워크플로를 브랜치 HEAD로 실행했다: https://github.com/gooson/DUNE/actions/runs/36263017318 . 자동 비활성화 상태였던 워크플로는 실행 요청 직후 다시 비활성화했다.
- 전체 CI 결과를 기다리는 동안 정적 리뷰를 병행한다. UI 통과 여부와 최종 ship 결과는 완료 시 추가 기록한다.

## 사용자 지정 게이트

사용자 후속 지시: “전체 ui test 결과 기다리지말고 스모크 통과 했으면 지나가”. 전체 UI CI 대기를 중단하고 현재 브랜치의 iOS 스모크 통과를 ship 기준으로 변경한다. 정식 5관점 리뷰와 품질/PR 검토는 모두 완료됐으며 P1/P2/P3는 0건이다.
