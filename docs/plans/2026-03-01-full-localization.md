---
tags: [localization, i18n, xcstrings, string-catalog]
date: 2026-03-01
category: plan
status: approved
---

# Plan: 전체 앱 다국어 지원 (String Catalogs)

## Approach

- **도구**: Xcode String Catalogs (`.xcstrings`)
- **키 전략**: 영어 텍스트를 키로 사용 (not structured keys)
- **Base Language**: English (en)
- **번역 언어**: Korean (ko), Japanese (ja)

## Key Decisions

1. `displayName` → `String(localized: "English text")`로 변환
2. `localizedDisplayName` 제거 → `displayName`이 locale에 따라 자동 반환
3. `bilingualDisplayName` 제거 → 순수 localized `displayName`으로 대체
4. `localizedSeverityDescription` → `severityDescription`으로 rename + `String(localized:)`
5. `equipmentDescription` → `String(localized: "English description")`
6. validation errors → `String(localized: "...")`로 래핑
7. SwiftUI `Text("...")` → 코드 변경 불필요 (자동 LocalizedStringKey)

## Affected Files

### Infrastructure (생성/수정)
| File | Action |
|------|--------|
| `DUNE/Resources/Localizable.xcstrings` | **Create** |
| `DUNEWatch/Resources/Localizable.xcstrings` | **Create** |
| `DUNE/project.yml` | **Modify** (developmentLanguage) |
| `.claude/rules/localization.md` | **Modify** (키 전략 업데이트) |

### Enum Extension Files (displayName → String(localized:))
| File | Changes |
|------|---------|
| `ExerciseCategory.swift` | displayName → String(localized:) |
| `MuscleGroup+View.swift` | displayName → String(localized:), remove localizedDisplayName |
| `BodyPart+View.swift` | displayName → String(localized:), remove localizedDisplayName/bilingualDisplayName |
| `Equipment+View.swift` | displayName/equipmentDescription → String(localized:), remove localizedDisplayName |
| `InjurySeverity+View.swift` | displayName → String(localized:), remove bilingual/localizedSeverityDescription |
| `ExerciseCategory+View.swift` | SetType.displayName → String(localized:) |
| `FatigueLevel+View.swift` | Korean displayName → English key + String(localized:) |
| `HabitType+View.swift` | displayName/description → String(localized:) |
| `SleepStage+View.swift` | label → String(localized:) |
| `TrainingReadiness+View.swift` | label/guideMessage → String(localized:) |
| `VolumePeriod+View.swift` | displayName → String(localized:) |
| `WeatherConditionType+View.swift` | Korean label → English key + String(localized:) |
| `WellnessScore+View.swift` | label → String(localized:) |
| `WorkoutActivityType+View.swift` | Korean displayName → English key + String(localized:) |
| `WorkoutIntensity+View.swift` | displayName → String(localized:) |
| `HealthMetric+View.swift` | displayName/unitLabel → String(localized:) |
| `CompoundWorkoutMode+View.swift` | displayName → String(localized:) |

### Caller Updates (localizedDisplayName → displayName)
| File | Changes |
|------|---------|
| `ExercisePickerView.swift` | .localizedDisplayName → .displayName (4곳) |
| `ExerciseDetailSheet.swift` | .localizedDisplayName → .displayName (2곳) |
| `WorkoutRecommendationCard.swift` | .localizedDisplayName → .displayName (1곳) |
| `MuscleDetailPopover.swift` | .localizedDisplayName → .displayName (1곳) |
| `InjuryCardView.swift` | .localizedDisplayName/.bilingualDisplayName → .displayName (2곳) |
| `InjuryFormSheet.swift` | .bilingualDisplayName/.localizedSeverityDescription → .displayName/.severityDescription (5곳) |
| `InjuryWarningBanner.swift` | .bilingualDisplayName → .displayName (1곳) |
| `InjuryHistoryView.swift` | .bilingualDisplayName/.localizedSeverityDescription → .displayName/.severityDescription (6곳) |

### Validation Error VMs (String → String(localized:))
| File | Count |
|------|-------|
| `BodyCompositionViewModel.swift` | 5곳 |
| `WorkoutSessionViewModel.swift` | 9곳 |
| `CreateCustomExerciseView.swift` | 3곳 |
| `CreateTemplateView.swift` | 3곳 |
| `CompoundWorkoutViewModel.swift` | 1곳 |
| `LifeViewModel.swift` | 6곳 |
| `InjuryViewModel.swift` | 4곳 |
| `WellnessView.swift` | 1곳 |
| `BodyHistoryDetailView.swift` | 1곳 |

## Implementation Steps

1. Update project.yml (developmentLanguage: en)
2. Create iOS Localizable.xcstrings (en/ko/ja 전체 번역)
3. Create watchOS Localizable.xcstrings (공유 enum + Watch UI)
4. Modify enum extension files (String(localized:) 적용)
5. Update localizedDisplayName/bilingualDisplayName callers
6. Wrap validation errors in String(localized:)
7. Update localization rules
8. Build verification
