---
tags: [testing, localization, swift-testing, healthmetric, viewmodel-validation]
category: testing
date: 2026-03-02
severity: important
related_files:
  - DUNETests/HealthMetricTests.swift
  - DUNETests/InjuryViewModelTests.swift
  - DUNETests/LifeViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-01-localization-completion-audit.md
---

# Solution: Locale-Safe Unit Test Assertions for Formatting and Validation Errors

## Problem

유닛 테스트가 로케일에 따라 다른 문자열을 반환하는 환경에서 불안정하게 실패했다.

### Symptoms

- `HealthMetricTests`의 수면 포맷 테스트가 영문 고정 문자열 기대값과 불일치
- `InjuryViewModelTests`, `LifeViewModelTests`가 validation error의 영문 substring(`future`, `after`, `past`, `name`)을 찾지 못해 실패

### Root Cause

테스트 assertion이 `String(localized:)` 결과를 직접 비교하지 않고, 영문 하드코딩 문자열/substring에 의존하고 있었다.

## Solution

로케일 의존 구간을 공통 포맷 함수 또는 `String(localized:)` 비교로 변경해 언어 환경 차이를 제거했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/HealthMetricTests.swift` | sleep formattedValue 기대값을 `sleep.value.hoursMinutesFormatted` 비교로 변경 | 포맷 로케일 차이 반영 |
| `DUNETests/InjuryViewModelTests.swift` | 4개 validation error assertion을 `String(localized: ...)` exact match로 변경 | 다국어 환경에서도 동일 의도 검증 |
| `DUNETests/LifeViewModelTests.swift` | 빈 이름 에러 assertion을 `String(localized: ...)` 비교로 변경 | 영문 substring 의존 제거 |

### Key Code

```swift
#expect(vm.validationError == String(localized: "Start date cannot be in the future"))
#expect(sleep.formattedValue == sleep.value.hoursMinutesFormatted)
```

## Prevention

### Checklist Addition

- [ ] 사용자 노출 에러 메시지 테스트는 영문 substring 검색 대신 `String(localized:)` 또는 로케일 독립 기준을 사용한다.
- [ ] 포맷 문자열 테스트는 특정 언어 표기(`m`, `min` 등) 고정값을 피하고 포맷 함수 기준으로 검증한다.

### Rule Addition (if applicable)

현재는 solution 문서로 패턴을 축적하고, 동일 유형이 반복되면 `.claude/rules/testing-required.md`에 승격한다.

## Lessons Learned

문자열 기반 테스트는 기능 로직보다 로케일에 먼저 깨질 수 있다. 포맷/검증 메시지를 테스트할 때는 로케일 독립 assertion을 우선해야 CI와 로컬 환경 간 편차를 줄일 수 있다.
