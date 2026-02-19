---
topic: unified-workout-row-redesign
date: 2026-02-19
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-19-dry-extraction-shared-components
  - architecture/2026-02-17-activity-tab-review-patterns
  - general/2026-02-17-exercise-visual-guide
related_brainstorms:
  - 2026-02-19-unified-workout-row-redesign
---

# Implementation Plan: Train/Exercise 통합 워크아웃 Row 리디자인

## Context

Train 탭(Recent Workouts)과 Exercise 탭 사이에 타이틀, 아이콘, 색상, 정렬, 상세 화면 헤더의 5가지 UI 괴리가 존재한다. 두 화면에서 같은 운동이 다르게 보이는 것은 사용자 혼란을 유발한다. 공통 컴포넌트를 만들어 일관성을 확보하고, legacy 코드를 제거한다.

## Requirements

### Functional

- 같은 운동이 Train 탭과 Exercise 탭에서 **동일한 타이틀, 아이콘, 색상**으로 표시
- Train 탭의 Recent Workouts가 **날짜순 통합 정렬** (수동/HK 구분 없이)
- 수동 기록에도 **카테고리 아이콘+색상** 적용 (현재: 항상 초록 or 없음)
- 수동 기록 타이틀이 모든 화면에서 **한국어 localizedType 우선**
- ExerciseSessionDetailView 헤더에 **아이콘+카테고리 색상+한국어 제목** 추가

### Non-functional

- 공통 컴포넌트 1곳 수정 → 양쪽 반영 (DRY)
- DS 토큰 일관 사용 (하드코딩 spacing 제거)
- legacy `WorkoutSummary.iconName(for:)` 완전 제거
- 기존 `ExerciseListItem` 모델 재활용 (새 모델 불필요)

## Approach

**기존 `ExerciseListItem`을 공통 데이터 소스로 채택**하고, 새 `UnifiedWorkoutRow` View를 만들어 양쪽에서 사용한다.

핵심 설계 결정:
1. `ExerciseListItem` 생성 시 수동 기록에도 `WorkoutActivityType`을 매핑 (현재는 항상 `.other`)
2. 매핑 경로: `exerciseDefinitionID` → `ExerciseLibraryService` → `ExerciseDefinition.category` → `ExerciseCategory.hkWorkoutActivityType` → `WorkoutActivityType`
3. Row는 `.compact` (Train)와 `.full` (Exercise) 두 스타일 제공
4. Train 탭의 `ExerciseListSection`이 `ExerciseListItem` 배열을 받도록 변경

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A. 새 WorkoutRowItem 프로토콜 | 깔끔한 추상화 | 기존 ExerciseListItem과 중복, 변환 비용 | **기각** — 이미 적합한 모델 존재 |
| B. ExerciseListItem 재활용 + UnifiedWorkoutRow | 최소 변경, 검증된 모델 | ExerciseListItem에 약간의 프로퍼티 추가 필요 | **채택** |
| C. Train 탭만 패치 (최소 수정) | 빠름 | 근본 문제(이중 코드) 미해결 | **기각** — 미래 유지보수 비용 증가 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Shared/Components/UnifiedWorkoutRow.swift` | **신규** | 공통 워크아웃 Row 컴포넌트 |
| `Presentation/Exercise/ExerciseViewModel.swift` | **수정** | 수동 기록의 activityType 매핑 추가 |
| `Presentation/Activity/Components/ExerciseListSection.swift` | **수정** | ExerciseListItem 기반으로 전환, 통합 정렬 |
| `Presentation/Activity/ActivityView.swift` | **수정** | ExerciseListSection에 ExerciseListItem 전달 |
| `Presentation/Activity/ActivityViewModel.swift` | **수정** | ExerciseListItem 빌드 로직 추가 (또는 ExerciseViewModel 재사용) |
| `Presentation/Exercise/ExerciseView.swift` | **수정** | ExerciseRowView → UnifiedWorkoutRow 교체 |
| `Presentation/Exercise/ExerciseSessionDetailView.swift` | **수정** | 헤더에 아이콘+카테고리 색상+한국어 제목 추가 |
| `Domain/Models/ExerciseDefinition.swift` | **수정** | `resolvedActivityType` computed property 추가 |
| `Domain/Models/HealthMetric.swift` | **수정** | `WorkoutSummary.iconName(for:)` 삭제 |
| `Presentation/Shared/Extensions/ExerciseCategory+View.swift` | **수정** | activityType 매핑 헬퍼 추가 (또는 기존 +HealthKit 활용) |
| `Dailve/project.yml` | 확인 | 새 파일 등록 (xcodegen) |

## Implementation Steps

### Step 1: ExerciseDefinition → WorkoutActivityType 매핑 추가

- **Files**: `Domain/Models/ExerciseDefinition.swift`, `Presentation/Shared/Extensions/ExerciseCategory+View.swift`
- **Changes**:
  - `ExerciseDefinition`에 `var resolvedActivityType: WorkoutActivityType` computed property 추가
  - 매핑 로직: `ExerciseCategory` → `WorkoutActivityType` (Data 레이어의 `ExerciseCategory+HealthKit.swift` 패턴 참고하되 Presentation에서 HealthKit import 없이 직접 매핑)
  - name 기반 세분화: "running" → `.running`, "cycling" → `.cycling` 등 (기존 `hkActivityType(category:exerciseName:)` 로직 참고)
- **Verification**: ExerciseDefinition의 각 카테고리별 매핑 결과를 단위 테스트로 검증

**매핑 테이블:**

| ExerciseCategory | 기본 WorkoutActivityType | name 키워드 세분화 |
|--|--|--|
| `.strength` | `.traditionalStrengthTraining` | — |
| `.cardio` | `.other` | run→`.running`, walk→`.walking`, bike/cycle→`.cycling`, swim→`.swimming`, row→`.rowing`, elliptical→`.elliptical`, stair→`.stairStepper`, hike→`.hiking` |
| `.hiit` | `.highIntensityIntervalTraining` | — |
| `.flexibility` | `.flexibility` | yoga→`.yoga`, pilates→`.pilates` |
| `.bodyweight` | `.functionalStrengthTraining` | — |

### Step 2: ExerciseViewModel에서 수동 기록 activityType 매핑

- **Files**: `Presentation/Exercise/ExerciseViewModel.swift`
- **Changes**:
  - `invalidateCache()`의 수동 기록 빌드 블록에서:
    ```swift
    let definition = record.exerciseDefinitionID.flatMap { exerciseLibrary.exercise(byID: $0) }
    let activityType = definition?.resolvedActivityType
        ?? WorkoutActivityType.infer(from: record.exerciseType)  // fallback: name 키워드 매칭
        ?? .other
    ```
  - `ExerciseListItem` 생성 시 `activityType: activityType` 전달 (현재 기본값 `.other` 대신)
- **Verification**: 빌드 후 Exercise 탭에서 수동 기록에 아이콘이 표시되는지 확인

### Step 3: UnifiedWorkoutRow 공통 컴포넌트 생성

- **Files**: `Presentation/Shared/Components/UnifiedWorkoutRow.swift` (신규)
- **Changes**:
  - `ExerciseListItem`을 데이터 소스로 받는 View
  - 두 스타일 variant:
    - `.compact`: Train 대시보드용 — InlineCard 래핑, 아이콘 28pt, 날짜 weekday+time, 근육 뱃지, duration+kcal
    - `.full`: Exercise 탭용 — plain row, 아이콘 32pt, 날짜 date, HR/pace/elevation, set summary, badges
  - 공통 요소: 아이콘(activityType.iconName + color), 타이틀(localizedType ?? activityType.displayName), PR highlight
  - DS 토큰 일관 사용 (하드코딩 spacing 제거)
- **Verification**: SwiftUI Preview로 양쪽 스타일 확인

**타이틀 우선순위:**
1. `item.localizedType` (exercise library 한국어명) — 수동 기록 전용
2. `item.activityType.displayName` (WorkoutActivityType 한국어명) — HealthKit + fallback
3. `item.type` (raw string) — 최종 fallback

### Step 4: Exercise 탭에 UnifiedWorkoutRow 적용

- **Files**: `Presentation/Exercise/ExerciseView.swift`
- **Changes**:
  - `ExerciseRowView` private struct 삭제
  - `ForEach` 내부에서 `UnifiedWorkoutRow(item: item, style: .full)` 사용
  - NavigationLink 목적지 로직 유지 (source별 분기)
- **Verification**: Exercise 탭에서 기존과 동일한 정보가 새 Row로 표시되는지 확인

### Step 5: Train 탭에 ExerciseListItem + UnifiedWorkoutRow 적용

- **Files**: `Presentation/Activity/Components/ExerciseListSection.swift`, `Presentation/Activity/ActivityView.swift`, `Presentation/Activity/ActivityViewModel.swift`
- **Changes**:
  - `ActivityViewModel`에 `ExerciseListItem` 빌드 로직 추가:
    - `ExerciseViewModel.invalidateCache()`의 병합+정렬 로직을 재사용 가능하도록 static 함수로 추출하거나, ActivityView에서도 ExerciseViewModel을 사용
    - **선호 접근**: 병합 로직을 `ExerciseListItemBuilder` static helper로 추출 → 양쪽 VM에서 호출
  - `ExerciseListSection`의 파라미터를 `items: [ExerciseListItem]` + `limit: Int`로 변경
  - 내부의 `setRecordRow()`, `workoutRow()` 삭제 → `UnifiedWorkoutRow(item:style:.compact)` 사용
  - NavigationLink 목적지: `item.source`에 따라 분기 유지
- **Verification**: Train 탭에서 날짜순 통합 정렬 + 새 Row 표시 확인

### Step 6: ExerciseSessionDetailView 헤더 개선

- **Files**: `Presentation/Exercise/ExerciseSessionDetailView.swift`
- **Changes**:
  - `navigationTitle`을 `localizedType ?? activityType.displayName`으로 변경
  - `sessionHeader`에 아이콘 추가:
    ```swift
    HStack(spacing: DS.Spacing.md) {
        Image(systemName: activityType.iconName)
            .font(.title)
            .foregroundStyle(activityType.color)
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(displayName).font(.title2.weight(.semibold))
            Text(record.date, style: .date).font(.subheadline).foregroundStyle(.secondary)
            Text(record.date, style: .time).font(.caption).foregroundStyle(.tertiary)
        }
    }
    ```
  - `ExerciseSessionDetailView` init에 `activityType: WorkoutActivityType`과 `displayName: String` 파라미터 추가 (caller가 ExerciseListItem에서 전달)
- **Verification**: 수동 기록 상세 화면에서 아이콘+한국어 제목 표시 확인

### Step 7: Legacy 코드 제거

- **Files**: `Domain/Models/HealthMetric.swift`
- **Changes**:
  - `WorkoutSummary.iconName(for:)` static 함수 삭제
  - 모든 참조 검색 → 이미 Step 5에서 대체 완료 확인
- **Verification**: 빌드 성공, 경고 0

### Step 8: xcodegen + 빌드 + 테스트

- **Files**: `Dailve/project.yml`
- **Changes**:
  - `cd Dailve && xcodegen generate`
  - 전체 빌드 확인
  - 기존 테스트 통과 확인
  - Step 1의 매핑 테스트 추가
- **Verification**: `xcodebuild test` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| `exerciseDefinitionID` nil (legacy 기록) | name 키워드 매칭 fallback → 최종 `.other` |
| 운동명이 어떤 키워드에도 안 맞음 | `.other` + `"figure.mixed.cardio"` 아이콘, 회색 |
| HealthKit 권한 거부 (HK 데이터 없음) | 수동 기록만 표시 — UnifiedWorkoutRow가 source 무관하게 동작 |
| 최근 운동 0건 | 기존 empty state 유지 (`"No recent workouts"`) |
| iPad sizeClass 전환 | InlineCard의 기존 adaptive 패딩 활용 |
| ExerciseSessionDetailView에 activityType 전달 불가 (deep link 등) | `.other` 기본값 + record.exerciseType fallback |

## Testing Strategy

- **Unit tests**:
  - `ExerciseDefinitionTests`: 각 카테고리+name 조합의 `resolvedActivityType` 검증
  - `WorkoutActivityType.infer(from:)`: name 키워드 매칭 경계값 테스트 (대소문자, 부분 매칭, 미매칭)
  - `ExerciseListItemBuilder`: 병합+정렬+dedup 로직 (기존 ExerciseViewModel 테스트 확장)
- **Manual verification**:
  - Train 탭: 수동/HK 기록이 날짜순 통합 정렬
  - Train 탭: 수동 기록에 카테고리 아이콘+색상 표시
  - Exercise 탭: 기존과 동일한 정보가 새 Row로 표시
  - 수동 기록 상세: 아이콘+한국어 제목 헤더
  - HK 기록 상세: 기존과 변화 없음

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ExerciseListItem 빌드 로직 이중화 (ActivityVM + ExerciseVM) | 중 | 중 | static helper 추출로 코드 공유 |
| 수동 기록 activityType 매핑 정확도 | 저 | 저 | fallback `.other` 존재, 점진적 매핑 테이블 확장 가능 |
| Train 탭 성능 (ExerciseListItem 빌드 추가) | 저 | 저 | limit=5로 소량만 빌드, 기존 ExerciseVM과 동일 패턴 |
| ExerciseSessionDetailView init 변경 → caller 수정 필요 | 저 | 저 | 기본값 제공으로 backward compatible |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 `ExerciseListItem` 모델과 `WorkoutActivityType+View.swift` 인프라가 이미 충분히 성숙. 새로 만드는 것은 `UnifiedWorkoutRow` View와 매핑 헬퍼뿐. 데이터 모델/스키마 변경 없음 (SwiftData/CloudKit 영향 없음). 기존 패턴(DRY 추출, DS 토큰)을 따르므로 위험 낮음.
