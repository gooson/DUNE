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
