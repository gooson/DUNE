---
tags: [muscle-map, detail-view, volume-analysis, recovery, DRY, push-navigation, isInline]
category: architecture
date: 2026-02-27
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailViewModel.swift
  - DUNE/Presentation/Activity/MuscleMap/Components/VolumeBreakdownSection.swift
  - DUNE/Presentation/Activity/MuscleMap/Components/RecoveryOverviewSection.swift
related_solutions:
  - architecture/2026-02-21-wellness-section-split-patterns.md
---

# Solution: Muscle Map Detail View — Volume + Recovery 통합

## Problem

### Symptoms

- Volume Analysis가 Exercise 탭 toolbar에 별도 뷰로 존재 — 근육 맵과 분리되어 사용자가 연결성을 인지하기 어려움
- 근육 맵 터치 시 개별 근육 정보만 시트로 표시 — 전체 볼륨/회복 현황을 한 눈에 볼 수 없음
- 근육별 상세 정보가 popover와 inline에서 코드 중복 가능성

### Root Cause

Volume Analysis, Recovery Overview, Muscle Map이 각기 다른 뷰/탭에 흩어져 있어 통합된 근육 상태 분석 화면이 부재

## Solution

Activity 탭의 근육 맵 영역 전체를 탭하면 Push 네비게이션으로 **MuscleMapDetailView** 진입. 확대된 근육 맵 + 볼륨 분석 + 회복 상태를 하나의 스크롤 뷰에 통합.

### Architecture Decisions

1. **Push navigation via NavigationLink(value:)**: `ActivityDetailDestination.muscleMap` case 추가. NavigationLink가 SectionGroup을 감싸되, 내부 Button들이 탭 이벤트를 소비하여 개별 근육 선택은 여전히 동작
2. **isInline 패턴**: `MuscleDetailPopover`에 `isInline: Bool` 파라미터 추가. sheet(isInline=false)과 inline section(isInline=true) 모두 단일 View가 처리 → DRY
3. **Top-level DTO**: `MuscleBalanceInfo`를 ViewModel 내부가 아닌 top-level struct로 선언하여 component View와 ViewModel 간 커플링 해소
4. **Service DI**: `MuscleMapDetailView(fatigueStates:, library:)` init 파라미터로 `ExerciseLibraryQuerying` 주입 (default: `.shared`)
5. **UserDefaults 캐싱**: `weeklySetGoal`을 stored property + `setWeeklySetGoal(_:)` 메서드 패턴으로 변경. 매 렌더 UserDefaults 읽기 제거

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ActivityDetailDestination.swift` | `.muscleMap` case 추가 | Push navigation routing |
| `MuscleMapDetailView.swift` | 새 파일 — ScrollView with expanded map + sections | 통합 상세 화면 |
| `MuscleMapDetailViewModel.swift` | 새 파일 — fatigue states → display data 변환 | Correction #103 준수 |
| `MuscleDetailPopover.swift` | `isInline` 파라미터 + `@State topExercises` 캐싱 | DRY + P1 성능 수정 |
| `VolumeBreakdownSection.swift` | 새 파일 — volume 분석 섹션 컴포넌트 | VolumeAnalysisView에서 추출 |
| `RecoveryOverviewSection.swift` | 새 파일 — 회복 현황 섹션 컴포넌트 | 독립 섹션으로 분리 |
| `MuscleRecoveryMapView.swift` | `isExpanded` 파라미터 추가 | Detail view에서 확대 표시 |
| `ActivityView.swift` | NavigationLink wrapping + destination 추가 | Push 네비게이션 연결 |
| `ExerciseView.swift` | Toolbar volume 링크 제거 | Detail view로 이관 |
| `VolumeAnalysisView.swift` | 삭제 | 기능 통합 완료 |

### Key Patterns

```swift
// isInline 패턴 — 단일 View가 sheet/inline 모두 처리
struct MuscleDetailPopover: View {
    var isInline: Bool = false

    var body: some View {
        content.task(id: muscle) { topExercises = ... }
    }

    @ViewBuilder
    private var content: some View {
        if isInline {
            inlineBody.padding(DS.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(...))
        } else {
            inlineBody.padding(DS.Spacing.xl)
                .presentationDetents([.medium])
        }
    }
}

// weeklySetGoal 캐싱 패턴
private(set) var weeklySetGoal: Int = {
    let stored = UserDefaults.standard.integer(forKey: Keys.weeklySetGoal)
    return stored == 0 ? 15 : stored.clamped(to: 5...30)
}()

func setWeeklySetGoal(_ value: Int) {
    weeklySetGoal = value.clamped(to: 5...30)
    UserDefaults.standard.set(weeklySetGoal, forKey: Keys.weeklySetGoal)
}

// Undertrained 근육 식별 (수정 후)
let undertrained = sortedMuscleVolumes
    .filter { $0.volume > 0 && $0.volume < goalHalf }
    .sorted { $0.volume < $1.volume }
    .prefix(3)
    .map(\.muscle)
```

## Prevention

### Checklist Addition

- [ ] Popover/sheet View를 inline으로도 사용할 때 `isInline` 파라미터 패턴 사용
- [ ] computed property에서 service 호출 시 `@State` + `.task(id:)` 캐싱 필수
- [ ] ViewModel 내부 struct가 2곳 이상에서 사용되면 top-level로 즉시 추출
- [ ] UserDefaults 읽기가 ForEach 내에서 반복되면 stored property 캐싱

## Lessons Learned

1. **isInline 패턴이 DRY에 효과적**: Popover와 inline section의 차이는 container 스타일뿐. `@ViewBuilder` content 분기로 간단 해결
2. **suffix(3) 함정**: 전체 리스트(untrained 포함)의 suffix는 거의 항상 volume=0 항목. 비즈니스 필터 후 prefix/suffix 적용해야 의미있는 결과
3. **UserDefaults computed property는 hot path에서 위험**: ForEach × N rows × 3 reads = O(N) lock acquisition per render
