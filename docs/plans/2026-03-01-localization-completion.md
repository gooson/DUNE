---
tags: [localization, xcstrings, i18n]
date: 2026-03-01
category: plan
status: approved
---

# Plan: Localization 미적용 텍스트 전수 수정

## Summary

displayName 프로퍼티에 `String(localized:)` 래핑 누락 수정 + xcstrings에 누락된 ko/ja 번역 232건 추가.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Presentation/Shared/Extensions/Equipment+View.swift` | 코드 수정 | TRX → String(localized:) |
| `DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | 코드 수정 | HIIT → String(localized:) |
| `DUNE/Presentation/Shared/Extensions/HealthMetric+View.swift` | 코드 수정 | BMI, VO2 Max → String(localized:) |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | 코드 수정 | Desert Warm, Ocean Cool → String(localized:) |
| `DUNE/Presentation/Shared/Extensions/VolumePeriod+View.swift` | 코드 수정 | 1W, 1M, 3M, 6M → String(localized:) |
| `DUNE/Resources/Localizable.xcstrings` | 번역 추가 | 232건 ko/ja 번역 |

## Implementation Steps

### Step 1: displayName String(localized:) 래핑 (5개 파일)

### Step 2: xcstrings 누락 번역 추가
- 일반 문자열 184건 + 포맷 문자열 48건
- 단위/약어 (kg, min, kcal, PR, 1RM 등)는 번역 불필요 → en과 동일값

### Step 3: 빌드 검증

## 영어 유지 항목 (번역 안 함)

- AppSection 탭 타이틀: Today, Activity, Wellness, Life
- 운동 이름: Bench Press, Squat 등
