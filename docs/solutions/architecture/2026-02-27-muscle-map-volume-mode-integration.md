---
tags: [muscle-map, recovery-map, volume, segmented-picker, swipe-gesture, mode-toggle, body-diagram, svg, color-cache, deduplication, view-consolidation]
category: architecture
date: 2026-02-27
severity: moderate
related_files:
  - DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift
  - DUNE/Presentation/Activity/Components/VolumeIntensity.swift
  - DUNE/Presentation/Activity/Components/VolumeLegendView.swift
  - DUNE/Presentation/Activity/Components/VolumeAlgorithmSheet.swift
related_solutions:
  - performance/2026-02-19-swiftui-color-static-caching.md
  - architecture/2026-02-19-exponential-decay-fatigue-model.md
---

# Solution: Recovery Map + Volume Mode 통합 (Segmented Picker)

## Problem

### Symptoms

- Activity 탭에 근육 시각화가 2곳에 분산: `MuscleRecoveryMapView` (SVG body diagram) + `MuscleMapView` (progress bar)
- 사용자가 회복 상태와 훈련 볼륨을 한눈에 비교 불가
- `MuscleMapView`는 상대 볼륨(최대값 대비 %) 사용 — 절대 기준 부재로 훈련 충분 여부 판단 곤란

### Root Cause

Recovery Map과 Muscle Map이 독립 컴포넌트로 설계되어 동일 body diagram을 공유하지 않음. 데이터는 이미 `MuscleFatigueState.weeklyVolume`에 존재하지만 시각화 경로가 분리.

## Solution

### Approach: 기존 MuscleRecoveryMapView 확장 + 모드 전환

**핵심 결정**: SVG body diagram을 1벌만 렌더하고, 색상 함수만 모드에 따라 분기.

#### 모드 전환 UX 변천

| 시도 | 방식 | 결과 |
|------|------|------|
| 1차 | `DragGesture` + 페이지 인디케이터 | 근육 탭(Button) 제스처와 충돌 — **기각** |
| 2차 | `Picker(.segmented)` 상단 배치 | 명시적이고 충돌 없음 — **채택** |

**교훈**: body diagram 위 DragGesture는 ForEach 내부 Button의 탭 이벤트를 가로챔. `.minimumDistance(30)`으로도 해결 불가. Segmented Picker가 SVG 인터랙션 영역과 분리되어 안정적.

### Changes Made

1. **`MuscleRecoveryMapView.swift`** — `MapMode` enum + segmented picker + 단일 `muscleColors(for:)` 함수
2. **`VolumeIntensity.swift`** (신규) — 5단계 enum + static color cache (Correction #83) + description
3. **`VolumeLegendView.swift`** (신규) — FatigueLegendView 미러링한 gradient bar
4. **`VolumeAlgorithmSheet.swift`** (신규) — Volume 계산 방법 설명 sheet
5. **`MuscleMapView.swift`** (삭제) — 통합 뷰로 대체
6. **`MuscleMapSummaryCard.swift`** (삭제) — 통합 뷰로 대체

### Key Patterns

#### 모드별 색상 분기 — 단일 함수 반환

```swift
private func muscleColors(for muscle: MuscleGroup) -> (fill: Color, stroke: Color) {
    switch mode {
    case .recovery:
        return (recoveryColor(for: muscle), recoveryStrokeColor(for: muscle))
    case .volume:
        let intensity = VolumeIntensity.from(sets: fatigueByMuscle[muscle]?.weeklyVolume ?? 0)
        return (intensity.color, intensity.strokeColor)
    }
}
```

4개 dispatch 함수(fillColor/strokeColor → recovery/volume 각각)를 1개 튜플 반환 함수로 통합.

#### VolumeIntensity static color cache

```swift
private enum ColorCache {
    static let fill: [Color] = VolumeIntensity.allCases.map { ... }
    static let stroke: [Color] = VolumeIntensity.allCases.map { ... }
}
var color: Color { ColorCache.fill[rawValue] }
```

rawValue를 인덱스로 O(1) 접근. ForEach ~40 근육 파트 렌더 시 allocation-free.

#### subtitle 캐싱 — rebuildFatigueIndex()에서 파생

```swift
@State private var recoveredCount = 0
@State private var trainedCount = 0

private func rebuildFatigueIndex() {
    fatigueByMuscle = Dictionary(...)
    recoveredCount = fatigueStates.filter(\.isRecovered).count
    trainedCount = fatigueStates.filter { $0.weeklyVolume > 0 }.count
}
```

subtitle가 body 렌더마다 O(N) filter하는 대신, 데이터 변경 시점에 1회 계산.

#### infoButton 중복 제거

```swift
Button {
    switch mode {
    case .recovery: showingRecoveryInfoSheet = true
    case .volume: showingVolumeInfoSheet = true
    }
} label: {
    Image(systemName: "info.circle")...
}
// .sheet 2개를 headerSection에 부착
```

## Prevention

1. **body diagram 위 커스텀 제스처 추가 전**: ForEach 내 Button/NavigationLink와 제스처 충돌 확인. 가능하면 diagram 영역 밖(header/footer)에 컨트롤 배치
2. **다중 모드 뷰 설계 시**: 모드별 dispatch 함수보다 단일 함수에서 튜플 반환이 switch 중복 최소화
3. **cross-file 참조 enum**: 3개+ 파일에서 사용되면 전용 파일로 즉시 분리
4. **VolumeIntensity 기준 변경 시**: `VolumeIntensity.swift` 단일 파일만 수정하면 됨

## Lessons Learned

1. **스와이프 UX는 SVG body diagram과 양립 어려움**: 수십 개 Button이 ForEach로 렌더되는 영역에서 DragGesture는 탭 이벤트를 소비함. Segmented Picker가 관심사를 분리하는 더 나은 선택
2. **Correction #118 재확인**: `Color.opacity()`는 value operation이므로 `String(format:)`처럼 static 캐싱이 필수는 아니지만, ForEach hot path(40+ 호출)에서는 Correction #83이 우선 적용
3. **기존 데이터 재활용**: `MuscleFatigueState.weeklyVolume`이 이미 존재하여 새 데이터 fetch 없이 Volume 모드 구현 완료. 신규 기능 전 기존 모델 프로퍼티 확인이 중요
