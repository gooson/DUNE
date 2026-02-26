---
topic: muscle-map-detail-view
date: 2026-02-27
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-27-muscle-map-volume-mode-integration.md
  - architecture/2026-02-23-activity-detail-navigation-pattern.md
  - architecture/2026-02-23-activity-detail-view-v2-patterns.md
related_brainstorms:
  - 2026-02-27-muscle-map-detail-view.md
---

# Implementation Plan: Muscle Map Detail View

## Context

근육 관련 데이터가 3곳에 분산되어 있음:
- Activity 탭 `MuscleRecoveryMapView` (Recovery/Volume 모드)
- Activity 탭 `TrainingVolumeDetailView` (기간별 통계)
- Exercise 탭 `VolumeAnalysisView` (근육별 볼륨, 밸런스, 주간 목표)

머슬맵 상세화면을 만들어 Recovery + Volume Analysis를 통합하고, Exercise 탭의 `VolumeAnalysisView`는 제거.

## Requirements

### Functional

- Activity 탭 머슬맵 영역 탭 → MuscleMapDetailView push
- 상세화면: 큰 머슬맵 (Recovery/Volume 모드 토글)
- 상세화면: 근육 탭 → 인라인 섹션으로 해당 근육 정보 표시
- 상세화면: Volume Analysis 통합 (근육별 볼륨, 밸런스, 주간 목표)
- 상세화면: Recovery Overview (회복 요약)
- Exercise 탭 `VolumeAnalysisView` 제거
- Activity 탭 개별 근육 탭 → 기존 sheet(MuscleDetailPopover) 유지

### Non-functional

- Correction #103: Detail View는 parent ViewModel 참조 금지 → 개별 프로퍼티 전달
- Correction #146: 새 View에 DetailWaveBackground 적용
- Correction #148: muscleColors tuple return 패턴 유지
- Correction #83: VolumeIntensity static color cache 패턴 유지
- Correction #93: enum switch에 default 금지

## Approach

`TrainingReadinessDetailView` 패턴을 따름:
1. `ActivityDetailDestination`에 `.muscleMap` case 추가
2. `MuscleMap/` 폴더 생성 (기존 feature folder 구조)
3. init 파라미터로 `fatigueStates` 전달, ViewModel은 동기 변환만 수행
4. `MuscleRecoveryMapView`를 재사용 (큰 버전 + 인라인 근육 상세)
5. `VolumeAnalysisView` 내용을 섹션 컴포넌트로 이식
6. Exercise 탭에서 `VolumeAnalysisView` 참조 제거

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| MuscleRecoveryMapView를 확장하여 detail 모드 추가 | 코드 재사용 극대화 | 단일 컴포넌트가 비대해짐, 책임 불명확 | Rejected |
| 독립 ViewModel에서 HealthKit re-fetch | 데이터 독립성 | 중복 쿼리, 부모와 불일치 가능 | Rejected |
| **init 파라미터 전달 + 경량 ViewModel** | #103 준수, 일관된 데이터 | ActivityViewModel에 의존 | **Selected** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Activity/MuscleMap/MuscleMapDetailView.swift` | NEW | 상세화면 메인 뷰 |
| `Activity/MuscleMap/MuscleMapDetailViewModel.swift` | NEW | 볼륨/회복 데이터 변환 |
| `Activity/MuscleMap/Components/MuscleInlineDetailSection.swift` | NEW | 근육 탭 시 인라인 상세 |
| `Activity/MuscleMap/Components/VolumeBreakdownSection.swift` | NEW | 근육별 볼륨 리스트 + 밸런스 |
| `Activity/MuscleMap/Components/RecoveryOverviewSection.swift` | NEW | 회복 요약 섹션 |
| `Activity/ActivityDetailDestination.swift` | MODIFY | `.muscleMap` case 추가 |
| `Activity/ActivityView.swift` | MODIFY | NavigationLink 래핑 + navigationDestination 추가 |
| `Activity/Components/MuscleRecoveryMapView.swift` | MODIFY | 큰 사이즈 지원용 `isExpanded` 파라미터 추가 |
| `Exercise/ExerciseView.swift` | MODIFY | VolumeAnalysisView NavigationLink 제거 |
| `Exercise/Components/VolumeAnalysisView.swift` | DELETE | 통합 완료 후 삭제 |
| `Dailve/project.yml` | MODIFY | 새 파일 반영 (xcodegen) |

## Implementation Steps

### Step 1: ActivityDetailDestination 확장

- **Files**: `ActivityDetailDestination.swift`
- **Changes**: `.muscleMap` case 추가
- **Verification**: 빌드 — switch exhaustive check로 누락 감지

### Step 2: MuscleMapDetailViewModel 생성

- **Files**: `Activity/MuscleMap/MuscleMapDetailViewModel.swift`
- **Changes**:
  - `@Observable @MainActor final class`
  - `func loadData(fatigueStates: [MuscleFatigueState])` — 동기 변환
  - Properties: `fatigueByMuscle: [MuscleGroup: MuscleFatigueState]`, `sortedMuscleVolumes: [(MuscleGroup, Int)]`, `recoveredCount`, `trainedCount`, `totalWeeklySets`, `balanceInfo: BalanceInfo`
  - `selectedMuscle: MuscleGroup?` (인라인 섹션 트리거)
  - `mode: MapMode` (Recovery/Volume 토글)
  - `weeklySetGoal: Int` (`@AppStorage` 대신 init 파라미터 또는 UserDefaults 직접 읽기)
- **Verification**: Unit test — 빈 배열, 전체 회복, 전체 미회복, 밸런스 계산

### Step 3: 섹션 컴포넌트 생성

- **Files**: `MuscleInlineDetailSection.swift`, `VolumeBreakdownSection.swift`, `RecoveryOverviewSection.swift`
- **Changes**:
  - `MuscleInlineDetailSection`: MuscleDetailPopover의 statsGrid + topExercises를 인라인 VStack으로 변환. `let muscle`, `let fatigueState`, `let library` 파라미터
  - `VolumeBreakdownSection`: VolumeAnalysisView의 summaryCards + goalSection + muscleBreakdown + balanceSection 이식. 데이터는 ViewModel에서 받음
  - `RecoveryOverviewSection`: recoveredCount/totalCount, overworked 근육, 다음 회복 시간 표시
- **Verification**: Preview로 각 섹션 독립 확인

### Step 4: MuscleMapDetailView 생성

- **Files**: `Activity/MuscleMap/MuscleMapDetailView.swift`
- **Changes**:
  - init: `let fatigueStates: [MuscleFatigueState]`
  - `@State private var viewModel = MuscleMapDetailViewModel()`
  - `.task { viewModel.loadData(fatigueStates: fatigueStates) }`
  - Layout: ScrollView > VStack
    1. MuscleRecoveryMapView (expanded, 근육 탭 → viewModel.selectedMuscle 설정)
    2. MuscleInlineDetailSection (selectedMuscle가 non-nil일 때 표시, withAnimation)
    3. VolumeBreakdownSection
    4. RecoveryOverviewSection
  - `.background { DetailWaveBackground() }`
  - `.navigationTitle("Muscle Map")`
  - `.navigationBarTitleDisplayMode(.inline)`
- **Verification**: Preview + 시뮬레이터에서 push/pop, 근육 탭 인라인 확장

### Step 5: MuscleRecoveryMapView 확장

- **Files**: `Activity/Components/MuscleRecoveryMapView.swift`
- **Changes**:
  - `var isExpanded: Bool = false` 파라미터 추가 (기본값 false → 기존 사용처 변경 없음)
  - `isExpanded == true`일 때: frame maxWidth 제거 (부모 크기에 맞춤), maxHeight 증가 (300 → 400)
  - 인라인 모드에서 header의 info button/segmented picker는 유지
- **Verification**: Activity 탭에서 기존 compact 렌더 유지 확인

### Step 6: ActivityView 통합

- **Files**: `Activity/ActivityView.swift`
- **Changes**:
  - `recoveryMapSection()` 수정: SectionGroup 전체를 `NavigationLink(value: .muscleMap)`로 래핑. 개별 근육 탭 → sheet 유지 (onMuscleSelected 그대로)
  - `.navigationDestination(for: ActivityDetailDestination.self)` switch에 `.muscleMap` case 추가:
    ```swift
    case .muscleMap:
        MuscleMapDetailView(fatigueStates: viewModel.fatigueStates)
    ```
  - **주의**: NavigationLink가 SectionGroup 전체를 감싸므로, 개별 근육 Button 탭이 NavigationLink 탭과 충돌하지 않아야 함 → MuscleRecoveryMapView 내부 Button이 이벤트를 소비하므로 배경 탭만 NavigationLink 작동
- **Verification**: 시뮬레이터에서 머슬맵 배경 탭 → push, 근육 탭 → sheet (둘 다 정상 작동)

### Step 7: VolumeAnalysisView 제거

- **Files**: `Exercise/ExerciseView.swift`, `Exercise/Components/VolumeAnalysisView.swift`
- **Changes**:
  - ExerciseView.swift: toolbar의 `NavigationLink { VolumeAnalysisView() }` 제거
  - VolumeAnalysisView.swift: 파일 삭제
  - project.yml에서 파일 참조 자동 반영 (xcodegen glob 패턴)
- **Verification**: Exercise 탭에서 차트 버튼 사라짐 확인, 빌드 성공

### Step 8: xcodegen + 빌드 검증

- **Files**: `Dailve/project.yml`
- **Changes**: `cd Dailve && xcodegen generate`
- **Verification**: `scripts/build-ios.sh` 실행, 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 운동 기록 없는 사용자 | VolumeBreakdownSection: "Start training to see muscle volume" placeholder |
| 선택된 근육에 데이터 없음 | MuscleInlineDetailSection: fatigueState nil → "No recent activity" 표시 |
| 모드 전환 시 선택된 근육 | selectedMuscle 유지 — 모드에 따라 표시 정보만 변경 |
| fatigueStates 빈 배열 | RecoveryOverviewSection: "Start training to track recovery" |
| weeklySetGoal 기존 사용자 | @AppStorage("weeklySetGoal") 키 동일하게 사용 → 기존 값 보존 |

## Testing Strategy

- **Unit tests**: `MuscleMapDetailViewModelTests.swift`
  - `loadData` 빈 배열 → 기본값 확인
  - `loadData` 전체 회복 → recoveredCount == totalCount
  - `loadData` 밸런스 계산 — 균형/불균형 케이스
  - `sortedMuscleVolumes` 정렬 순서
  - `totalWeeklySets` 합산 정확성
- **Manual verification**:
  - Activity 탭 머슬맵 배경 탭 → push 확인
  - Activity 탭 개별 근육 탭 → sheet 확인 (기존 동작 유지)
  - 상세화면 근육 탭 → 인라인 섹션 확장/축소
  - 상세화면 모드 토글 (Recovery ↔ Volume)
  - Exercise 탭에서 VolumeAnalysis 버튼 사라짐 확인
  - iPad 레이아웃 (compact/regular 모두)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| NavigationLink + Button 탭 충돌 | Medium | High | MuscleRecoveryMapView 내부 Button이 이벤트를 소비하므로 배경만 NavigationLink 트리거. 시뮬레이터 테스트로 검증 |
| @AppStorage 키 불일치 | Low | Medium | 동일 키 "weeklySetGoal" 사용, VolumeAnalysisView 삭제 전 키 확인 |
| 큰 머슬맵 성능 | Low | Low | 기존 SVG 캐싱 패턴 유지, path(in:) 무거운 연산 없음 (#82) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 detail view 패턴(TrainingReadinessDetailView)이 명확하고, VolumeAnalysisView 코드가 단순하여 이식 용이. NavigationLink + Button 탭 충돌만 실기기 검증 필요.
