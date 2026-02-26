---
topic: recovery-muscle-map-integration
date: 2026-02-27
status: draft
confidence: high
related_solutions: []
related_brainstorms: [2026-02-27-recovery-muscle-map-integration]
---

# Implementation Plan: Recovery Map + Muscle Map 통합

## Context

Activity 탭의 Recovery Map에 Volume 모드를 추가하여, 하나의 body diagram에서 스와이프로 회복 상태와 훈련 볼륨을 전환할 수 있도록 한다. 기존 `MuscleMapView`(progress bar)와 `MuscleMapSummaryCard`는 이 통합 뷰로 대체한다.

## Requirements

### Functional

- 기존 Recovery Map body diagram 위에 `TabView(.page)` 스와이프로 Recovery ↔ Volume 모드 전환
- 페이지 인디케이터(dots) 표시
- Volume 모드: 주간 세트 수 기준 절대 볼륨 강도로 근육 채색 (0 / 1-5 / 6-10 / 11-15 / 16+)
- 모드별 Legend 전환 (Recovery: 기존 FatigueLegendView, Volume: 세트 기반 범례)
- 모드별 요약 텍스트 전환
- Recovery 모드: 기존 탭→상세 팝오버(MuscleDetailPopover) 유지
- Volume 모드에서도 근육 탭 시 기존 MuscleDetailPopover 표시 (weeklyVolume 정보 이미 포함)
- Volume 모드 ⓘ info 버튼 → Volume 설명 sheet 추가
- 기존 `MuscleMapView`, `MuscleMapSummaryCard` 참조 제거

### Non-functional

- SVG body diagram 2회 렌더 없음 — 같은 diagram에 색상만 전환
- Correction #82: path(in:) 내 무거운 연산 금지 (이미 pre-parsed)
- Correction #83: Color 인스턴스 static 캐싱

## Approach

**기존 `MuscleRecoveryMapView`를 확장**하여 모드 전환 기능을 추가한다. `TabView`는 body diagram 전체를 감싸지 않고, 색상 함수만 모드에 따라 분기하는 방식으로 구현한다. 이렇게 하면 SVG를 2벌 렌더하지 않아 성능이 유지된다.

**모드 전환 UX**: body diagram 위에 좌우 스와이프 제스처를 감지하여 모드를 토글한다. `TabView(.page)`를 body diagram 전체에 사용하면 SVG가 2벌 렌더되므로, 대신 `DragGesture`로 스와이프를 감지하고 색상+legend+subtitle만 `.transition(.opacity)` crossfade한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TabView(.page) wrapping 2 diagrams | 네이티브 스와이프 UX | SVG 2벌 렌더, 메모리 2배 | **기각** |
| DragGesture + 색상 전환 | SVG 1벌, 가벼움, crossfade | 커스텀 제스처 구현 필요 | **채택** |
| Segmented Picker | 명시적 모드 표시 | 공간 차지, 사용자가 스와이프 선호 | **기각** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift` | **Major Modify** | 모드 enum 추가, 색상 함수 분기, DragGesture, legend/subtitle 전환 |
| `DUNE/Presentation/Activity/Components/VolumeLegendView.swift` | **New** | 세트 기반 볼륨 범례 (0 / 1-5 / 6-10 / 11-15 / 16+) |
| `DUNE/Presentation/Activity/Components/VolumeAlgorithmSheet.swift` | **New** | 볼륨 모드 설명 info sheet |
| `DUNE/Presentation/Shared/Extensions/FatigueLevel+View.swift` | **Minor Modify** | 볼륨 색상 static 캐시 추가 (또는 별도 enum) |
| `DUNE/Presentation/Activity/ActivityView.swift` | **Minor Modify** | recoveryMapSection 제목 변경 ("Recovery Map" → "Muscle Map") |
| `DUNE/Presentation/Activity/Components/MuscleMapSummaryCard.swift` | **Delete** | 통합 뷰로 대체 |
| `DUNE/Presentation/Exercise/Components/MuscleMapView.swift` | **Delete** | 통합 뷰로 대체 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | **Minor Modify** | MuscleMapSummaryCard 참조 제거 |
| `Dailve/project.yml` | **Modify** | 새 파일 등록, 삭제 파일 제거 |

## Implementation Steps

### Step 1: MuscleRecoveryMapView에 모드 전환 추가

- **Files**: `MuscleRecoveryMapView.swift`
- **Changes**:
  1. `enum MuscleMapMode: CaseIterable { case recovery, volume }` 추가
  2. `@State private var mode: MuscleMapMode = .recovery` 추가
  3. `@State private var showingVolumeInfoSheet = false` 추가
  4. body diagram에 `.gesture(DragGesture(...))` 추가 — 수평 50pt+ 스와이프로 모드 토글
  5. `bodyDiagram(isFront:)` 내 `fill()`과 `stroke()`를 `colorForCurrentMode(muscle:)` 함수로 분기
  6. header의 subtitle을 모드별 전환 (Recovery: "N/M groups ready", Volume: "N muscles trained this week")
  7. header의 info 버튼을 모드별 분기 (Recovery: FatigueAlgorithmSheet, Volume: VolumeAlgorithmSheet)
  8. legend를 모드별 전환 (Recovery: FatigueLegendView, Volume: VolumeLegendView)
  9. 페이지 인디케이터 dots 추가 (2개, 현재 모드 highlight)
  10. 모드 전환 시 `.animation(.easeInOut(duration: 0.3))`
- **Verification**: 빌드 성공, Recovery 모드 기존 동작 유지, 스와이프로 Volume 모드 전환

### Step 2: 볼륨 색상 시스템 구현

- **Files**: `MuscleRecoveryMapView.swift` (private enum 또는 inline)
- **Changes**:
  1. Volume 모드 색상 함수: `weeklyVolume` 기준 5단계 채색
     - 0 sets: `Color.secondary.opacity(0.08)` (미훈련, 회색)
     - 1-5 sets: `DS.Color.activity.opacity(0.2)` (경량)
     - 6-10 sets: `DS.Color.activity.opacity(0.4)` (적정)
     - 11-15 sets: `DS.Color.activity.opacity(0.6)` (고강도)
     - 16+ sets: `DS.Color.activity.opacity(0.8)` (과다)
  2. static 캐싱은 불필요 — opacity 기반 단순 Color 연산이므로 (Correction #118 적용)
- **Verification**: Volume 모드 근육 채색 정상 렌더

### Step 3: VolumeLegendView 생성

- **Files**: `VolumeLegendView.swift` (new)
- **Changes**:
  1. FatigueLegendView와 유사한 compact gradient bar 형태
  2. 5단계: "0 sets" → "1-5" → "6-10" → "11-15" → "16+"
  3. 라벨: "Untrained" ↔ "High Volume"
  4. `onTap` 클로저 (info sheet 열기용)
- **Verification**: Preview에서 렌더 확인

### Step 4: VolumeAlgorithmSheet 생성

- **Files**: `VolumeAlgorithmSheet.swift` (new)
- **Changes**:
  1. FatigueAlgorithmSheet 구조 참고
  2. 섹션: 개요, 볼륨 계산 방법 (primary: full sets, secondary: half sets), 5단계 설명, 활용 팁
  3. `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)`
- **Verification**: Preview에서 렌더 확인

### Step 5: ActivityView 업데이트

- **Files**: `ActivityView.swift`
- **Changes**:
  1. `recoveryMapSection`의 SectionGroup title: "Recovery Map" → "Muscle Map"
  2. SectionGroup icon 유지: "figure.stand"
- **Verification**: 탭 제목 변경 확인

### Step 6: 기존 뷰 제거 + 참조 정리

- **Files**: `MuscleMapSummaryCard.swift` (delete), `MuscleMapView.swift` (delete), `TrainingVolumeDetailView.swift` (modify)
- **Changes**:
  1. `MuscleMapSummaryCard.swift` 삭제
  2. `MuscleMapView.swift` 삭제
  3. `TrainingVolumeDetailView.swift`에서 `MuscleMapSummaryCard` 참조 제거
  4. project.yml에서 삭제 파일 반영 불필요 (xcodegen glob 패턴 사용)
- **Verification**: 빌드 성공, 참조 에러 없음

### Step 7: xcodegen + 빌드 검증

- **Files**: `Dailve/project.yml`
- **Changes**: `xcodegen generate` + `scripts/build-ios.sh`
- **Verification**: 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 데이터 없음 (첫 사용자) | Recovery: "Start training to track recovery", Volume: "Start recording workouts to see volume" — 모든 근육 회색 |
| 한쪽 모드만 데이터 있음 | 각 모드 독립 empty state. fatigueStates 배열이 비어있어도 모드 전환 가능 |
| 극단적 볼륨 (30+ sets) | 16+ 상한 클램핑 — 모두 동일 최대 색상 |
| iPad multitasking sizeClass 변경 | `@State mode`는 sizeClass 변경에 영향 없음 |
| 스와이프 vs 근육 탭 제스처 충돌 | DragGesture의 `minimumDistance: 30`으로 탭과 구분. 탭은 Button으로 처리됨 |

## Testing Strategy

- **Unit tests**: 볼륨 색상 threshold 매핑 함수 (0/1-5/6-10/11-15/16+ → 올바른 opacity)
- **Manual verification**:
  - Recovery ↔ Volume 스와이프 전환
  - 페이지 인디케이터 정상 표시
  - 각 모드별 legend/subtitle 전환
  - 근육 탭 → MuscleDetailPopover (양쪽 모드)
  - Volume ⓘ info sheet 표시
  - 기존 Recovery ⓘ info sheet 유지
  - iPad 레이아웃 정상

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 스와이프 제스처 vs ScrollView 충돌 | Low | Medium | `.gesture(DragGesture().onEnded)` — ended만 처리하여 스크롤과 공존 |
| MuscleMapSummaryCard 삭제 시 참조 누락 | Low | High | grep으로 전체 참조 검색 후 삭제 |
| 기존 MuscleMapView NavigationLink 참조 | Low | High | 삭제 전 모든 참조처 확인 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 MuscleRecoveryMapView 코드를 베이스로 확장하는 작업. 새 데이터 fetch 불필요 (weeklyVolume 이미 존재). SVG 렌더링 경로 변경 없음. 색상 함수 분기 + 2개 새 View 추가만으로 구현 가능.
