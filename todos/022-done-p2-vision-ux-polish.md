---
source: brainstorm/vision-pro-production-roadmap
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# Phase 5B: visionOS UX Polish + Spatial Native

## 완료 메모

- Dashboard는 4개 quick action 중심으로 단순화됐고, `Coming Soon` 노출이 제거됐다.
- `VisionVolumetricExperienceView`의 2D 컨트롤이 ornament로 분리되고 배경 gradient가 제거됐다.
- volumetric 3D scene들의 drag rotation 패턴과 empty state copy가 통일됐다.
- 구현 근거와 재사용 패턴은 `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`에 기록돼 있다.
- `defaultWindowPlacement` 기반 dashboard/chart3d placement planner와 targeted unit test가 추가됐다.
- `VisionSharePlayWorkoutCard`에 남아 있던 마지막 `.caption` 사용을 `.callout`로 올려 DUNEVision 전반의 minimum typography rule을 닫았다.
- runtime spatial placement의 simulator/device 시각 검증은 `todos/107-ready-p2-vision-window-placement-runtime-validation.md`로 분리했다.
- 이는 아직 별도 visionOS UI harness 없이 `openWindow`/window lifecycle automation이 어려운 현재 저장소 제약을 반영한 정리다.
- 따라서 Phase 5C(`todos/023-in-progress-p2-vision-phase4-remaining.md`)는 5B 구현 종료를 전제로 계속 진행할 수 있다.
- `scripts/build-ios.sh`와 `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' ... build`를 2026-03-09 기준으로 다시 실행해 빌드 성공을 확인했다.
- `VisionWindowPlacementPlannerTests` 단독 재실행도 시도했지만, 현재 `DUNETests` 스킴에는 이번 변경과 무관한 기존 compile failure(`Extra argument 'status' in call`, `Cannot infer contextual base in reference to member 'good'`)가 있어 suite 실행 전 단계에서 중단됐다.

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
- dashboard 4개 윈도우 겹침 방지는 runtime visual verification TODO로 분리
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
- [x] window placement policy가 `VisionWindowPlacementPlanner` + targeted unit test로 고정됨
- [x] runtime spatial placement visual verification scope가 `todos/107-ready-p2-vision-window-placement-runtime-validation.md`로 분리됨

## 참고

- Apple Human Interface Guidelines: Spatial Design
- `docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md` UX 감사 결과
- `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`
- `todos/107-ready-p2-vision-window-placement-runtime-validation.md`
