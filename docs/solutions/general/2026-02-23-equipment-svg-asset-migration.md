---
tags: [svg, asset-catalog, equipment, swiftui, image, template-rendering]
category: general
date: 2026-02-23
severity: minor
related_files:
  - Dailve/Presentation/Shared/Extensions/Equipment+View.swift
  - Dailve/Presentation/Exercise/Components/ExerciseDetailSheet.swift
  - Dailve/Presentation/Exercise/Components/ExercisePickerView.swift
  - Dailve/Resources/Assets.xcassets/Equipment/
related_solutions: []
---

# Solution: Equipment SVG Asset 마이그레이션

## Problem

### Symptoms

- `EquipmentIllustrationView.swift` (814줄)이 SwiftUI Canvas로 25종 기구를 직접 그림
- 새 기구 추가 시 Canvas path 코드 작성 필요 (기구당 ~30줄)
- 56pt 고정 크기로 ExerciseDetailSheet에서 너무 작게 표시
- ExercisePickerView 기구 필터 칩에 아이콘 없어 식별 어려움

### Root Cause

Asset Catalog SVG 지원 이전에 구현된 Canvas 기반 벡터 드로잉 방식. SVG 파일로 교체하면 유지보수성과 확장성 대폭 향상.

## Solution

SwiftUI Canvas 일러스트를 Xcode Asset Catalog SVG 이미지로 전환.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Equipment+View.swift` | `svgAssetName` 프로퍼티 추가 | Asset Catalog 경로 매핑 |
| `ExerciseDetailSheet.swift` | `EquipmentIllustrationView` → `Image` 교체 (80pt) | SVG 이미지로 전환 + 크기 확대 |
| `ExercisePickerView.swift` | 기구 필터 칩에 SVG 아이콘 추가 (14pt) | 시각적 식별성 향상 |
| `EquipmentIllustrationView.swift` | 삭제 (814줄) | SVG 교체로 불필요 |
| `Assets.xcassets/Equipment/` | 25개 SVG imageset 생성 | 벡터 에셋 파일 |

### Key Code

```swift
// Equipment+View.swift - Asset Catalog 경로 매핑
var svgAssetName: String {
    switch self {
    case .barbell: "Equipment/equipment.barbell"
    case .dumbbell: "Equipment/equipment.dumbbell"
    // ... 25 cases
    }
}

// ExerciseDetailSheet.swift - 80pt SVG 이미지
Image(exercise.equipment.svgAssetName)
    .resizable()
    .renderingMode(.template)
    .aspectRatio(contentMode: .fit)
    .foregroundStyle(DS.Color.activity)
    .frame(width: 80, height: 80)

// ExercisePickerView.swift - 14pt 칩 아이콘
Image(equipment.svgAssetName)
    .resizable()
    .renderingMode(.template)
    .aspectRatio(contentMode: .fit)
    .frame(width: 14, height: 14)
```

### Asset Catalog 구조

```
Assets.xcassets/Equipment/
├── Contents.json            (provides-namespace: true)
└── equipment.{name}.imageset/
    ├── Contents.json        (preserves-vector-representation + template-rendering-intent)
    └── {name}.svg           (viewBox="0 0 64 64", fill="#000000")
```

### SVG 규격

- **viewBox**: `0 0 64 64` (정사각형 기준)
- **fill**: `#000000` (template 모드에서 tinting 되므로 단색)
- **xmlns**: `http://www.w3.org/2000/svg`
- **스타일**: 기구 실루엣 + 핵심 특징 강조

### Contents.json 필수 속성

```json
{
  "properties": {
    "preserves-vector-representation": true,
    "template-rendering-intent": "template"
  }
}
```

- `preserves-vector-representation`: 모든 해상도에서 벡터 렌더링 유지
- `template-rendering-intent`: SwiftUI `.foregroundStyle()` 자동 적용

## Prevention

### Checklist Addition

- [ ] 새 Equipment case 추가 시 `svgAssetName` switch case + SVG imageset 함께 생성
- [ ] SVG는 viewBox="0 0 64 64", fill="#000000", template mode 호환 확인
- [ ] Asset Catalog namespace (`Equipment/`) 내에 배치

## Lessons Learned

1. **Canvas → SVG 마이그레이션은 순이익**: 814줄 코드 삭제 + 개별 SVG 파일로 분리하여 디자이너 협업 가능
2. **template-rendering-intent 설정이 핵심**: Contents.json에 설정하면 `.renderingMode(.template)` 없이도 동작하지만, 명시적 `.renderingMode(.template)` 추가가 안전
3. **Asset Catalog namespace**: `provides-namespace: true`로 `Equipment/equipment.barbell` 형태의 경로 사용. 다른 에셋과 이름 충돌 방지
4. **SVG fill="#000000" 필수**: template 모드에서 fill color가 tint color로 교체됨. 다색 SVG는 template 모드 비호환
