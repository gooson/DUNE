---
tags: [habit, lifestyle, tab, swiftdata, streak]
date: 2026-02-28
category: plan
status: draft
---

# Plan: Life Tab — 습관 형성 라이프스타일 탭

## Overview

4번째 탭 "Life"를 추가하여 사용자가 일상 습관(체크형/시간형/횟수형)을 추적하고, 연속 달성(streak)을 시각화하며, 운동은 기존 ExerciseRecord에서 자동 연동하는 기능을 구현한다.

## Affected Files

### 신규 생성 (14개)

| File | Layer | Purpose |
|------|-------|---------|
| `Data/Persistence/Models/HabitDefinition.swift` | Data | @Model — 습관 정의 |
| `Data/Persistence/Models/HabitLog.swift` | Data | @Model — 일별 습관 기록 |
| `Domain/Models/HabitType.swift` | Domain | 습관 유형 enum (check/duration/count) |
| `Domain/Models/HabitFrequency.swift` | Domain | 습관 빈도 enum (daily/weekly) |
| `Domain/UseCases/HabitStreakService.swift` | Domain | 연속 달성일 계산 |
| `Presentation/Life/LifeView.swift` | Presentation | 탭 root view |
| `Presentation/Life/LifeViewModel.swift` | Presentation | 습관 CRUD + streak |
| `Presentation/Life/HabitRowView.swift` | Presentation | 습관 row (3종류 유형별) |
| `Presentation/Life/HabitFormSheet.swift` | Presentation | 습관 추가/편집 폼 |
| `Presentation/Shared/Extensions/HabitType+View.swift` | Presentation | 유형별 아이콘/이름 |
| `Resources/Assets.xcassets/Colors/TabLife.colorset/Contents.json` | Resources | 탭 웨이브 색상 |
| `DUNETests/HabitStreakServiceTests.swift` | Tests | streak 계산 테스트 |
| `DUNETests/LifeViewModelTests.swift` | Tests | ViewModel CRUD 테스트 |
| `DUNETests/HabitTypeTests.swift` | Tests | Domain enum 테스트 |

### 기존 수정 (5개)

| File | Change |
|------|--------|
| `App/AppSection.swift` | `.life` case 추가 |
| `App/ContentView.swift` | 4번째 Tab 등록 + scrollToTop signal |
| `App/DUNEApp.swift` | ModelContainer에 HabitDefinition, HabitLog 추가 |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | V6 스키마 + migration |
| `Presentation/Shared/Components/WavePreset.swift` | `.life` case 추가 |
| `Presentation/Shared/DesignSystem.swift` | `DS.Color.tabLife` 토큰 추가 |

## Implementation Steps

### Step 1: Domain 모델 (Domain Layer)

**HabitType.swift**
```swift
enum HabitType: String, Sendable, CaseIterable {
    case check     // 했다/안했다
    case duration  // 몇 분
    case count     // 몇 회
}

enum HabitFrequency: Sendable {
    case daily
    case weekly(targetDays: Int) // 주 N회
}
```

**HabitStreakService.swift**
- `static func calculateStreak(completedDates: [Date], frequency: HabitFrequency, from referenceDate: Date) -> Int`
- daily: 연속 달성일 카운트 (오늘부터 역방향)
- weekly: 연속 달성 주 카운트 (현재 주부터 역방향)

### Step 2: Data 모델 (SwiftData)

**HabitDefinition.swift** — @Model
- id, name, iconName, colorName
- habitTypeRaw (String), goalValue (Double), goalUnit (String?)
- frequencyTypeRaw (String), weeklyTargetDays (Int)
- isAutoLinked (Bool), autoLinkSourceRaw (String?)
- sortOrder (Int), isArchived (Bool), createdAt
- @Relationship → logs: [HabitLog]? = [] (Correction #32)
- Computed: habitType, frequency, icon/color accessors

**HabitLog.swift** — @Model
- id, date (Calendar.startOfDay), value (Double)
- isAutoCompleted (Bool), completedAt (Date?), memo (String?)
- habitDefinition: HabitDefinition? (inverse)

### Step 3: Schema Migration

**AppSchemaVersions.swift**
- AppSchemaV6: all V5 models + HabitDefinition + HabitLog
- migrateV5toV6: lightweight
- AppMigrationPlan: add V6 schema + stage

**DUNEApp.swift**
- ModelContainer(for:) 양쪽 path에 HabitDefinition.self, HabitLog.self 추가

### Step 4: Tab Infrastructure

**AppSection.swift** — `.life` case
- title: "Life", icon: "checklist"

**WavePreset.swift** — `.life` case
- amplitude: 0.04, frequency: 1.4, opacity: 0.12 (차분한 느낌)

**DS.Color** — `tabLife` 토큰
- TabLife.colorset: Desert Amber 계열 (기존 TabTrain=Coral, TabWellness=Teal과 구분)

**ContentView.swift**
- @State lifeScrollToTopSignal
- 4번째 Tab 등록
- tabSelection switch에 .life case 추가

### Step 5: ViewModel

**LifeViewModel.swift**
- @Observable @MainActor, import Observation (NOT SwiftUI)
- Form fields: name, selectedIcon, selectedType, goalValue, goalUnit, frequencyType, weeklyTargetDays, isAutoLinked
- CRUD: createValidatedHabit() -> HabitDefinition?, createValidatedLog() -> HabitLog?
- didFinishSaving(), resetForm(), startEditing()
- isSaving guard, validationError
- calculateProgress(habits:, logs:, exerciseRecords:) → [HabitProgress]
- today 운동 자동 연동 로직

### Step 6: Views

**LifeView.swift**
- ScrollView + TabWaveBackground + waveRefreshable
- Hero: 오늘 달성률 (N/M 완료)
- HabitListQueryView (isolated @Query child, Correction #179)
- + 버튼으로 HabitFormSheet
- navigationDestination for detail (Future)

**HabitRowView.swift**
- 체크형: 탭으로 토글 (원형 체크 아이콘)
- 시간형: 진행 바 + 값 입력
- 횟수형: +/- 스테퍼 + 진행 바
- streak 배지

**HabitFormSheet.swift**
- NavigationStack > Form + SheetWaveBackground
- 이름, 유형 선택, 목표값, 빈도(매일/주N회), 자동연동 토글
- 아이콘 선택 (카테고리별 고정 SF Symbol 그리드)

**HabitType+View.swift**
- displayName, iconName, themeColor (Correction #93: no default)

### Step 7: Unit Tests

**HabitStreakServiceTests.swift**
- 연속 3일 달성 → streak 3
- 1일 빠짐 → streak 0 (또는 빠진 이후부터 카운트)
- 주간 목표: 주 3회, 이번 주 3회 달성 → streak 1주
- 빈 데이터 → streak 0
- 중복 날짜 dedup
- 과거 날짜 소급 체크 반영

**LifeViewModelTests.swift**
- createValidatedHabit: 정상 생성
- createValidatedHabit: 빈 이름 → validationError
- createValidatedHabit: isSaving 중복 방지
- didFinishSaving: isSaving 리셋
- resetForm: 모든 필드 초기화
- goalValue 범위 검증 (0 이하, 음수)

**HabitTypeTests.swift**
- rawValue round-trip
- CaseIterable 전체 케이스 확인

## Key Corrections Applied

- #2: ViewModel에 ModelContext 전달 금지
- #7: ViewModel에 import SwiftUI 금지
- #32: @Relationship Optional 필수
- #39: 반환값 함수에서 defer 금지 (createValidatedHabit)
- #43: isSaving 리셋은 View에서 insert 완료 후
- #48: navigationDestination 조건 블록 밖 배치
- #93: switch에 default 금지
- #119: xcassets 색상은 Colors/ 하위
- #132: Void async에서 defer 사용 (loadData)
- #145: WavePreset case는 consumer와 동시 추가
- #146: 새 View에 웨이브 배경 적용
- #164: Codable rawValue에 CodingKeys + WARNING
- #177: DS 색상은 xcassets 패턴
- #179: LazyVGrid + @Query 동일 View 금지
- #181: ScrollView에 scrollBounceBehavior

## Verification

1. `scripts/build-ios.sh` 빌드 통과
2. `xcodebuild test -scheme DUNETests` 테스트 통과
3. 새 @Model 2회 실행 테스트 (Correction #33)
