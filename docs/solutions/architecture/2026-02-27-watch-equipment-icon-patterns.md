---
tags: [watch, equipment, icon, asset-catalog, template-rendering, sf-symbol, pre-resolve, codable, cloudkit, rawvalue]
date: 2026-02-27
category: architecture
status: implemented
---

# Watch Equipment Icon Architecture — Asset Catalog + Pre-resolve Pattern

## Problem

Watch 앱에 25개 AI 생성 장비 아이콘을 통합하면서 여러 문제가 동시 발생:

### 증상 1: 아이콘이 표시되지 않거나 단색 사각형으로 표시
- **원인**: Asset catalog 폴더에 `"provides-namespace": true` 누락 → `Image("Equipment/equipment.barbell")` 경로 실패
- **원인**: PNG에 불투명 배경 → `.renderingMode(.template)`가 전체 사각형을 tint

### 증상 2: 제네릭 장비(machine, bodyweight) 아이콘이 관련 없는 운동에 표시
- **원인**: "machine"은 레그프레스/사이클링/스텝클라이머 등 다양한 운동을 포함하는데, 단일 아이콘(케이블 로우 핸들)으로 대표 불가

### 증상 3: 리뷰에서 per-render switch dispatch, DRY 위반, stringly-typed persistence 지적
- **원인**: `EquipmentIcon.assetName(for:)` + `sfSymbol(for:)`가 computed property body에서 매 렌더마다 호출
- **원인**: 동일 `@ViewBuilder` 패턴이 ExerciseTileView와 TemplateCardView에 중복
- **원인**: `TemplateEntry.equipment: String?`이 Equipment.rawValue를 문자열로 저장 — rename 시 silent break

## Solution

### 1. Asset Catalog 구성

```
Equipment/
├── Contents.json          ← "provides-namespace": true 필수
├── equipment.barbell.imageset/
│   ├── Contents.json      ← "template-rendering-intent": "template"
│   └── equipment.barbell.png  ← 투명 배경 PNG, 128×128
└── ... (25 imagesets)
```

**핵심**: 투명 배경 PNG + template rendering mode = foregroundStyle tint 적용

### 2. Pre-resolve Pattern (EquipmentIcon.Resolved)

```swift
enum EquipmentIcon {
    enum Resolved {
        case asset(String)
        case symbol(String)
    }

    static func resolve(for equipmentRawValue: String?) -> Resolved {
        if let eq = equipmentRawValue,
           let asset = assetName(for: eq) {
            return .asset(asset)
        }
        return .symbol(sfSymbol(for: equipmentRawValue))
    }
}
```

View init에서 1회 resolve → body에서는 switch-free rendering:

```swift
struct EquipmentIconView: View {
    let size: CGFloat
    private let resolved: EquipmentIcon.Resolved

    init(equipment: String?, size: CGFloat) {
        self.size = size
        self.resolved = EquipmentIcon.resolve(for: equipment)
    }
}
```

### 3. 제네릭 장비 → SF Symbol Fallback

특정 장비(barbell, dumbbell, kettlebell...)만 커스텀 아이콘 매핑.
제네릭 카테고리(machine, cable, bodyweight, other)는 `default: return nil` → SF Symbol fallback.

### 4. Equipment.other → nil 매핑

```swift
// WatchSessionManager
equipment: def.equipment == .other ? nil : def.equipment.rawValue
```

"equipment 없음"(nil)과 "unknown rawValue"(default 분기)를 의미적으로 구분.

### 5. CodingKeys + 경고 주석

CloudKit 영구 저장되는 TemplateEntry에 explicit CodingKeys 추가:
```swift
enum CodingKeys: String, CodingKey {
    case id, exerciseDefinitionID, exerciseName, ...
}
```

rawValue rename 위험에 대한 WARNING 주석으로 미래 개발자에게 전달.

## Prevention

1. **Asset catalog 폴더에 네임스페이스 설정 체크리스트**: 새 에셋 폴더 생성 시 `"provides-namespace": true` 확인
2. **AI 생성 아이콘은 투명 배경 확인 후 통합**: PIL brightness threshold 스크립트 활용
3. **제네릭 장비 카테고리는 커스텀 아이콘 매핑 금지**: 하나의 아이콘으로 대표할 수 없는 카테고리는 SF Symbol fallback 사용
4. **icon 렌더링은 EquipmentIconView 단일 컴포넌트**: 새 뷰에서 직접 EquipmentIcon.assetName/sfSymbol 호출 금지
5. **rawValue 저장 필드에 CodingKeys + WARNING 주석**: rename 위험이 있는 enum rawValue 저장 시 필수

## Lessons Learned

1. **per-render switch는 누적 비용이 큼**: 50+ 운동 리스트에서 프레임당 100+ switch — View init에서 pre-resolve하는 습관 필요
2. **DS 토큰 통일 시 시맨틱 축소 주의**: `.title` → `.title2`로 자동 치환하면 rest timer 같은 primary focus 요소가 축소됨. 용도별 토큰 분리 필요
3. **Codable struct에 새 필드 추가는 간단하지만, rawValue 저장은 숨겨진 계약**: Optional 필드 추가는 backward-compatible이지만, 저장된 rawValue가 rename되면 모든 디바이스에서 silent break
4. **Static let > static func for constant gradients**: SwiftUI body에서 호출되는 함수가 매번 새 인스턴스를 생성하면 Watch 성능에 영향
