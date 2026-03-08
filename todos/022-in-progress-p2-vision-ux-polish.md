---
source: brainstorm/vision-pro-production-roadmap
priority: p2
status: in-progress
created: 2026-03-08
updated: 2026-03-08
---

# Phase 5B: visionOS UX Polish + Spatial Native

## 진행 메모

- Dashboard는 4개 quick action 중심으로 단순화됐고, `Coming Soon` 노출이 제거됐다.
- `VisionVolumetricExperienceView`의 2D 컨트롤이 ornament로 분리되고 배경 gradient가 제거됐다.
- volumetric 3D scene들의 drag rotation 패턴과 empty state copy가 통일됐다.
- 구현 근거와 재사용 패턴은 `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`에 기록돼 있다.
- `defaultWindowPlacement` 기반 dashboard/chart3d placement planner와 targeted unit test가 추가됐다.
- DUNEVision에 남아 있던 `.caption` 사용이 `.callout` 이상으로 정리됐다.
- 남은 closure 범위는 visionOS simulator 또는 실기기에서 window placement를 실제로 눈으로 검증하는 일뿐이다.
- Phase 5C(`todos/023-in-progress-p2-vision-phase4-remaining.md`)는 placement 실기기 검증만 남은 상태라 병행 진행한다.

## 목표

visionOS HIG를 준수하고, iOS 복사가 아닌 공간 네이티브 경험을 제공한다.

## 범위

### 1. Dashboard 리팩토링

- 핵심 4개 metric 중심으로 단순화 (Condition, HRV, RHR, Sleep)
- 카드 최소 높이 160pt+, 2열 그리드
- Quick action 중복 제거 (toolbar에 이미 있는 것)
- 폰트 최소 .callout 이상

### 2. Volumetric Ornament 분리

- VisionVolumetricExperienceView: 2D 컨트롤(Picker, metric strip) → ornament로 분리
- RealityView만 volumetric 윈도우에 유지
- 배경 LinearGradient 제거 (공간에서 불투명 배경 부적합)

### 3. Typography & Material 체계화

- 최소 폰트 .callout로 상향 (visionOS에서 .caption은 보조 전용)
- glass material depth 규칙:
  - 컨테이너: .regularMaterial
  - 카드/셀: .ultraThinMaterial
  - 오버레이: .thinMaterial
- DS 토큰으로 정의

### 4. 공통 Spatial Gesture Modifier

- SpatialOrbitGesture: drag(delta 기반) + magnify + spatial tap
- 모든 3D scene에 일관 적용
- 선택 피드백 일관화 (scale + brightness)

### 5. Window Management

- defaultWindowPlacement로 메인 윈도우 대비 상대 위치 지정
- dashboard 4개 윈도우 겹침 방지
- chart3d를 volumetric WindowGroup으로 전환 검토

### 6. Empty State Design

- skeleton loading (.redacted + shimmer)
- 데이터 없을 때 onboarding CTA
- 로딩 중 subtle pulse 애니메이션

### 7. Information Architecture

- Wellness/Life 탭 컨텐츠 충분하지 않으면 2탭으로 축소 검토
- 또는 탭 구조 제거 → 단일 윈도우 + 멀티 윈도우 패턴

## 검증 기준

- [x] Dashboard에 7개 이상 카드가 한 화면에 나열되지 않음
- [x] Volumetric 윈도우에 2D 컨트롤이 직접 포함되지 않음
- [x] 모든 텍스트가 .callout 이상
- [x] 3D scene에서 일관된 gesture 동작 (orbit, zoom, tap)
- [ ] 윈도우 4개 동시 열기 시 겹치지 않음

## 참고

- Apple Human Interface Guidelines: Spatial Design
- `docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md` UX 감사 결과
- `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`
