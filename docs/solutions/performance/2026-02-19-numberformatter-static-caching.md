---
tags: [numberformatter, caching, swift-charts, hot-path, formatting, performance]
category: performance
date: 2026-02-19
severity: important
related_files:
  - Dailve/Presentation/Shared/Extensions/Double+Formatting.swift
related_solutions:
  - performance/2026-02-16-computed-property-caching-pattern.md
---

# Solution: NumberFormatter Static Caching for Chart Rendering

## Problem

### Symptoms

- 6관점 리뷰에서 P1 성능 이슈로 지적
- `formattedWithSeparator()` 호출마다 `NumberFormatter` 인스턴스 생성
- Swift Charts 렌더링 중 수백 회 호출되는 hot path

### Root Cause

`Double.formattedWithSeparator()` 와 `Int.formattedWithSeparator` 가 매 호출마다 새 `NumberFormatter` 를 할당.
`NumberFormatter` 는 `NSObject` 기반으로 생성 비용이 높고, Charts의 `SectorMark` / `BarMark` 렌더링에서 데이터 포인트마다 호출됨.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Double+Formatting.swift` | `FormatterCache` enum + static let | 인스턴스 재사용 |

### Key Code

```swift
private enum FormatterCache {
    static let integerFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()
    static let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()
}

extension Double {
    func formattedWithSeparator(fractionDigits: Int = 0) -> String {
        let formatter: NumberFormatter = switch fractionDigits {
        case 0: FormatterCache.integerFormatter
        case 1: FormatterCache.oneDecimalFormatter
        default:
            // Rare path — allocate on demand
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            f.minimumFractionDigits = fractionDigits
            f.maximumFractionDigits = fractionDigits
            return f.string(from: NSNumber(value: self)) ?? "\(self)"
        }
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
```

### Pattern

`private enum` (case-less) 로 namespace 생성 → `static let` 으로 lazy 초기화 + thread-safe 싱글턴.
`fractionDigits` 0과 1이 전체 사용의 99%를 차지하므로 이 두 경우만 캐싱.

## Prevention

### Checklist Addition

- [ ] `NumberFormatter`, `DateFormatter`, `MeasurementFormatter` 생성이 반복 호출 경로에 있는지 확인
- [ ] Charts 렌더링에서 사용되는 포맷팅은 반드시 캐시된 formatter 사용

### Rule Addition

기존 Correction Log #8 (computed property 캐싱)과 함께, **Formatter 객체는 반드시 static 캐싱** 규칙 적용.

## Lessons Learned

- `NumberFormatter` 는 `NSObject` 기반이므로 Swift의 value type 최적화를 받지 못함
- Charts hot path에서는 `String(format:)` 이 더 빠르지만, locale-aware 천 단위 구분자가 필요하면 `NumberFormatter` 캐싱이 정답
- `private enum` 패턴은 Swift에서 namespace + static-only 타입을 표현하는 관용적 방법
