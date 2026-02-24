---
tags: [healthkit, sleep, dedup, apple-watch, source-detection, productType, bundleIdentifier, data-loss]
category: healthkit
date: 2026-02-24
severity: critical
related_files:
  - Dailve/Data/HealthKit/SleepQueryService.swift
  - Dailve/Domain/Models/HealthMetric.swift
  - Dailve/Presentation/Shared/Extensions/SleepStage+View.swift
  - Dailve/Presentation/Shared/Charts/SleepStageChartView.swift
  - Dailve/Presentation/Sleep/SleepViewModel.swift
  - Dailve/Presentation/Shared/Detail/MetricDetailViewModel.swift
related_solutions: []
---

# Solution: Sleep Dedup — Watch 소스 감지 실패 + 동일 소스 데이터 삭제

## Problem

### Symptoms

- 앱 표시 수면 시간(~226분)이 Apple Health 표시(~314분)와 ~88분 차이
- Sleep Score, Training Readiness, Wellness 등 하류 점수 전부 과소 평가
- 날마다 차이 발생 (일관적 데이터 손실)

### Root Cause

**2가지 원인이 동시에 작용:**

1. **`isWatchSource()` 감지 실패**: Apple Watch 데이터는 iPhone에 동기화 시 `com.apple.health.{UUID}` 형태의 번들 ID를 사용함. 기존 코드는 `bundleIdentifier.contains("watch")`만 체크하여 UUID 기반 번들 ID를 Watch로 인식 못함

2. **동일 소스 overlap 전부 삭제**: 모든 샘플이 Watch로 인식 안 됨 → dedup의 `else` 분기("non-Watch overlaps existing → skip")에 진입 → 겹치는 샘플 4개(~88분) 삭제. HealthKit은 같은 소스에서 수면 단계 전환기에 겹치는 시간 구간을 정상적으로 기록하므로, 동일 소스 overlap은 유지해야 함

**데이터 흐름:**
```
17 raw samples (all from com.apple.health.{UUID})
  → isWatchSource() = false for ALL
  → 4 samples overlapping existing → "non-Watch skip" → DELETED
  → 13 samples remain → 226min (should be 314min)
```

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SleepQueryService.swift` | `isWatchSource`: `productType.hasPrefix("Watch")` 우선 체크 | Watch6,18 등 하드웨어 모델 기반 감지 (가장 신뢰) |
| `SleepQueryService.swift` | dedup: 동일 소스 overlap은 유지 | HealthKit이 같은 소스에서 다른 stage를 겹치는 시간대로 기록하는 것은 정상 |
| `SleepQueryService.swift` | dedup: 동일 소스 `asleepUnspecified`는 구체적 stage 존재 시 skip | 3rd-party 앱이 부모+자식 span을 겹쳐 쓸 때 과다 집계 방지 |
| `HealthMetric.swift` | `SleepStage.Stage`에 `.unspecified` case 추가 | `asleepUnspecified` (rawValue 1) 샘플 보존 |
| `SleepStage+View.swift` | `label`, `color` Presentation으로 이동 + static color 캐싱 | Domain layer 경계 준수 (#20, #36) + chart 성능 (#105) |
| `SleepStageChartView.swift` | `stageColor()` 삭제, `segmentColor` → enum 역매핑 위임 | Color 정의 단일 소스 (3곳 → 1곳) |
| `SleepViewModel.swift` | `cachedOutput`, `rebuildStageBreakdown()` 캐싱 | 렌더당 UseCase 3회 → 1회, stageBreakdown 5×O(N) → 1회 |
| `SleepViewModel.swift` | `.unspecified`를 `.core`에 병합하지 않고 별도 "Asleep" 표시 | Score 계산과 차트 표시 일관성 (#23) |
| `MetricDetailViewModel.swift` | stacked chart 세그먼트에 "Asleep" 추가 | Detail 차트도 동일 정책 적용 |

### Key Code

**Watch 소스 감지 (핵심 수정):**
```swift
private func isWatchSource(_ sample: HKSample) -> Bool {
    // 1. Product type: most reliable (e.g., "Watch6,18")
    if let productType = sample.sourceRevision.productType,
       productType.hasPrefix("Watch") {
        return true
    }
    // 2. Bundle ID fallback (e.g., com.apple.NanoHealthApp)
    let bundleID = sample.sourceRevision.source.bundleIdentifier
    return bundleID.localizedCaseInsensitiveContains("watch")
}
```

**동일 소스 dedup (핵심 수정):**
```swift
if allSameSource {
    // Skip broad unspecified when specific stages already cover the period
    let category = HKCategoryValueSleepAnalysis(rawValue: sample.value)
    if category == .asleepUnspecified {
        let hasSpecificOverlap = overlapIndices.contains { i in
            let existing = HKCategoryValueSleepAnalysis(rawValue: result[i].value)
            return existing != .asleepUnspecified && existing != .inBed
        }
        if hasSpecificOverlap { continue }
    }
    result.append(sample)
    continue
}
```

## Prevention

### Checklist Addition

- [ ] HealthKit 소스 판별 시 `bundleIdentifier` 문자열 매칭에만 의존하지 않는다. `sourceRevision.productType`을 우선 확인
- [ ] Dedup 알고리즘 변경 후 Apple Health 표시 값과 비교 검증한다
- [ ] 새 수면 관련 기능 추가 시 `.unspecified` stage 처리를 확인한다

### Rule Addition

`.claude/rules/healthkit-patterns.md`에 추가 권장:

```markdown
## Watch 소스 감지

`bundleIdentifier.contains("watch")` 단독 사용 금지. Apple Watch 데이터는 iPhone에 동기화 시 `com.apple.health.{UUID}` 형태의 번들 ID를 사용하므로 `sourceRevision.productType.hasPrefix("Watch")`를 우선 체크.

## Sleep Dedup 원칙

- 동일 소스 overlap: 유지 (다른 단계의 전환기 overlap은 정상)
- 동일 소스 unspecified + 구체적 stage overlap: unspecified skip
- 다른 소스 overlap: Watch 우선, 동일 우선순위면 더 긴 duration 유지
```

## Lessons Learned

1. **HealthKit 번들 ID는 예측 불가**: Apple Watch → iPhone 동기화 경로에서 `com.apple.health.{UUID}` 패턴 사용. 문서화되지 않은 동작이므로 `productType` 같은 구조적 프로퍼티를 우선 활용해야 함

2. **Dedup은 데이터 손실의 주범**: 보수적으로 설계해야 함. "의심 시 유지"가 "의심 시 삭제"보다 안전 — 과소 집계보다 과다 집계가 사용자 신뢰에 덜 해로움

3. **디버그 로깅은 진단 후 즉시 제거**: 검증 완료된 디버그 로그를 프로덕션에 남기면 성능/보안 양쪽에서 문제. ISO8601DateFormatter 매 호출 생성, 번들 ID 노출 등

4. **Display ↔ Score 일관성 필수**: 차트에서 `.unspecified`를 `.core`로 보여주면서 점수 계산에서는 `.core`로 안 세면 사용자가 "Core 4시간인데 왜 점수가 낮지?" 혼란. Correction #23 (동일 데이터 동일 검증 수준) 원칙 재확인

5. **`sourceRevision.productType`은 HealthKit의 숨은 보석**: 하드웨어 모델(`Watch6,18`, `iPhone15,3`)을 직접 제공하므로 소스 분류에 가장 신뢰할 수 있는 필드
