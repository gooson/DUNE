---
tags: [theme, arctic-dawn, performance, swiftui, iphone, max-performance]
date: 2026-03-07
category: brainstorm
status: reviewed
---

# Brainstorm: Arctic Theme 최대 성능 개선

## Problem Statement

Arctic Dawn 테마는 이미 `TimelineView`, `drawingGroup`, LOD, normalized sample cache 같은 1차/2차 최적화를 적용한 상태다.
그럼에도 iPhone에서 Arctic 화면을 오갈 때 `탭 전환`, `push/pop`, `sheet 진입`, `리스트 스크롤` 구간의 체감 끊김이 남아 있다.

이번 목표는 **수치 최적화보다 체감 성능**을 우선하고,
Arctic의 시각 아이덴티티는 유지하되 **최대 5% 이내의 디테일 감소**를 허용해서
전체 Arctic surface의 반응성과 부드러움을 최대한 끌어올리는 것이다.

## Target Users

- iPhone에서 Arctic Dawn을 메인 테마로 사용하는 사용자
- 탭 왕복, 긴 리스트 스크롤, 상세 화면 진입/이탈이 잦은 사용자
- fps 수치보다 "버벅임이 없는가"를 더 민감하게 느끼는 사용자

## Success Criteria

- Arctic 탭 진입/복귀 시 첫 프레임 hitch가 거의 느껴지지 않는다
- Arctic 배경 위 리스트 스크롤에서 손가락 추적성이 유지된다
- Detail/Sheet 진입과 해제 중 배경 애니메이션이 입력 반응성을 해치지 않는다
- 시각 회귀는 허용 범위(약 5% 이내) 안에 머문다
- 구현 후 수동 검증 경로와 회귀 테스트 포인트가 정의된다

## Current Baseline

현재 코드 기준으로 이미 반영된 항목:

- `TimelineView(.animation(minimumInterval: 1.0 / 60.0, ...))` 적용
- `ArcticAuroraCurtainOverlayView`, `ArcticAuroraMicroDetailOverlayView`,
  `ArcticAuroraEdgeTextureOverlayView`에 `drawingGroup()` 적용
- 저전력/Reduce Motion 기반 `ArcticAuroraLOD` 적용
- `ArcticNormalizedSamples` 캐시로 shape sample 재사용

남은 병목 후보:

- `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView`가 여전히 많은 `Capsule`/`Circle`을 SwiftUI view tree로 매 frame 생성
- 두 오버레이가 `GeometryReader`에 의존해 layout + render 부담이 남아 있음
- Tab/Detail/Sheet가 모두 동일한 60fps cadence로 보조 디테일까지 갱신
- 정적에 가까운 glow/gradient 레이어도 `TimelineView` body 안에서 함께 재계산됨

## Proposed Approach

### 1) Micro/Edge 레이어를 `Canvas` 기반 단일 패스로 전환

가장 큰 후보는 `ArcticAuroraMicroDetailOverlayView`와
`ArcticAuroraEdgeTextureOverlayView`를 SwiftUI primitive 묶음에서 `Canvas`로 바꾸는 것이다.

- `Capsule`/`Circle` 수십~수백 개의 view identity churn 제거
- `GeometryReader` 제거 가능 (`context.size` 사용)
- 마이크로 디테일/스파클/엣지 텍스처를 한 렌더 패스로 합성 가능

예상 효과:

- 체감 성능 개선폭이 가장 클 가능성이 높음
- 특히 스크롤과 탭 전환 중 secondary layer 비용을 크게 낮출 수 있음

리스크:

- blur/blend 결과가 기존 SwiftUI primitive와 완전히 같지 않을 수 있음
- snapshot/manual visual tuning이 필요함

### 2) 레이어 중요도별 cadence 분리

현재는 핵심 레이어와 보조 레이어가 모두 60fps로 움직인다.
체감 성능 우선이라면 **리본/커튼은 60fps 유지**, `micro detail`과 `edge texture`만 30fps 또는 phase quantization으로 낮추는 전략이 유효하다.

- 메인 모션(aurora curtain, ribbon)은 부드럽게 유지
- 미세 shimmer만 프레임 빈도를 줄여도 체감 손실은 제한적

예상 효과:

- 5% 이내의 시각 손실로 높은 성능 이득 가능
- 구현 난이도 대비 효과가 큼

리스크:

- quantization 폭이 과하면 shimmer가 끊겨 보일 수 있음

### 3) Normal 모드에서도 iPhone 전용 LOD 추가 감축

지금은 conserve 경로가 중심이다.
하지만 이번 목표는 최대 성능이므로 normal 모드에도 iPhone 전용 미세 감축을 넣는 편이 맞다.

권장 방향:

- Tab: micro/edge 반복 수를 약 `0.85x ~ 0.9x`
- Detail: 약 `0.65x ~ 0.75x`
- Sheet: 약 `0.5x ~ 0.6x`
- curtain/ribbon은 최대한 유지하고 micro sparkle/crest/strand부터 먼저 줄이기

예상 효과:

- 테마 인상은 유지하면서 연산량을 안정적으로 감축
- visual budget 5% 안에서 가장 관리하기 쉬운 옵션

리스크:

- 감축 기준이 과하면 "Arctic의 풍성함"이 빠졌다고 느껴질 수 있음

### 4) 화면 가시성 기준 playback 제어 강화

지금은 scene active 여부 중심으로 playback을 멈춘다.
체감 최적화를 더 밀려면 **화면이 실제로 topmost인지**까지 포함해야 한다.

예시:

- 탭 전환 중 비활성 탭의 Arctic background cadence 즉시 축소 또는 pause
- sheet 뒤 배경이 가려진 상태에서는 secondary layer만 정지
- navigation push/pop 중 이전 화면의 보조 레이어 재생 빈도 축소

예상 효과:

- 전환 구간의 첫 hitch 완화에 직접적

리스크:

- 화면 상태 전달 plumbing이 필요함
- pause/resume 시 phase continuity를 자연스럽게 유지해야 함

### 5) 정적 glow/gradient 레이어 분리 또는 사전 합성

현재 `TimelineView` 내부에는 사실상 움직이지 않는 glow/gradient 레이어도 함께 들어 있다.
이 레이어를 animation tick 바깥으로 빼거나 사전 합성하면 diff/재렌더 부담을 더 줄일 수 있다.

- sky glow, horizon bloom, 일부 top-to-bottom tint gradient를 정적 레이어로 승격
- 동적인 curtain/ribbon/micro detail만 frame tick에 연결

예상 효과:

- 구현 난이도는 낮고 누적 비용 절감에 유리

리스크:

- 구조상 ZStack 분리가 필요할 수 있음

## Constraints

- 우선 타겟은 **iPhone**
- 범위는 Arctic **전체 surface** (`Tab`, `Detail`, `Sheet`, 관련 전환/스크롤 컨텍스트)
- 목표는 benchmark보다 **체감 성능 최우선**
- 시각 저하는 최대 **약 5% 이내**에서만 허용
- 테마 아이덴티티를 만드는 `ribbon + curtain + cold glow`는 유지해야 함

## Edge Cases

- 탭 전환 직후 첫 프레임에서 background가 재구성될 때 hitch 발생 가능
- interactive sheet drag 중 뒤 배경까지 계속 60fps로 돌면 손가락 추적성이 떨어질 수 있음
- ProMotion 기기에서도 현재 60fps cap이 충분히 자연스럽게 느껴지는지 확인 필요
- Reduce Motion / Low Power Mode 경로와 새로운 normal-mode 감축 로직이 충돌하지 않아야 함
- `Canvas` 전환 시 색감과 blend 결과가 snapshot 기준으로 미세하게 달라질 수 있음

## Scope

### MVP (Must-have)

- `ArcticAuroraMicroDetailOverlayView`와 `ArcticAuroraEdgeTextureOverlayView`의 `Canvas` 전환 검토 및 우선 적용
- normal 모드의 iPhone 전용 micro-layer LOD 감축
- secondary layer cadence 분리
- hidden / covered / transitioning 상태에서 playback 정책 강화

### Nice-to-have (Future)

- 정적 glow/gradient 레이어 사전 합성 또는 animation tick 바깥 분리
- 스크롤/전환 상태 연동 adaptive cadence
- Arctic 외 다른 테마로 재사용 가능한 background performance policy 추출
- Instruments 기반 before/after 기록 문서화

## Open Questions

- 현재 체감 문제가 가장 큰 플로우가 `탭 전환`, `리스트 스크롤`, `push/pop`, `sheet` 중 어디인지 추가 확인이 필요하다
- 5% visual budget을 전체 레이어에 균등 적용할지, `micro detail`에 더 몰아줄지 결정이 필요하다
- iPhone 첫 패스 이후 iPad/Watch까지 같은 전략을 확장할지 후속 판단이 필요하다

## Next Steps

- [ ] `/plan arctic theme max performance` 로 구현 계획 생성
