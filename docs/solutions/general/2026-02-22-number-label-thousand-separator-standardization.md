---
tags: [number-formatting, thousand-separator, ui-consistency, watchos, swiftui]
category: general
date: 2026-02-22
status: implemented
severity: important
related_files:
  - Dailve/Presentation/Shared/Extensions/Double+Formatting.swift
  - Dailve/Presentation/Shared/Extensions/HealthMetric+View.swift
  - DailveWatch/Int+Formatting.swift
  - DailveTests/NumberFormattingTests.swift
related_solutions:
  - performance/2026-02-19-numberformatter-static-caching.md
---

# Solution: 숫자 라벨 천 단위 구분자 표준화

## Problem

여러 화면에서 숫자 라벨이 `4321`처럼 표기되고, 일부 화면은 `4,321`로 표기되는 불일치가 존재했습니다.

### Symptoms

- 동일 성격의 수치(볼륨/칼로리/세트/걸음/요약 통계)가 화면마다 다른 형식으로 표시됨
- `String(format: "%.0f")`, `"\(Int(...))"` 직접 렌더링이 다수 분산되어 누락 발생
- Watch 화면은 `1.2k` 축약 표기와 일반 정수 표기가 혼재

### Root Cause

숫자 렌더링 진입점이 하나로 고정되지 않아 각 View/ViewModel이 개별 포맷 문자열을 직접 사용했고, 신규 UI 추가 시 재사용 기준이 강제되지 않았습니다.

## Solution

공통 포맷 함수를 기준으로 숫자 라벨 렌더링을 통일하고, 주요 표시 지점의 직접 포맷 문자열을 전면 치환했습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Double+Formatting.swift` | `alwaysShowSign` 옵션 추가 | `+1,234.5` 형식까지 공통 함수로 처리 |
| `HealthMetric+View.swift` 외 다수 UI 파일 | `String(format:)`/직접 Int 문자열을 `formattedWithSeparator`로 교체 | 라벨 표기 일관성 확보 |
| `DailveWatch/Int+Formatting.swift` | Watch 전용 정수 포맷 확장 추가 | Watch에서도 동일 규칙 적용 |
| `NumberFormattingTests.swift` | 천 단위/소수/부호 포맷 테스트 추가 | 포맷 회귀 방지 |
| `CLAUDE.md` | Correction Log #97 추가 | 향후 직접 문자열 포맷 재도입 방지 |

### Key Code

```swift
extension Double {
    func formattedWithSeparator(fractionDigits: Int = 0, alwaysShowSign: Bool = false) -> String {
        let formatted = formatter.string(from: NSNumber(value: self)) ?? "\(self)"
        guard alwaysShowSign, self > 0 else { return formatted }
        return "+\(formatted)"
    }
}
```

## Prevention

### Checklist Addition

- [ ] UI 숫자 라벨은 `formattedWithSeparator` 경유 여부를 리뷰 체크리스트에 포함
- [ ] `String(format: "%.0f")`가 표시 문자열에 쓰였는지 grep으로 점검
- [ ] Watch/iOS 모두 동일한 숫자 표기 규칙을 적용했는지 확인

### Rule Addition

Correction Log #97 추가: 화면 숫자 표기에 직접 포맷 문자열 사용 금지, 공통 formatter 경유 필수.

## Lessons Learned

- 숫자 포맷 일관성은 “디자인 이슈”가 아니라 재발성 결함이므로 공통 API 강제가 필요합니다.
- 캐시된 formatter를 재사용하면 일관성과 성능을 동시에 확보할 수 있습니다.
- Watch와 iOS를 분리 타깃으로 운영하는 경우 동일 UX 규칙도 타깃별 확장으로 명시해야 누락이 줄어듭니다.
