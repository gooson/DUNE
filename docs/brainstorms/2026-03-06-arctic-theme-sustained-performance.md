---
tags: [theme, arctic-dawn, performance, thermal, battery, memory, swiftui, shared-wave]
date: 2026-03-06
category: brainstorm
status: draft
---

# Brainstorm: Arctic Theme 지속 성능 개선

## Problem Statement

Arctic Dawn는 이미 프레임 안정성 중심 최적화(LOD, render trim, TimelineView 통합, drawingGroup 적용)를 거쳤지만,
여전히 **지속 사용 관점의 비용**이 가장 큰 테마 후보이다.

이번 목표는 단순히 "덜 끊기게"가 아니라 다음 4가지를 함께 개선하는 것이다.

- 발열 감소
- 스크롤 버벅임 감소
- 배터리 소모 감소
- 메모리 사용 안정화

조건은 명확하다.

- **디자인 100% 유지**
- **모든 사용자 대상**
- **Arctic에 국한되지 않고, 재사용 가능한 공통 성능 개선이 있으면 포함**

즉, 레이어를 없애거나 테마 인상을 바꾸는 방식이 아니라,
**동일한 비주얼을 더 적은 CPU/GPU/메모리 비용으로 유지하는 구조 최적화**가 필요하다.

## Current Context

이미 반영된 Arctic 관련 최적화:

- `ArcticAuroraLOD` 기반 normal/conserve 품질 단계
- Arctic overlay loop의 임시 배열/중복 animation 시작 경로 정리
- `TimelineView(.animation(minimumInterval: 1.0 / 60.0))` 기반 단일 시간 소스
- 고비용 overlay의 `drawingGroup()` 적용

현재 남은 의심 지점:

- `OceanWaveBackground.swift` 내부의 Arctic overlay stack이 여전히 가장 높은 렌더 비용 후보
- Shape path 계산과 blur/blend 조합이 지속 사용 시 발열/배터리 비용으로 이어질 가능성
- background가 화면 밖에 있어도 계속 살아 있거나 텍스처가 재생성되면 메모리/에너지 낭비 가능성
- 공통 wave/theme 배경 계층이 없어 비슷한 비용 패턴이 다른 테마로 확산될 위험

## Target Users

- Arctic Dawn를 사용하는 모든 사용자
- 특정 기기군이 아니라 전체 사용자 기준으로 체감 개선이 필요한 상태
- 구형 기기, 일반 60Hz 기기, ProMotion 기기 모두에서 동일하게 이득을 받아야 함

## Success Criteria

- Arctic Tab/Detail/Sheet 배경에서 스크롤 시 체감 jank가 줄어든다
- 5분 이상 Arctic 사용 시 발열과 배터리 소모가 기존보다 낮다
- 반복적인 탭 왕복/시트 오픈/닫기 이후 메모리 사용량이 계속 누적되지 않는다
- Arctic의 커튼, 리본, 마이크로 디테일, 엣지 글로우 인상이 시각적으로 동일하다
- Arctic에 적용한 구조가 다른 wave 계열 테마에도 재사용 가능하다

## Proposed Approach

### 1. 측정 기준 먼저 고정

최적화 방향이 분산되지 않도록, 구현 전에 공통 측정 시나리오를 먼저 만든다.

- 시나리오 A: Arctic Tab 진입 후 30초 idle
- 시나리오 B: Arctic 리스트 60초 연속 스크롤
- 시나리오 C: Arctic ↔ 다른 탭 왕복 20회
- 시나리오 D: Arctic Detail/Sheet 반복 진입

수집 항목:

- Core Animation: frame pacing / hitch
- Time Profiler: Shape path / body recomposition hotspot
- Energy Log: sustained CPU/GPU cost
- Memory Graph / Allocations: 텍스처, seed 배열, gradient/color 재할당 여부

### 2. Arctic 전용 최적화는 "무회귀 구조 정리"에 집중

디자인 100% 유지 조건이므로, 아래 방식이 우선이다.

- 화면 밖 background 업데이트 중단
- 동일 phase/seed/palette의 재계산 제거
- 동일 overlay subtree의 불필요한 재합성 제거
- path 계산용 sample/lookup 값을 init-time 또는 static cache로 이동

### 3. 공통 wave background 성능 레이어 도입 검토

Arctic만 고치고 끝내면, 유사한 문제는 다른 테마에서 반복될 수 있다.
그래서 공통 구조를 먼저 정의하는 편이 장기적으로 유리하다.

후보 공통화 포인트:

- `ThemeBackgroundVisibilityGate`: 화면에 실제로 보일 때만 animation tick 허용
- `WaveAnimationClock`: 테마별 phase를 하나의 공통 시간/정책 객체에서 파생
- `WaveRenderCache`: gradient, palette, seed, sampling table의 공통 cache 계층
- `WavePerformanceProfile`: 테마별 허용 cadence / compositing / clipping 정책 정의

### 4. 스크롤 순간의 체감 개선을 따로 본다

지속 발열과 별개로, 사용자가 가장 먼저 느끼는 것은 스크롤 hitch다.
따라서 스크롤 중에는 background가 main content를 방해하지 않도록 우선순위를 재조정할 필요가 있다.

### 5. 메모리 안정성은 texture lifecycle 관점으로 점검

Arctic는 `drawingGroup()`과 다수의 overlay를 사용하므로,
문제가 있다면 단순 Swift 객체보다 **래스터 텍스처 lifecycle** 쪽에서 나타날 가능성이 높다.

## Constraints

- 디자인 100% 유지
- Arctic의 핵심 레이어 삭제 금지
- 시각 톤, 색 구성, 모션 인상 변경 금지
- 사용자 전체를 대상으로 하므로 특정 기기 최적화에만 의존하면 안 됨
- Arctic 전용 수정이어도, 재사용 가능한 패턴이면 shared layer로 승격 검토

## Edge Cases

- 화면에 보이지 않는 탭 background가 계속 tick될 수 있음
- Detail/Sheet가 겹칠 때 background 중복 합성이 발생할 수 있음
- ProMotion 기기와 60Hz 기기에서 cadence 체감이 다를 수 있음
- theme 전환 직후 이전 테마 texture가 잠시 유지될 수 있음
- iPad 계열에서 더 넓은 viewport 때문에 동일 레이어가 더 큰 비용을 낼 수 있음

## Scope

### MVP (Must-have)

- [x] Instruments 기준 성능 baseline 시나리오 정의
- [x] Arctic background의 off-screen/hidden 상태 업데이트 정책 정리
- [x] Arctic hot path의 static cache/lookup hoist 후보 식별
- [x] 메모리 누적 여부 확인을 위한 texture/spec lifecycle 점검 항목 정의
- [x] 다른 테마에도 바로 재사용 가능한 공통 성능 레이어 후보 도출

### Nice-to-have (Future)

- [ ] 공통 `WaveAnimationClock` / `WavePerformanceProfile` 추출
- [ ] interaction-aware cadence shaping 도입
- [ ] 테마별 background 성능 체크리스트 문서화
- [ ] Instruments before/after 결과를 solution 문서로 축적

## Open Questions

- 실제 지속 발열의 주원인은 CPU path 계산인가, GPU compositing인가?
- hidden tab background가 현재도 계속 active tick을 소비하는가?
- 메모리 증가는 texture retained issue인가, 단순 정상 캐시 증가인가?
- Arctic에서 유효한 최적화가 Solar/Forest/Hanok에도 동일하게 적용 가능한가?

## Next Steps

- [ ] `/plan arctic theme sustained performance` 로 구현 계획 생성
- [ ] Instruments baseline 시나리오와 측정 지표를 plan에 포함
- [ ] Arctic 전용 후보와 shared wave 후보를 분리해 우선순위 결정
