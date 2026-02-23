---
tags: [activity-tab, personal-records, healthkit, cardio, performance, weather-context]
category: general
date: 2026-02-24
severity: important
related_files:
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - Dailve/Presentation/Activity/Components/PersonalRecordsSection.swift
  - Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift
  - Dailve/Domain/UseCases/ActivityPersonalRecordService.swift
  - Dailve/Domain/Models/ActivityPersonalRecord.swift
related_solutions:
  - docs/solutions/performance/2026-02-16-review-triage-task-cancellation-and-caching.md
  - docs/solutions/general/2026-02-19-review-p1-p2-training-volume-fixes.md
---

# Solution: Activity PR 통합 후 리뷰 이슈(시드 로딩/날씨 컨텍스트) 수정

## Problem

Activity 탭에 근력+유산소 PR 통합 기능을 추가한 뒤, 리뷰 단계에서 성능과 데이터 노출 완성도 이슈가 확인되었다.

### Symptoms

- Activity 최초 로딩 시 카드용 PR 시드(HealthKit 장기 이력 10년) 조회가 동기 흐름에 묶여 초기 화면 표시가 지연될 수 있음
- PR 카드의 보조 정보에 날씨/실내외 정책을 반영했지만, 실제 카드 텍스트에서 날씨 조건/습도가 누락되어 정보가 불완전함

### Root Cause

- `loadActivityData()`에서 시드 fetch를 `await`로 직접 대기하여 초기 렌더 단계와 결합됨
- PR 카드/디테일의 `contextText`가 온도와 실내외만 표시하도록 제한되어 정책 범위(날씨 조건, 습도) 전체를 반영하지 못함

## Solution

장기 이력 시드를 백그라운드 태스크로 분리해 초기 로딩 경로를 가볍게 만들고, PR 컨텍스트에 날씨 조건/습도 텍스트를 추가해 정책 범위를 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Dailve/Presentation/Activity/ActivityViewModel.swift` | 시드 로직을 `triggerCardioPersonalRecordSeedIfNeeded()` 비동기 태스크로 분리하고, 초기 로딩에서 non-blocking으로 호출 | Activity 초기 로딩 지연 방지 |
| `Dailve/Presentation/Activity/Components/PersonalRecordsSection.swift` | 컨텍스트 텍스트에 날씨 조건/온도/습도/실내외를 조합 표시하도록 확장 | HealthKit 컨텍스트 정책 누락 해소 |
| `Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | 디테일 카드에도 동일한 날씨 컨텍스트 규칙 적용 | 목록/디테일 간 정보 일관성 유지 |

### Key Code

```swift
// ActivityViewModel
refreshCardioPersonalRecords(with: workoutsResult)
triggerCardioPersonalRecordSeedIfNeeded() // non-blocking seed
```

```swift
// PR context
if let condition = record.weatherCondition {
    weatherParts.append(weatherConditionLabel(for: condition))
}
if let humidity = record.weatherHumidity, humidity.isFinite, humidity >= 0 {
    weatherParts.append("습도 \(Int(humidity).formattedWithSeparator)%")
}
```

## Prevention

### Checklist Addition

- [ ] 초기 화면 로딩 경로에서 장기 히스토리/대용량 fetch를 직접 `await`하지 않는다.
- [ ] 정책 문서에 포함된 HealthKit 필드는 카드/디테일 모두 동일하게 노출되는지 확인한다.
- [ ] Activity PR 변경 시 섹션 카드와 디테일 카드 컨텍스트가 동일 규칙을 쓰는지 확인한다.

### Rule Addition (if applicable)

새 rule 파일 추가 없이, 코드 리뷰 체크리스트에 위 3개 항목을 반영한다.

## Lessons Learned

- "한 번만 실행"되는 시드 로직도 초기 로딩 체인에 묶이면 체감 성능 문제를 만들 수 있다.
- 기능 범위 합의(날씨/실내외 포함)는 저장뿐 아니라 표시 계층까지 끝까지 관통되어야 한다.
