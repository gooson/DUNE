---
tags: [settings, tint-color, rest-timer, watch-sync, workout]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Settings TintColor + Rest Time 자동 적용

## Problem Statement

### Feature 1: 시스템 기본 파란색 tint가 앱 테마와 불일치

현재 앱에서 Toggle, Stepper, NavigationLink chevron, Button 등 시스템 컨트롤이 iOS 기본 파란색으로 표시됨. AccentColor xcasset은 warm brown(0.788, 0.584, 0.420)으로 설정되어 있으나, iOS 26 `.sidebarAdaptable` TabView 환경에서 일부 컨트롤이 이를 무시.

**영향 범위**: Settings의 Toggle/Stepper, NavigationLink chevron, Form 내 Button 등

### Feature 2: Settings의 Rest Time이 워크아웃에 적용되지 않음

`WorkoutSettingsStore.restSeconds`(15-600초, 기본 90초)를 사용자가 설정할 수 있지만, 실제 워크아웃 실행 시 **모든 경로에서 30초가 하드코딩**되어 있음:

| 경로 | 현재 값 | 기대 값 |
|------|---------|---------|
| `WorkoutSessionView.startRest()` | 30초 하드코딩 | WorkoutSettingsStore.restSeconds |
| `CompoundWorkoutView` → `RestTimerViewModel()` | defaultDuration=30 | WorkoutSettingsStore.restSeconds |
| Watch → `currentEntry?.restDuration ?? 30` | 30초 fallback | 글로벌 설정값 |

추가로, `TemplateEntry.restDuration`은 이미 운동별 override를 지원하지만, Watch에는 글로벌 설정값이 전달되지 않아 fallback이 항상 30초.

## Target Users

- 앱 사용자 전체 (iOS + Watch)
- 특히 세트 간 휴식 시간이 긴 중량 운동 사용자 (2-5분 필요)

## Success Criteria

### Feature 1
- [ ] Settings의 Toggle, Stepper가 앱 테마 색상(warm glow)으로 표시
- [ ] NavigationLink chevron이 테마 색상으로 표시
- [ ] 기존에 명시적 `.tint()`이 설정된 요소(activity, red 등)는 영향 없음

### Feature 2
- [ ] iOS: Settings에서 설정한 rest time이 WorkoutSessionView에 적용
- [ ] iOS: Settings에서 설정한 rest time이 CompoundWorkoutView에 적용
- [ ] Watch: 글로벌 rest time 설정이 applicationContext로 동기화
- [ ] Watch: 워크아웃 시작 시 최신 rest time이 message로 전달
- [ ] 운동별 override (`TemplateEntry.restDuration`)가 글로벌 설정보다 우선
- [ ] 운동별 override가 Watch에도 전달

## Proposed Approach

### Feature 1: Root-level `.tint()` 적용

```swift
// DUNEApp.swift - appContent에 .tint 추가
ContentView(...)
    .tint(DS.Color.warmGlow)
```

단일 수정으로 모든 하위 뷰의 기본 tint가 warm glow로 변경. 이미 `.tint(DS.Color.activity)` 등 명시적으로 설정된 요소는 override되지 않음 (SwiftUI는 가장 가까운 `.tint()` 우선).

### Feature 2: Rest Time 파이프라인 통합

**2-1. iOS 적용 (버그 수정)**
- `WorkoutSessionView.startRest()`: 30 → `WorkoutSettingsStore.shared.restSeconds`
- `CompoundWorkoutView`: `RestTimerViewModel()` init 시 `defaultDuration` = `WorkoutSettingsStore.shared.restSeconds`
- 운동별 override: `TemplateEntry.restDuration ?? globalRestSeconds`

**2-2. Watch 동기화 (이중화)**
- **applicationContext**: exerciseLibrary 전송 시 `globalRestSeconds` 필드 추가
- **message**: `WatchWorkoutState`에 `restSeconds` 필드 추가
- Watch → `globalRestSeconds` 저장 → `currentEntry?.restDuration ?? globalRestSeconds ?? 30`

**2-3. 운동별 override**
- `TemplateEntry.restDuration`은 이미 존재
- Watch DTO에 per-exercise `restDuration` 전달 확인 (현재 `WatchExerciseInfo`에는 없음)
- CreateTemplateView에서 이미 Picker로 설정 가능 ("Default", "30s", "60s" 등)

## Constraints

- iOS 26+ only
- Watch DTO 변경 시 양쪽 target 동기화 필수 (Correction #69, #138)
- `applicationContext`는 마지막 값만 유지 (적합)
- `sendMessage`는 Watch가 reachable할 때만 작동 → applicationContext가 기본, message가 보조

## Edge Cases

1. **Watch가 연결되지 않은 상태에서 설정 변경**: applicationContext 큐에 쌓여 다음 연결 시 자동 전달
2. **운동별 override와 글로벌 설정 충돌**: override가 항상 우선 (nil일 때만 글로벌)
3. **설정 변경 후 진행 중인 워크아웃**: 진행 중 워크아웃의 rest time은 시작 시점 값 유지 (실시간 반영 X)
4. **Watch에서 독립 실행 (iPhone 없이)**: applicationContext의 마지막 동기화된 값 사용, 없으면 30초 fallback 유지

## Scope

### MVP (Must-have)
- [ ] Feature 1: Root `.tint(DS.Color.warmGlow)` 적용
- [ ] Feature 2: iOS rest time에 WorkoutSettingsStore 값 적용
- [ ] Feature 2: Watch에 글로벌 rest time applicationContext 동기화
- [ ] Feature 2: Watch 워크아웃 시작 시 rest time message 전달
- [ ] Feature 2: 운동별 override가 글로벌보다 우선

### Nice-to-have (Future)
- [ ] 운동별 rest time override를 Watch에서도 설정 가능
- [ ] rest time 변경 시 실시간 반영 (진행 중 워크아웃)
- [ ] 테마 시스템 전체 구현 (Ocean Cool, Forest Green)

## Open Questions

1. ~~Feature 1의 범위~~ → 시스템 기본 파란색 tint를 앱 테마로 변경 (root `.tint()`)
2. ~~Watch 동기화 방식~~ → applicationContext + message 이중화
3. ~~운동별 override~~ → MVP에 포함 (이미 TemplateEntry에 기반 있음)

## Key Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/App/DUNEApp.swift` | `.tint(DS.Color.warmGlow)` 추가 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `startRest()` → 글로벌 설정값 사용 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | `setTimer` 초기화 시 설정값 사용 |
| `DUNE/Presentation/Exercise/RestTimerViewModel.swift` | `defaultDuration` 초기값 변경 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | applicationContext에 restSeconds 추가 |
| `DUNEWatch/WatchConnectivityManager.swift` | restSeconds 수신 + 저장 |
| `DUNEWatch/Views/MetricsView.swift` | fallback을 globalRestSeconds로 변경 |

## Next Steps

- [ ] `/plan` 으로 Feature 1 (TintColor) 구현 계획 생성
- [ ] `/plan` 으로 Feature 2 (Rest Time) 구현 계획 생성
- 두 기능은 별도 PR로 병렬 진행
