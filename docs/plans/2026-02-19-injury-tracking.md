---
topic: injury-tracking
date: 2026-02-19
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-17-cloudkit-optional-relationship.md
  - architecture/2026-02-15-domain-layer-purity.md
  - security/2026-02-16-defensive-coding-patterns.md
related_brainstorms:
  - 2026-02-19-injury-tracking.md
---

# Implementation Plan: 부상 상태 기록 및 트레인 연동

## Context

사용자가 부상(발목 염좌, 허리 통증 등)을 체계적으로 기록/관리하고, Train 탭에서 부상 부위와 충돌하는 운동 시 경고를 받을 수 있도록 한다. Wellness 탭에 바디맵 시각화 + 카드 리스트 UI를 추가하고, 부상 통계 및 운동량 비교 기능도 포함한다.

## Requirements

### Functional

- F1: Wellness 탭에서 부상 생성/수정/종료/삭제 (CRUD)
- F2: 활성 부상을 바디맵(불스아이 마커) + 카드 리스트로 시각화
- F3: 부상 히스토리 (종료된 부상) 조회
- F4: Train 탭에서 활성 부상 부위와 충돌하는 운동 시 severity별 경고 배너
- F5: MuscleRecoveryMapView에 부상 오버레이
- F6: 부상 통계 (부위별 빈도, 평균 회복 기간)
- F7: 부상 기간 중 운동량 자동 비교 (전/중/후)

### Non-functional

- NF1: CloudKit sync 호환 (모든 relationship Optional, 스키마 V5)
- NF2: Domain 레이어에 SwiftUI/SwiftData import 금지
- NF3: ViewModel에 ModelContext 전달 금지
- NF4: 입력 검증: startDate <= today, endDate > startDate, memo <= 500자
- NF5: 삭제 시 확인 다이얼로그 필수 (CloudKit 전파)

## Approach

12개 MVP 항목을 7단계로 그룹화하여 bottom-up 구현. 각 단계는 독립 빌드/검증 가능.

1. **Domain 모델** (BodyPart, BodySide, InjurySeverity, InjuryInfo DTO, CheckInjuryConflictUseCase, InjuryStatisticsService)
2. **Data 레이어** (InjuryRecord, 스키마 V5)
3. **ViewModel** (InjuryViewModel — CRUD + validation + 통계)
4. **Wellness UI** (카드 리스트 섹션 + 추가/수정 Sheet + 히스토리)
5. **바디맵** (관절 좌표 데이터 + JointMarkerView + MuscleRecoveryMapView 오버레이)
6. **Train 연동** (ActivityViewModel에 부상 충돌 경고 + 바디맵 오버레이)
7. **통계/비교** (부상 통계 카드 + 운동량 비교 뷰)

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| InjuryRecord에 affectedMuscles 저장 | 쿼리 빠름 | 데이터 중복, BodyPart 변경 시 불일치 | **거부** — BodyPart.affectedMuscleGroups computed property로 해결 |
| WorkoutRecommending 프로토콜에 injury 파라미터 추가 | 서비스 레벨 통합 | 기존 프로토콜 변경, 의존성 전파 | **거부** — ViewModel에서 post-filter (surgical scope) |
| 부상별로 별도 @Query 사용 (active/inactive) | 단순 | @Query 2개로 WellnessView 복잡도 증가 | **거부** — 단일 @Query + computed filter |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/BodyPart.swift` | **New** | BodyPart enum (18 cases) + BodySide enum |
| `Domain/Models/InjurySeverity.swift` | **New** | InjurySeverity enum (3 levels) |
| `Domain/Models/InjuryInfo.swift` | **New** | Domain DTO (ViewModel ↔ UseCase 교환용) |
| `Domain/UseCases/CheckInjuryConflictUseCase.swift` | **New** | 운동-부상 충돌 감지 |
| `Domain/Services/InjuryStatisticsService.swift` | **New** | 부상 통계 계산 (빈도, 평균 회복) |
| `Data/Persistence/Models/InjuryRecord.swift` | **New** | SwiftData @Model |
| `Data/Persistence/Migration/AppSchemaVersions.swift` | **Modify** | V5 추가 |
| `Presentation/Injury/InjuryViewModel.swift` | **New** | CRUD + validation + 통계 로딩 |
| `Presentation/Injury/InjuryFormSheet.swift` | **New** | 추가/수정 폼 UI |
| `Presentation/Injury/InjuryCardView.swift` | **New** | 활성 부상 카드 |
| `Presentation/Injury/InjuryHistoryView.swift` | **New** | 종료된 부상 목록 |
| `Presentation/Injury/InjuryStatisticsView.swift` | **New** | 부상 통계 + 운동량 비교 |
| `Presentation/Injury/InjuryBodyMapView.swift` | **New** | Wellness 탭용 부상 바디맵 (불스아이 마커) |
| `Presentation/Shared/Extensions/InjurySeverity+View.swift` | **New** | severity 색상/아이콘/displayName |
| `Presentation/Shared/Extensions/BodyPart+View.swift` | **New** | bodyPart displayName/icon |
| `Presentation/Shared/Components/JointMarkerView.swift` | **New** | 불스아이 링 마커 컴포넌트 |
| `Presentation/Shared/Components/MuscleMapData.swift` | **Modify** | 관절 좌표 데이터 추가 |
| `Presentation/Wellness/WellnessView.swift` | **Modify** | injurySection 추가 |
| `Presentation/Activity/Components/MuscleRecoveryMapView.swift` | **Modify** | 부상 오버레이 레이어 추가 |
| `Presentation/Activity/ActivityViewModel.swift` | **Modify** | 부상 충돌 경고 로직 추가 |
| `Presentation/Activity/Components/InjuryWarningBanner.swift` | **New** | Train 탭 경고 배너 |
| `DailveTests/InjuryTests/` | **New** | 테스트 파일들 |

## Implementation Steps

### Step 1: Domain 모델 + UseCase

- **Files**: `BodyPart.swift`, `InjurySeverity.swift`, `InjuryInfo.swift`, `CheckInjuryConflictUseCase.swift`, `InjuryStatisticsService.swift`
- **Changes**:
  - `BodyPart` enum — 18 cases (관절 8 + 근육 10), `affectedMuscleGroups: [MuscleGroup]`, `isLateral: Bool`
  - `BodySide` enum — left/right/both
  - `InjurySeverity` enum — minor(1)/moderate(2)/severe(3), `Comparable` conformance
  - `InjuryInfo` struct — Domain DTO (`bodyPart`, `bodySide?`, `severity`, `startDate`, `endDate?`, `memo`, `isActive`)
  - `CheckInjuryConflictUseCase` — Input(exerciseMuscles, activeInjuries) → Output([InjuryConflict]), sync pure computation
  - `InjuryStatisticsService` — 부위별 빈도, 평균 회복 기간, 총 부상 횟수 계산
- **Verification**: Unit test — `BodyPartTests`, `CheckInjuryConflictUseCaseTests`, `InjuryStatisticsServiceTests`

### Step 2: Data 레이어 (InjuryRecord + Schema V5)

- **Files**: `InjuryRecord.swift`, `AppSchemaVersions.swift`
- **Changes**:
  - `InjuryRecord` @Model — `id: UUID`, `bodyPartRaw: String`, `bodySideRaw: String?`, `severityRaw: Int`, `startDate: Date`, `endDate: Date?`, `memo: String`, `createdAt: Date`
  - Computed properties: `bodyPart`, `bodySide`, `severity`, `isActive`, `durationDays`
  - `toInjuryInfo() -> InjuryInfo` — Domain DTO 변환 메서드
  - `AppSchemaV5` 추가 — InjuryRecord 포함, lightweight migration
- **Verification**: 빌드 성공 + 앱 2회 실행 (CloudKit 스키마 검증, Correction #33)

### Step 3: ViewModel

- **Files**: `InjuryViewModel.swift`
- **Changes**:
  - `@Observable @MainActor final class InjuryViewModel`
  - Form state: `selectedBodyPart: BodyPart`, `selectedSide: BodySide?`, `selectedSeverity: InjurySeverity`, `startDate: Date`, `endDate: Date?`, `memo: String`
  - CRUD: `createValidatedRecord() -> InjuryRecord?`, `applyUpdate(to:) -> Bool`, `markAsRecovered(record:) -> Bool`
  - Validation: startDate <= today, endDate > startDate (if set), memo <= 500자, 동일 부위 중복 경고
  - 통계: `loadStatistics(from: [InjuryRecord])` — InjuryStatisticsService 호출
  - `startEditing(_:)`, `resetForm()`, `isSaving` guard
  - `selectedDate.didSet { validationError = nil }` (Correction #12)
- **Verification**: `InjuryViewModelTests` — validation 분기, 경계값, isSaving guard

### Step 4: Wellness UI (카드 리스트 + Form + History)

- **Files**: `WellnessView.swift`, `InjuryFormSheet.swift`, `InjuryCardView.swift`, `InjuryHistoryView.swift`, `InjurySeverity+View.swift`, `BodyPart+View.swift`
- **Changes**:
  - `WellnessView`: `@State var injuryViewModel`, `@Query InjuryRecord`, `injurySection` ViewBuilder
  - 기존 toolbar `+` 버튼을 `Menu`로 변경 (Body Composition / Injury 선택)
  - `InjuryCardView`: 부위명 + severity 배지(색상) + 기간 + 메모 요약
  - `InjuryFormSheet`: Picker(bodyPart) + SegmentedPicker(side, isLateral일 때만) + severity selector + DatePicker + TextField(memo)
  - `InjuryHistoryView`: 종료된 부상 목록, 삭제 시 `.confirmationDialog` (Correction #50)
  - `.navigationDestination(for: InjuryHistoryDestination.self)` — body 최상위 배치 (Correction #48)
  - Extension files: `displayName`, `color`, `icon` computed properties
- **Verification**: 빌드 성공 + 수동 테스트 (추가/수정/종료/삭제 플로우)

### Step 5: 바디맵 (Wellness 탭 + 공유 컴포넌트)

- **Files**: `JointMarkerView.swift`, `InjuryBodyMapView.swift`, `MuscleMapData.swift`
- **Changes**:
  - `MuscleMapData`: `static let frontJointPositions: [BodyPart: CGPoint]`, `static let backJointPositions: [BodyPart: CGPoint]` — SVG 724x1448 좌표
  - `JointMarkerView`: 불스아이 링 마커 (stroked circle + center dot), severity별 색상, moderate/severe 펄스 애니메이션
  - `InjuryBodyMapView`: MuscleRecoveryMapView 패턴 활용한 Wellness 전용 바디맵. 근육 영역은 neutral gray + 부상 부위만 severity 색상으로 하이라이트. 관절은 JointMarkerView. Front/Back 토글
- **Verification**: 빌드 성공 + 시각적 확인 (좌표 미세 조정 필요)

### Step 6: Train 탭 연동

- **Files**: `ActivityViewModel.swift`, `MuscleRecoveryMapView.swift`, `InjuryWarningBanner.swift`
- **Changes**:
  - `ActivityViewModel`: `var activeInjuryInfos: [InjuryInfo] = []`, `updateInjuries(records:)` 메서드, `injuredMuscleGroups: Set<MuscleGroup>` computed
  - `MuscleRecoveryMapView`: `injuredBodyParts: [(BodyPart, BodySide?, InjurySeverity)]` 파라미터 추가, ZStack 3번째 레이어에 JointMarkerView 오버레이 + 근육 영역 부상 시 빗금(줄무늬) 오버레이
  - `InjuryWarningBanner`: severity별 색상 배너 (minor=yellow, moderate=orange, severe=red), 충돌 근육 목록 표시
  - `ActivityView`: `@Query InjuryRecord` → `viewModel.updateInjuries(records:)`, 운동 선택/실행 시 `CheckInjuryConflictUseCase` 호출 → 배너 표시
- **Verification**: Train 탭에서 부상 부위 운동 선택 시 경고 배너 확인

### Step 7: 통계 + 운동량 비교

- **Files**: `InjuryStatisticsView.swift`, `InjuryViewModel.swift` (통계 관련 추가)
- **Changes**:
  - `InjuryStatisticsView`: 부위별 빈도 차트 (Bar chart), 평균 회복 기간 표시, 운동량 비교 (부상 전 2주 / 부상 중 / 부상 후 2주)
  - 운동량 비교: `InjuryViewModel`에서 `ExerciseRecord` @Query 결과를 받아 기간별 집계
  - Wellness 탭의 Injury 섹션 하단 또는 History 화면에 통계 링크
- **Verification**: 빌드 성공 + 통계 데이터 정합성 수동 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 동일 부위 중복 활성 부상 | 경고 표시 후 생성 허용 (다른 원인 가능) |
| 종료일 < 시작일 | validation 차단, `validationError` 표시 |
| 활성 부상 0개 | `miniEmptyState(icon: "bandage.fill", message: "...")` |
| 부상 삭제 | `.confirmationDialog` 필수 (CloudKit 전파) |
| 미래 시작일 | `startDate > Date()` → validation 차단 |
| memo 500자 초과 | `String(memo.prefix(500))` 자동 트림 |
| BodyPart가 isLateral=false인데 side 선택 | side picker 숨김, `bodySide = nil` |
| 부상 통계 데이터 부족 (부상 1건 미만) | 통계 섹션 숨김 또는 빈 상태 메시지 |
| 운동량 비교 시 해당 기간 운동 0건 | "해당 기간 운동 기록 없음" 표시 |
| Train 탭에서 부상과 무관한 운동 선택 | 경고 없이 정상 진행 |

## Testing Strategy

### Unit Tests

| Test File | Coverage |
|-----------|----------|
| `BodyPartTests.swift` | affectedMuscleGroups 매핑 정확성, isLateral, 모든 18 case |
| `InjurySeverityTests.swift` | rawValue, Comparable 순서 |
| `CheckInjuryConflictUseCaseTests.swift` | 충돌 감지 (겹침/미겹침/다중 부상/primary+secondary), 빈 입력 |
| `InjuryStatisticsServiceTests.swift` | 빈도 계산, 평균 회복 기간, 빈 데이터 |
| `InjuryViewModelTests.swift` | createValidatedRecord 성공/실패, validation 분기, isSaving guard, applyUpdate, markAsRecovered |

### Manual Verification

- 부상 추가/수정/종료/삭제 전체 플로우
- 바디맵 관절 마커 위치 정확성 (front/back)
- Train 탭 경고 배너 (minor/moderate/severe 각각)
- CloudKit: 앱 2회 실행 crash 없음 (Correction #33)
- 통계 화면 데이터 정합성

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 관절 좌표 오정렬 | Medium | Low | 구현 후 시각적 확인 + 미세 조정 |
| 스키마 V5 migration 이슈 | Low | High | Lightweight migration (새 모델 추가만), 2회 실행 테스트 |
| WellnessView 복잡도 증가 | Medium | Medium | injurySection을 별도 ViewBuilder로 분리, ViewModel 독립 |
| Train 탭 성능 (부상 조회 추가) | Low | Low | @Query는 SwiftData 캐싱, Set 연산은 O(N) 미만 |
| 바디맵 근육 영역 + 관절 마커 시각적 충돌 | Low | Medium | 근육=filled region, 관절=ring marker로 시각 언어 분리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 BodyCompositionRecord CRUD 패턴, MuscleRecoveryMapView ZStack 구조, ActivityViewModel 파이프라인이 잘 정립되어 있어 동일 패턴을 확장하면 됨. 새로운 인프라 없이 기존 좌표계/컴포넌트 재활용 가능. 스키마 V5는 새 모델 추가만이므로 lightweight migration으로 안전.
