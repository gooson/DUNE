---
tags: [watch, routine, equipment-icon, legacy-data, template-entry, enrichment, cloudkit-migration]
category: general
date: 2026-02-28
severity: important
related_files:
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNE/Data/Persistence/Models/WorkoutTemplate.swift
  - DUNEWatch/Views/Components/EquipmentIcon.swift
related_solutions: []
---

# Solution: Watch 루틴 장비 아이콘이 generic fallback으로 표시되는 문제

## Problem

### Symptoms

- Watch 루틴 카드에서 모든 운동이 동일한 generic figure 아이콘(`figure.strengthtraining.traditional`) 표시
- 랫 풀다운(latPulldownMachine)과 시티드 케이블 로우(cable) 모두 같은 아이콘
- 개별 운동(Popular/Recent)의 아이콘은 정상 표시

### Root Cause

`TemplateEntry`에 `equipment: String?` 필드가 나중에 추가됨. 이전에 생성된 루틴 템플릿의 entries는 `equipment == nil`로 CloudKit/SwiftData에 저장되어 있음.

`EquipmentIcon.resolve(for: nil)`은 generic SF Symbol fallback을 반환하므로 모든 운동이 동일한 아이콘으로 표시됨.

새로 생성하는 템플릿은 `CreateTemplateView`에서 `exercise.equipment.rawValue`를 정확히 설정하지만, 기존 데이터는 마이그레이션되지 않음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/CarouselHomeView.swift` | `enrichedEntries()` 추가, `rebuildCards()`에서 호출 | nil equipment를 exercise library에서 보충 |

### Key Code

```swift
// rebuildCards() 시작 부분에서 equipment lookup dict 구성
var equipmentByID: [String: String] = [:]
for exercise in library {
    guard let eq = exercise.equipment, !eq.isEmpty else { continue }
    equipmentByID[exercise.id] = eq
}

// 템플릿 카드 생성 시 enrichment 적용
let entries = Self.enrichedEntries(template.exerciseEntries, equipmentByID: equipmentByID)

// enrichment 함수 — nil equipment만 보충, 기존 값은 보존
private static func enrichedEntries(
    _ entries: [TemplateEntry],
    equipmentByID: [String: String]
) -> [TemplateEntry] {
    entries.map { entry in
        guard entry.equipment == nil else { return entry }
        guard let equipment = equipmentByID[entry.exerciseDefinitionID] else { return entry }
        var enriched = entry
        enriched.equipment = equipment
        return enriched
    }
}
```

### Design Decisions

1. **Display-time enrichment (not data migration)**: SwiftData/CloudKit 데이터를 직접 수정하지 않고 표시 시점에 보충. Watch에서 SwiftData 쓰기를 최소화하는 원칙 유지
2. **Dictionary lookup (O(1))**: library를 dict로 변환하여 template entry 수에 비례하는 성능만 소모
3. **enriched entries가 downstream으로 전파**: CarouselCard → WorkoutSessionTemplate → WorkoutPreviewView까지 enriched data가 흐름

## Prevention

### Checklist Addition

- [ ] 새 optional 필드를 Codable struct에 추가할 때 기존 데이터에 nil인 경우의 display 동작 검증
- [ ] CloudKit 영구 저장 모델에 필드 추가 시 "legacy data enrichment" 전략 수립

### Rule Addition (if applicable)

없음 — 기존 Correction #164 (Codable struct rawValue 경고)가 유사 맥락을 커버함.

## Lessons Learned

1. **Optional 필드 추가 != 마이그레이션 완료**: Codable struct에 optional 필드를 추가하면 새 데이터는 정상이지만, 기존 데이터는 nil 상태로 영구 잔존. CloudKit 환경에서는 서버 데이터가 업데이트되지 않는 한 계속 nil
2. **Display-time enrichment 패턴**: 데이터를 수정하기 어려운 경우(CloudKit, Watch readonly) 표시 시점에 다른 데이터 소스에서 보충하는 패턴이 안전하고 효과적
3. **Exercise library가 Watch의 ground truth**: Watch는 iOS에서 sync된 exercise library를 가지고 있으므로, template 데이터의 결손을 library에서 채울 수 있음
