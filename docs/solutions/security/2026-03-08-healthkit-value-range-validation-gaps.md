---
tags: [healthkit, validation, sensor-data, range-check, body-composition, hrv, rhr, cloudkit-propagation]
category: security
date: 2026-03-08
severity: critical
related_files:
  - DUNE/Data/HealthKit/HRVQueryService.swift
  - DUNE/Data/HealthKit/BodyCompositionQueryService.swift
related_solutions: []
---

# Solution: HealthKit 센서값 범위 검증 누락

## Problem

### Symptoms

- HRV/RHR/Weight/BMI 쿼리 서비스에서 센서 오류, 수동 입력 오류 값이 필터 없이 통과
- 비정상 값이 CloudKit을 통해 전 디바이스에 전파될 위험
- 컨디션 점수 계산에서 비정상 값이 왜곡된 결과 생성

### Root Cause

`.claude/rules/input-validation.md`에 HealthKit 값 범위 테이블이 정의되어 있었지만, 실제 쿼리 서비스 구현에서 일부만 적용됨. 특히:
- `HRVQueryService`: HRV 하한(>=1)만 체크, 상한(<=500) 누락. RHR은 범위 체크 없음
- `BodyCompositionQueryService`: Weight/BMI에 일부 하한만 존재, 상한 누락. 통계 쿼리(`fetchQuantitySamples`)에는 범위 필터 자체가 없음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HRVQueryService.swift` | HRV guard에 `<= 500` 추가 | 센서 상한 초과 방어 |
| `HRVQueryService.swift` | RHR 2개 메서드에 `>= 20, <= 300` guard 추가 | 생리학적 범위 외 값 차단 |
| `HRVQueryService.swift` | Collection 쿼리에 동일 범위 적용 | 통계 경로도 동일 수준 보장 |
| `BodyCompositionQueryService.swift` | `validRange` 파라미터 추가 | 재사용 가능한 범위 필터 |
| `BodyCompositionQueryService.swift` | `.map` → `.compactMap` + range filter | out-of-range 값 자동 제거 |
| `BodyCompositionQueryService.swift` | Weight: `0...500`, BMI: `0...100` 적용 | 물리적/의학적 범위 |

### Key Code

```swift
// 재사용 가능한 validRange 파라미터 패턴
func fetchQuantitySamples(
    type: HKQuantityType,
    validRange: ClosedRange<Double>? = nil,
    ...
) -> [Sample] {
    // .map → .compactMap 전환
    .compactMap { sample in
        let value = sample.quantity.doubleValue(for: unit)
        if let range = validRange, !range.contains(value) { return nil }
        return Sample(value: value, date: sample.startDate)
    }
}

// 호출부
fetchQuantitySamples(type: .init(.bodyMass), validRange: 0...500, ...)
fetchQuantitySamples(type: .init(.bodyMassIndex), validRange: 0...100, ...)
```

## Prevention

### Checklist Addition

- [ ] 새 HealthKit 쿼리 추가 시 `input-validation.md`의 범위 테이블 참조하여 validRange 적용
- [ ] 동일 데이터의 모든 쿼리 경로(단건/컬렉션/통계)에서 동일한 범위 검증 적용 확인

### Rule Addition

`input-validation.md`에 이미 범위 테이블이 존재하므로 새 규칙 추가 불필요. 단, "동일 데이터의 **모든 쿼리 경로**에서 동일한 검증 수준" 강조사항은 이미 추가됨.

## Lessons Learned

1. **규칙의 존재 ≠ 규칙의 적용**: 규칙 문서에 테이블이 있어도 실제 코드에 100% 적용되었는지는 전수 검사가 필요하다
2. **`validRange` 파라미터화**: 범위 필터를 호출부에서 주입하면 쿼리 함수 재사용성이 높아지고, 새 데이터 타입 추가 시 범위 누락 가능성이 줄어든다
3. **통계 쿼리 경로 누락**: 단건 쿼리에는 guard가 있었지만 `Collection/Statistics` 쿼리에는 없었다. 같은 데이터를 다른 경로로 읽는 곳을 모두 찾아야 한다
