---
tags: [review-fix, localization, checkedcontinuation, watchconnectivity, swiftdata, startup-resilience, oslog]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/Data/Location/LocationTrackingService.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNE/App/DUNEApp.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNE/project.yml
  - DUNE/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-02-ios-cardio-live-tracking.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
---

# Solution: Run Pipeline Review Fix Batch

## Problem

전수 리뷰에서 P1/P2 항목이 동시에 발견되어 출시 안정성과 다국어 품질을 저해했다.

### Symptoms

- Location 권한 대기 로직에서 timeout Task와 delegate callback이 동시에 continuation을 다룰 수 있는 경합 여지
- `WellnessViewModel.partialFailureMessage` 하드코딩으로 번역 누락
- watch `SessionSummaryView` helper가 `String`을 `Text()`로 전달해 localization leak 발생
- WatchConnectivity DTO가 iOS/watch 양쪽에 중복 정의되어 drift 위험 존재
- 프로덕션 코드에 `print()` 로그 경로가 잔존
- persistent store 2차 실패 시 앱 시작 경로에서 즉시 `fatalError`

### Root Cause

- 빠른 구현 과정에서 cross-target DTO를 임시 복제로 유지
- 로깅/로컬라이제이션 규칙이 일부 신규 코드에 일관 적용되지 않음
- startup 복구 경로가 "삭제 후 재시도"까지만 고려되어 마지막 fallback이 부재

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `LocationTrackingService.swift` | `authLock` + `store/takeAuthContinuation` 도입 | timeout/delegate 동시 resume 경합 제거 |
| `WellnessViewModel.swift` | partial failure 문구 `String(localized:)` 전환 + `print`→`AppLogger` | L10N 누수 제거 + 로깅 표준화 |
| `Localizable.xcstrings` | `%lld of %lld` 키(en/ko/ja) 추가 | 동적 소스 개수 메시지 번역 보장 |
| `SessionSummaryView.swift` | helper 파라미터 `String`→`LocalizedStringKey` | `Text(StringProtocol)` 경로 누수 제거 |
| `WatchConnectivityModels.swift`(신규) | 공통 DTO 단일 소스 정의 | iOS/watch 모델 드리프트 방지 |
| `WatchSessionManager.swift` | DTO 정의 제거, validation extension만 유지 | 공통 DTO 재사용 |
| `WatchConnectivityManager.swift` | DTO 정의 제거 + `Logger` 적용 | 중복 제거 + 프로덕션 로깅 일관화 |
| `DUNEApp.swift`, `DUNEWatchApp.swift` | in-memory `ModelContainer` fallback 추가 | store 손상 시에도 앱 부팅 가능 |
| `WorkoutManager.swift`, `WeatherProvider.swift` | 잔여 `print` 제거 | 관측성 품질 개선 |
| `DUNETests/WatchWorkoutUpdateValidationTests.swift`(신규) | DTO validation 경계/필터링 테스트 추가 | 회귀 방지 |
| `DUNE/project.yml` | watch shared source group 중복 정의 정리 | malformed project warning 완화 |

### Key Code

```swift
private func takeAuthContinuation() -> CheckedContinuation<CLAuthorizationStatus, Never>? {
    authLock.withLock {
        let pending = authContinuation
        authContinuation = nil
        return pending
    }
}

if status != .notDetermined, let continuation = takeAuthContinuation() {
    continuation.resume(returning: status)
}
```

```swift
partialFailureMessage = String(
    localized: "Some data could not be loaded (\(failedSources.count) of \(primarySources.count) sources)"
)
```

## Prevention

### Checklist Addition

- [ ] `CheckedContinuation`은 set/take 원자 연산으로 단일 resume 보장
- [ ] ViewModel 사용자 노출 `String` 할당은 `String(localized:)` 강제
- [ ] View helper에서 `Text()` 입력 파라미터는 `LocalizedStringKey` 우선
- [ ] cross-target DTO는 복제 금지, 공통 모델 파일 단일 소스 유지
- [ ] startup storage 복구 경로에 in-memory fallback 포함
- [ ] 프로덕션 코드에서 `print()` 금지, `OSLog`/`AppLogger` 사용

### Rule Addition (if applicable)

`.claude/rules/` 신규 파일 추가 없이 기존 규칙(`localization.md`, `swift-layer-boundaries.md`, `documentation-standards.md`)에 따라 적용 가능.

## Lessons Learned

- "임시 복제" DTO는 작은 차이부터 drift가 시작되므로 즉시 공통 소스로 승격해야 한다.
- continuation timeout 패턴은 race-safe한 take/clear가 없으면 리뷰에서 다시 P1로 재발한다.
- startup 안정성은 migration 복구뿐 아니라 마지막 non-persistent fallback까지 있어야 실제 사용자 장애를 줄일 수 있다.
