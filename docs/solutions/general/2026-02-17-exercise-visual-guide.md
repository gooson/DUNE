---
tags: [swiftui, canvas, muscle-map, exercise, visual-guide, equipment, localization, korean-english]
category: general
date: 2026-02-17
severity: important
related_files:
  - Dailve/Presentation/Shared/Components/ExerciseMuscleMapView.swift
  - Dailve/Presentation/Shared/Components/EquipmentIllustrationView.swift
  - Dailve/Presentation/Shared/Components/MuscleMapData.swift
  - Dailve/Presentation/Exercise/Components/ExerciseDetailSheet.swift
  - Dailve/Presentation/Exercise/Components/ExercisePickerView.swift
  - Dailve/Presentation/Shared/Extensions/Equipment+View.swift
related_solutions: []
---

# Solution: Exercise Visual Guide (근육 맵 + 기구 일러스트 + 한/영 병기)

## Problem

### Symptoms

- 운동 등록 시 "체스트 프레스 머신" 같은 운동이 어떤 동작인지, 어떤 기구를 사용하는지 직관적으로 이해하기 어려움
- 운동 이름이 영어 only 또는 한국어 only로 표시되어 검색/이해에 불편
- 어떤 근육을 사용하는지 텍스트로만 나열되어 시각적 이해도 낮음

### Root Cause

- ExerciseDetailSheet이 텍스트 기반 정보만 제공 (이름, 근육 리스트, 카테고리)
- 기구(Equipment)에 대한 시각적 표현이 전무
- 근육 정보가 텍스트 태그로만 표시되어 신체 어디인지 직관적 파악 불가
- 한국어/영어 병기 패턴이 일관적이지 않음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| MuscleMapData.swift (NEW) | MuscleMapView에서 공유 데이터 추출 | ExerciseMuscleMapView와 MuscleMapView 간 데이터 재사용 |
| ExerciseMuscleMapView.swift (NEW) | 전면/후면 근육 맵 (주동근/보조근 하이라이트) | 운동별 타겟 근육을 시각적으로 표시 |
| EquipmentIllustrationView.swift (NEW) | Canvas 기반 8종 기구 벡터 일러스트 | 기구 형태를 시각적으로 표시 |
| ExerciseDetailSheet.swift | 근육 맵 + 기구 일러스트 섹션 추가 | 정보 시트에 시각 가이드 통합 |
| ExercisePickerView.swift | 한/영 병기, 한국어 근육/기구명 | 피커에서도 이해도 향상 |
| Equipment+View.swift | equipmentDescription 추가 | 기구별 한국어 설명 |
| ExerciseViewModel.swift | localizedType 필드 + DI 패턴 | 한국어 운동명 표시 + 테스트 가능 |

### Key Code

**1. 공유 근육 데이터 추출 패턴**

기존 MuscleMapView 전용 데이터를 MuscleMapData enum으로 추출하여 두 뷰에서 재사용:

```swift
struct MuscleMapItem: Identifiable {
    let id: String  // "\(muscle.rawValue)-\(position.x)-\(position.y)"
    let muscle: MuscleGroup
    let position: CGPoint  // Normalized (0...1)
    let size: CGSize       // Normalized (0...1)
    let cornerRadius: CGFloat
}

enum MuscleMapData {
    static let frontMuscles: [MuscleMapItem] = [...]
    static let backMuscles: [MuscleMapItem] = [...]
    static func bodyOutline(width:height:) -> Path { ... }
}
```

**2. SwiftUI Canvas 벡터 일러스트**

외부 이미지 에셋 없이 SwiftUI Canvas API로 8종 기구를 프로그래밍적으로 그림:

```swift
Canvas { context, canvasSize in
    let w = canvasSize.width
    let h = canvasSize.height
    guard w > 0, h > 0 else { return }
    draw(equipment, in: context, width: w, height: h)
}
.frame(width: size, height: size)
```

**3. Set 캐싱으로 O(1) 근육 조회**

```swift
private var primarySet: Set<MuscleGroup> { Set(primaryMuscles) }
private var secondarySet: Set<MuscleGroup> { Set(secondaryMuscles) }
```

**4. 한/영 병기 패턴**

```swift
// Primary: Korean, Subtitle: English
Text(exercise.localizedName)      // 벤치 프레스
    .font(.title3.weight(.semibold))
Text(exercise.name)               // Bench Press
    .font(.caption)
    .foregroundStyle(.secondary)
```

## Prevention

### Checklist Addition

- [ ] 새 운동 정보 UI 추가 시 한/영 병기 패턴 적용 여부 확인
- [ ] 근육/기구 관련 데이터 표시 시 MuscleMapData/Equipment+View 기존 자산 재사용 확인
- [ ] Canvas 드로잉 코드에 zero-size guard 포함 여부 확인
- [ ] ForEach에서 Identifiable 프로토콜 사용 (offset ID 금지)
- [ ] ViewModel에서 싱글턴 직접 참조 대신 프로토콜 주입 패턴 사용

### Rule Addition

없음 (기존 규칙으로 충분: swift-layer-boundaries, input-validation)

## Lessons Learned

1. **기존 데이터 재사용 우선**: MuscleMapView의 근육 위치 데이터를 새로 만들지 않고 추출하여 공유함으로써 일관성 확보 + 코드 절감
2. **Canvas > 에셋 이미지**: SF Symbols로 부족한 시각 표현은 SwiftUI Canvas로 프로그래밍적으로 해결. 외부 에셋 의존 없이 테마 색상과 자연스럽게 통합
3. **비주얼 맵이 텍스트 태그를 대체**: 근육 맵 추가 후 텍스트 기반 muscle chips 섹션이 완전히 중복됨. 시각 컴포넌트가 있으면 텍스트 리스트는 제거 가능
4. **정규화 좌표계(0...1)**: 근육 위치를 정규화 좌표로 저장하면 어떤 크기의 컨테이너에서도 비례적으로 렌더링 가능
5. **리뷰에서 발견된 DIP 위반 즉시 수정**: ViewModel이 싱글턴을 직접 참조하면 테스트 불가. 프로토콜 주입 + optional default parameter로 기존 코드 변경 최소화
