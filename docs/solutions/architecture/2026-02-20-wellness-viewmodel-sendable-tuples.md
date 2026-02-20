---
tags: [sendable, swift-concurrency, tuple, taskgroup, vital-sample, layer-boundary]
category: architecture
date: 2026-02-20
severity: important
related_files:
  - Dailve/Presentation/Wellness/WellnessViewModel.swift
  - Dailve/Presentation/Shared/Models/VitalCardData.swift
  - Dailve/Presentation/Shared/Extensions/WellnessScore+View.swift
  - Dailve/Domain/Models/WellnessScore.swift
related_solutions: []
---

# Solution: Wellness ViewModel Sendable Tuples & Layer Violations

## Problem

### Symptoms

- `FetchResults` struct가 `Sendable`로 선언되어 있지만 내부에 `(value: Double, date: Date)?` 튜플 사용 — Swift 6 strict concurrency에서 잠재적 warning
- `VitalCardData` DTO가 ViewModel 내부에 정의되어 다른 View에서 import 시 ViewModel 의존 발생
- `WellnessScore.Status.label`이 Domain 레이어에 위치하여 UI 문자열이 Domain에 침투
- `bodyFatChange` 계산 로직이 항상 nil을 반환하는 dead code
- 20개 TaskGroup catch 블록이 에러를 silent 처리

### Root Cause

1. **튜플의 Sendable 비보장**: Swift 튜플은 명시적 `Sendable` 프로토콜 준수를 갖지 않음. `Sendable` struct 내에서 사용하면 strict concurrency 검사 시 문제 발생 가능
2. **빠른 프로토타이핑 관성**: 초기 구현 시 편의를 위해 튜플과 ViewModel 내부 타입을 사용한 것이 리팩토링 없이 유지
3. **Correction #20 미적용**: Domain에 locale-specific 문자열(label)을 배치하면 안 된다는 기존 교정사항이 새 모델에 적용되지 않음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Shared/Models/VitalCardData.swift` | ViewModel에서 추출, 새 파일 생성 | ViewModel 의존 없이 공유 가능 (Correction #86) |
| `WellnessViewModel.swift` | 튜플 → `VitalSample` 교체 | Sendable 보장, `.value`/`.date` 접근 동일 |
| `WellnessViewModel.swift` | FetchValue enum에서 `weightResult`/`bmiResult`/`bodyFatResult` 제거, `vitalSample` 케이스로 통합 | enum 케이스 감소, 코드 간결화 |
| `WellnessViewModel.swift` | `bodyFatChange` dead logic 제거 | 항상 nil → guard 단순화 |
| `WellnessViewModel.swift` | 20개 catch 블록에 `print("[Wellness]")` 추가 | silent failure 방지 |
| `WellnessScore+View.swift` | `label` 프로퍼티 추가 | Domain → Presentation 이동 |
| `WellnessScore.swift` | `label` 프로퍼티 제거 | Domain에서 UI 문자열 제거 |

### Key Code

튜플 → VitalSample 변환 패턴:

```swift
// Before: non-Sendable tuple
let latestHRV: (Double, Date)? = hrvSamples.last.flatMap { sample in
    sample.value > 0 && sample.value <= 500 ? (sample.value, sample.date) : nil
}

// After: Sendable VitalSample
let latestHRV: VitalSample? = hrvSamples.last.flatMap { sample in
    sample.value > 0 && sample.value <= 500 ? VitalSample(value: sample.value, date: sample.date) : nil
}
```

BodyCompositionSample → VitalSample 변환:

```swift
// Before: removed enum case
return (.weight, .weightResult(value: w.value, date: w.date))

// After: reuse vitalSample case
return (.weight, .vitalSample(VitalSample(value: w.value, date: w.date)))
```

## Prevention

### Checklist Addition

- [ ] `Sendable` struct 내에 튜플 사용 금지 — `VitalSample` 등 명명 타입 사용
- [ ] 새 DTO가 2곳 이상에서 사용되면 즉시 `Shared/Models/`로 추출
- [ ] Domain 모델에 UI 문자열(label, displayName) 추가 시 `Presentation/Extensions/`로 분리

### Rule Addition (if applicable)

기존 `.claude/rules/swift-layer-boundaries.md`에 이미 포함된 원칙의 확장. 별도 규칙 추가 불필요.

## Lessons Learned

1. **기존 Sendable 타입을 재활용할 것**: `VitalSample`이 이미 `value: Double, date: Date`를 가진 `Sendable` struct로 존재했음. 새 타입을 만들거나 튜플을 쓰기 전에 기존 타입 검색 필수
2. **FetchValue enum 케이스는 최소화**: 동일 구조(`VitalSample?`)를 반환하는 케이스가 여러 개면 하나로 통합. 결과 수집 switch에서 FetchKey로 구분하면 충분
3. **Dead code는 리뷰에서 발견된 즉시 삭제**: bodyFatChange처럼 "나중에 구현"이라고 남기면 dead branch가 유지보수 비용만 증가시킴 (Correction #55)
