---
tags: [healthkit, sleep, dedup, apple-watch, partial-coverage, data-loss, interval-merge]
category: healthkit
date: 2026-03-10
severity: critical
related_files:
  - DUNE/Data/HealthKit/SleepQueryService.swift
  - DUNETests/SleepQueryServiceTests.swift
related_solutions:
  - 2026-02-24-sleep-dedup-watch-detection.md
---

# Solution: Sleep Dedup — Watch 부분 커버리지 시 non-Watch 데이터 전체 삭제

## Problem

### Symptoms

- HealthKit(Apple Health)에서 6시간 수면으로 표시되는데, 앱에서는 3시간으로 표시됨 (정확히 절반)
- Sleep Score, Training Readiness, Wellness 등 모든 하류 점수가 과소 평가됨

### Root Cause

`deduplicateSamples()`에서 **Watch 소스가 non-Watch 소스와 부분 overlap 할 때, non-Watch 샘플 전체를 삭제**하는 버그.

**시나리오:**
1. iPhone Sleep Schedule이 `asleepUnspecified` 11pm-5am (6h) 기록
2. Apple Watch가 detailed stages 11pm-2am (3h) 기록 (사용자가 2am에 시계를 벗음)
3. Dedup: Watch `core 11pm-12am`이 iPhone `unspecified 11pm-5am`과 overlap
4. "Watch replaces non-Watch" 정책에 의해 iPhone 6h 샘플 **전체 삭제**
5. Watch 3h만 남음 → 앱 표시: 3h

```
iPhone:  [============================] 11pm ─────────────── 5am (6h)
Watch:   [=============]                11pm ──── 2am (3h)

Before fix: Watch 3h only (iPhone 6h entirely removed)
After fix:  Watch 3h + iPhone remainder 2am-5am (3h) = 6h total
```

**Apple Health는 시간 범위 기반 merge를 사용**하므로 11pm-5am = 6h로 올바르게 표시.
DUNE의 기존 dedup은 샘플 단위로 동작하여 부분 overlap 시 전체 샘플을 삭제.

### 부차적 버그: sweep-line 조기 중단

기존 `deduplicateSamples`에서 cross-source 대체 시 `result.remove(at:)` + `append()`로 인해
result 배열의 startDate 정렬이 깨졌음. 뒤에서부터 역순 sweep 시 `guard existing.endDate > sample.startDate else { break }` 조건이
정렬 깨진 배열에서 조기 중단하여 overlap을 놓칠 수 있었음.

## Solution

### Architecture Change

기존 monolithic `deduplicateSamples` (샘플 단위 전체 대체) →
**시간 범위 인식 2-phase dedup** (`deduplicateAndConvert`)로 교체.

### Algorithm

1. **Partition**: Watch / non-Watch 소스 분리
2. **Within-group dedup**: 각 그룹 내 same-source 및 cross-source dedup (기존 로직 유지)
3. **Watch → SleepStage 변환**: Watch 샘플을 SleepStage로 변환
4. **Watch coverage 계산**: Watch SleepStage들의 시간 범위를 merge
5. **non-Watch trimming**: non-Watch 샘플의 시간 범위에서 Watch coverage를 subtract → 나머지만 SleepStage로 변환

### Key Code

```swift
private func deduplicateAndConvert(_ samples: [HKCategorySample]) -> [SleepStage] {
    // 1. Partition by Watch vs non-Watch
    // 2. Same-source dedup within each group
    let dedupedWatch = deduplicateSameSourceGroup(watchSamples)
    let dedupedNonWatch = deduplicateSameSourceGroup(nonWatchSamples)

    // 3. Convert Watch → SleepStage
    var stages: [SleepStage] = dedupedWatch.compactMap { ... }

    // 4. Build merged Watch coverage intervals
    let watchCoverage = Self.mergedIntervals(stages.map { ($0.startDate, $0.endDate) })

    // 5. Non-Watch: trim against Watch coverage, keep remainder
    for sample in dedupedNonWatch {
        let trimmed = Self.subtractIntervals(from: (sample.startDate, sample.endDate), subtracting: watchCoverage)
        for (start, end) in trimmed { stages.append(...) }
    }
    return stages.sorted { $0.startDate < $1.startDate }
}
```

### Within-group dedup 개선

`deduplicateSameSourceGroup`에서 sweep-line의 `break` 기반 역순 탐색을 **전체 스캔**으로 변경:
```swift
// Before: break-early (정렬 깨지면 overlap 누락)
for i in stride(from: result.count - 1, through: 0, by: -1) {
    guard existing.endDate > sample.startDate else { break }  // ← 위험
}

// After: full scan (정렬 무관하게 정확)
for i in 0..<result.count {
    if existing.startDate < sample.endDate && sample.startDate < existing.endDate {
        overlapIndices.append(i)
    }
}
```

### Helper Functions

| Function | Purpose |
|----------|---------|
| `mergedIntervals` | 겹치는/인접한 시간 구간을 병합 |
| `subtractIntervals` | 시간 구간에서 다른 구간들을 빼고 나머지 반환 |

Both are `static` for independent testability.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SleepQueryService.swift` | `deduplicateSamples` → `deduplicateAndConvert` | 시간 범위 인식 cross-source dedup |
| `SleepQueryService.swift` | `deduplicateSameSourceGroup` 추가 | 그룹 내 dedup (full scan overlap 탐색) |
| `SleepQueryService.swift` | `mergedIntervals`, `subtractIntervals` 추가 | 시간 구간 연산 헬퍼 |
| `SleepQueryServiceTests.swift` | 12개 테스트 추가 | interval 헬퍼 경계 조건 검증 |

## Prevention

### Checklist

- [ ] Cross-source sleep dedup 변경 시, **부분 overlap** 시나리오 (Watch가 수면 일부만 커버) 반드시 검증
- [ ] Dedup 결과의 총 시간을 Apple Health 표시와 비교하여 drift 없는지 확인
- [ ] sweep-line 알고리즘에서 result 배열 정렬이 mutation으로 깨질 수 있음을 인지

### Rule Addition

`.claude/rules/healthkit-patterns.md`에 추가:

```markdown
## Sleep Cross-Source Dedup

Watch vs non-Watch dedup은 **시간 범위 인식** 방식으로 수행한다:
- Watch 커버 시간을 계산한 후, non-Watch 샘플에서 Watch 커버 부분만 제거
- non-Watch 샘플 전체를 삭제하면 Watch가 부분 커버일 때 데이터 손실 발생
- Apple Health의 동작과 일치: 시간별 최우선 소스 선택, 나머지 소스로 gap 채움
```

## Lessons Learned

1. **샘플 단위 대체 ≠ 시간 범위 대체**: HKCategorySample은 하나의 시간 범위를 나타내며, 부분 overlap 시 전체 삭제하면 커버되지 않는 시간이 유실된다. Apple Health는 시간 범위 기반 merge를 사용하므로 동일한 접근이 필요하다.

2. **사용자 행동 다양성**: 수면 중 시계를 벗는 것은 흔한 행동 (충전, 불편함 등). 이 경우 Watch는 부분 데이터만 가지고 iPhone Sleep Schedule은 전체 데이터를 가진다. 두 소스를 **상호 보완적**으로 활용해야 한다.

3. **sweep-line 정렬 가정**: 배열 mutation (remove + append) 후 정렬 불변량이 깨질 수 있다. break-early 최적화는 정렬이 보장될 때만 안전하다.
