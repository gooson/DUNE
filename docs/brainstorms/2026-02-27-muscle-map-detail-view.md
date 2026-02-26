---
tags: [muscle-map, volume-analysis, detail-view, navigation, activity-tab]
date: 2026-02-27
category: brainstorm
status: reviewed
---

# Brainstorm: Muscle Map Detail View + Volume Analysis Integration

## Problem Statement

현재 근육 관련 데이터가 분산되어 있음:
- **MuscleRecoveryMapView** (Activity 탭): Recovery/Volume 2모드 토글, 개별 근육 → sheet
- **TrainingVolumeDetailView** (Activity → 요약 카드 → push): 기간별 볼륨 통계, 도넛/바 차트
- **VolumeAnalysisView** (Exercise 탭): 근육별 볼륨, 밸런스, 주간 목표

사용자가 "내 근육 상태가 어떤지"를 한 곳에서 볼 수 없음. 머슬맵 상세화면을 만들어 Recovery + Volume을 통합하고, Exercise 탭의 VolumeAnalysisView는 제거.

## Target Users

- 웨이트 트레이닝 사용자 (주 3-6회)
- 근육별 회복/볼륨 밸런스를 신경 쓰는 사용자

## Success Criteria

1. Activity 탭 → 머슬맵 탭 → 한 화면에서 Recovery + Volume 전체 확인 가능
2. Exercise 탭의 VolumeAnalysisView 제거 후 기능 누락 없음
3. 상세화면 내 근육 탭 → 인라인 섹션으로 해당 근육 정보 표시
4. 기존 TrainingVolumeDetailView/SummaryCard는 유지 (변경 없음)

## Proposed Approach

### Navigation Flow

```
Activity Tab
├─ MuscleRecoveryMapView (compact, 현재와 동일)
│  ├─ [개별 근육 탭] → MuscleDetailPopover (sheet, 현재 유지)
│  └─ [맵 영역 탭 / 버튼] → Push: MuscleMapDetailView ← NEW
│
├─ TrainingVolumeSummaryCard → Push: TrainingVolumeDetailView (유지)
└─ ...

MuscleMapDetailView (NEW)
├─ 큰 머슬맵 (Recovery/Volume 모드 토글)
├─ 근육 탭 → 인라인 섹션 (MuscleDetailPopover 내용을 섹션으로)
├─ Volume Analysis 통합
│  ├─ 근육별 볼륨 리스트 + 프로그레스 바
│  ├─ 밸런스 인디케이터
│  └─ 주간 목표
└─ Recovery Overview
   ├─ X/Y 근육 회복 완료
   └─ 회복 타임라인 (다음 준비 시간)
```

### 상세화면 레이아웃 (초안)

```
┌─────────────────────────────┐
│ ← Muscle Map     [Recovery|Volume] ← segmented picker
├─────────────────────────────┤
│                             │
│     [Front]    [Back]       │  ← 큰 머슬맵 (탭 인터랙션)
│                             │
├─────────────────────────────┤
│ ▼ Selected: Chest           │  ← 근육 탭 시 인라인 확장
│   Recovery: 85% | Level 2   │
│   Weekly Volume: 12 sets    │
│   Top Exercises: ...        │
├─────────────────────────────┤
│ § Volume Analysis           │
│   Total: 48 sets this week  │
│   ┌ Chest ████████░░ 12     │
│   ├ Back  ██████░░░░  8     │
│   ├ Legs  █████░░░░░  7     │
│   └ ...                     │
│   Balance: ●●●○○ Moderate   │
│   Weekly Goal: 40/50 sets   │
├─────────────────────────────┤
│ § Recovery Status           │
│   Ready: 8/13 muscles       │
│   Next ready: Chest (4h)    │
│   Overworked: Shoulders     │
└─────────────────────────────┘
```

### 주요 구현 항목

| 항목 | 파일 | 설명 |
|------|------|------|
| MuscleMapDetailView | `Activity/MuscleMap/MuscleMapDetailView.swift` | NEW - 상세화면 메인 뷰 |
| MuscleMapDetailViewModel | `Activity/MuscleMap/MuscleMapDetailViewModel.swift` | NEW - 데이터 로딩/상태 |
| MuscleInlineDetailSection | `Activity/MuscleMap/Components/MuscleInlineDetailSection.swift` | NEW - 인라인 근육 상세 |
| VolumeOverviewSection | `Activity/MuscleMap/Components/VolumeOverviewSection.swift` | NEW - 볼륨 분석 섹션 |
| RecoveryOverviewSection | `Activity/MuscleMap/Components/RecoveryOverviewSection.swift` | NEW - 회복 상태 섹션 |
| MuscleRecoveryMapView | 기존 수정 | 탭 제스처 → push navigation 추가 |
| ActivityView | 기존 수정 | navigationDestination 추가 |
| VolumeAnalysisView | 삭제 | Exercise 탭에서 제거 |

### 데이터 흐름

```
MuscleMapDetailViewModel
├─ fatigueStates: [MuscleFatigueState]     ← ActivityViewModel과 공유 or 독립 fetch
├─ selectedMuscle: MuscleGroup?            ← 인라인 섹션 트리거
├─ muscleVolumes: [MuscleGroup: Int]       ← 주간 근육별 볼륨
├─ weeklyGoal: Int                         ← UserDefaults
├─ balanceRatio: Double                    ← 볼륨 균형도
├─ recoveryStats: RecoveryOverview         ← 회복 요약 (ready/total/next)
└─ mode: MapMode (.recovery | .volume)     ← 모드 토글
```

## Constraints

- **Correction #103**: Detail View는 parent ViewModel 참조 금지 → 필요한 데이터를 개별 프로퍼티로 전달 or 독립 ViewModel
- **Correction #82**: Shape.path(in:) 내 무거운 연산 금지 → 기존 MuscleBodyShape 패턴 유지
- **Correction #148**: 모드별 dispatch는 tuple return 단일 함수 → muscleColors(for:) 패턴 유지
- **Correction #146**: 새 View 추가 시 웨이브 배경 적용 → DetailWaveBackground 적용
- Activity 탭의 기존 TrainingVolumeSummaryCard → TrainingVolumeDetailView 경로는 변경 없음

## Edge Cases

1. **운동 기록 없는 사용자**: 볼륨 섹션 빈 상태 → "Start training to see muscle volume" placeholder
2. **선택된 근육에 데이터 없음**: 인라인 섹션에 "No recent activity for this muscle" 표시
3. **모드 전환 시 선택된 근육**: 모드 전환해도 selectedMuscle 유지 (컨텍스트 보존)
4. **iPad 레이아웃**: sizeClass regular → 머슬맵과 상세 정보를 HStack으로 나란히 배치 고려

## Scope

### MVP (Must-have)
- MuscleMapDetailView 생성 (push navigation)
- Recovery + Volume 모드 토글 (기존 로직 재사용)
- 근육 탭 → 인라인 섹션 (MuscleDetailPopover 내용 기반)
- Volume Analysis 통합 (근육별 볼륨 리스트, 밸런스, 주간 목표)
- Recovery Overview 섹션 (회복 요약)
- VolumeAnalysisView 제거 (Exercise 탭)
- 웨이브 배경 적용

### Nice-to-have (Future)
- iPad HStack 레이아웃
- 기간별 볼륨 트렌드 차트 (주간/월간)
- 근육별 PR 표시
- 추천 운동 링크 (Exercise 라이브러리 연동)
- 회복 타임라인 시각화 (시간대별 바 차트)

## Decisions (Resolved)

1. **Push 트리거**: 머슬맵 영역 전체 탭 → push. 개별 근육 탭은 Activity 탭에서 sheet, 상세화면에서 인라인 섹션
2. **데이터 소스**: init 파라미터로 개별 프로퍼티 전달 (Correction #103 준수). ActivityViewModel에서 이미 로드한 fatigueStates 활용
3. **Exercise 탭 볼륨 진입점 제거**: OK 확인됨

## Next Steps

- [ ] `/plan muscle-map-detail` 로 구현 계획 생성
