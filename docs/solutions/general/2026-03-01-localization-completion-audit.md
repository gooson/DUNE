---
tags: [localization, xcstrings, i18n, audit, String-localized]
date: 2026-03-01
category: solution
status: implemented
---

# Localization 전수 조사 및 완료

## Problem

xcstrings 인프라가 구축되어 있었지만 일부 displayName 프로퍼티에 `String(localized:)` 래핑이 누락, xcstrings에 ko/ja 번역이 빠진 키가 232건 존재.

## Solution

### 1. displayName `String(localized:)` 래핑 (9개 파일, 21개 문자열)

**Presentation 레이어 (5개 파일)**:
- `Equipment+View.swift`: TRX
- `WorkoutActivityType+View.swift`: HIIT
- `HealthMetric+View.swift`: BMI, VO2 Max
- `AppTheme+View.swift`: Desert Warm, Ocean Cool
- `VolumePeriod+View.swift`: 1W, 1M, 3M, 6M

**Domain 레이어 (4개 파일)** — Foundation의 `String(localized:)` 사용 가능:
- `ConditionScore.swift`: Status.label (5) + Status.guideMessage (5)
- `WellnessScore.swift`: message(for:) (5)
- `WorkoutActivityType.swift`: MilestoneDistance.label (4)
- `WeightUnit.swift`: displayName (2)

### 2. xcstrings 번역 추가 (232건 → 0건 누락)

Python 스크립트로 xcstrings JSON을 직접 수정하여 일괄 추가.

### 3. 영어 유지 항목

- AppSection 탭 타이틀: `title: String` 반환 → `Tab(section.title, ...)` → StringProtocol 오버로드 → 자동 localization 안 됨
- 운동 이름: 국제 피트니스 표준 영어 유지

### 4. Enum rawValue → displayName 전환 (6개 enum, 27파일)

기존 `String` rawValue를 Picker/Chart에서 `Text(enum.rawValue)`로 사용하던 패턴을 제거하고, `displayName` computed property + static dictionary 캐싱 패턴으로 교체.

- `ProgressMetric` (ExerciseHistoryViewModel)
- `DailyVolumeChartView.Metric`
- `WeeklySummaryChartView.Tab`
- `TimePeriod` (Presentation extension)
- `ScoreContribution.Factor`
- `SleepStage.Stage`

### 5. Helper 함수 String → LocalizedStringKey (13개 함수)

`sectionHeader(title: String)` 등에서 `Text(title)`이 `StringProtocol` init을 타서 번역이 안 되는 패턴을 `LocalizedStringKey` 파라미터로 수정.

### 6. Orphan 키 정리 + Unicode 불일치 수정

- 4개 orphan 키 삭제: "Coming Soon", "Coarse Dust", "Fine Dust", "Ozone"
- Smart quote U+2019 → ASCII U+0027 키 불일치 수정

### 7. displayName static dictionary 캐싱

리뷰에서 발견: `ForEach` 내부에서 `String(localized:)` computed property가 매 렌더마다 호출되는 문제 → `private static let displayNames: [Enum: String]` 패턴으로 1회 할당.

## Prevention

### 새 문자열 추가 시 체크리스트

1. `displayName`, `label`, `guideMessage` 등 사용자 노출 computed property는 `String(localized:)` 필수
2. 약어(BMI, HIIT, TRX 등)도 `String(localized:)` 래핑 (localization.md 규칙)
3. xcstrings에 ko/ja 번역 동시 추가 (3개 언어 필수)
4. SwiftUI 자동 LocalizedStringKey (Text, Button, navigationTitle) → 코드 변경 불필요, xcstrings만 추가

### 누락 탐지 방법

```bash
# xcstrings에서 번역 누락 키 찾기
python3 -c "
import json
with open('DUNE/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)
for key, val in data['strings'].items():
    locs = val.get('localizations', {})
    if key and ('ko' not in locs or 'ja' not in locs):
        print(f'Missing: {key}')
"
```
