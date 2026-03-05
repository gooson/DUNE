---
tags: [widget, widgetkit, app-group, data-sharing, extension]
category: architecture
date: 2026-03-05
severity: important
related_files:
  - Shared/WidgetScoreData.swift
  - DUNE/Data/Services/WidgetDataWriter.swift
  - DUNEWidget/WidgetScoreProvider.swift
  - DUNE/project.yml
related_solutions: []
---

# Solution: WidgetKit Extension Data Sharing via App Group

## Problem

앱을 열지 않고 홈 화면에서 3개 건강 점수(Condition, Training Readiness, Wellness)를 확인할 수 있어야 함. 각 점수는 서로 다른 ViewModel에서 독립적으로 계산되며, Widget Extension은 별도 프로세스로 실행됨.

### Root Cause

Widget Extension은 main app과 메모리를 공유하지 않으므로, UseCase 의존성(HRV baseline, sleep 데이터 등)을 extension에서 재현하는 것은 비용이 높음.

## Solution

Main app에서 계산된 점수를 **App Group UserDefaults**를 통해 Widget에 전달하는 패턴.

### Architecture

```
Main App (3 ViewModels)
  └─ WidgetDataWriter.writeXxxScore()
       └─ UserDefaults(suiteName: appGroup)
            └─ WidgetScoreData (Codable JSON)

Widget Extension
  └─ WidgetScoreProvider (TimelineProvider)
       └─ UserDefaults(suiteName: appGroup)
            └─ WidgetScoreData (Codable JSON)
```

### Key Design Decisions

1. **Merge-on-write**: 각 VM이 자기 점수만 업데이트, 나머지는 기존값 보존
2. **rawValue 전달**: Domain 모델의 Status enum을 rawValue String으로 직렬화 → widget에서 String 기반 매핑
3. **별도 DesignSystem**: Widget은 main app의 DS를 import 불가 → `WidgetDS` 서브셋 생성
4. **Shared source file**: `WidgetScoreData`는 `Shared/` 디렉토리에 두고 양쪽 target membership

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Shared/WidgetScoreData.swift` | CREATE | App ↔ Widget 공유 Codable 모델 |
| `DUNE/Data/Services/WidgetDataWriter.swift` | CREATE | Main app → App Group 저장 |
| `DUNEWidget/*.swift` | CREATE | Widget Extension target 전체 |
| `DUNE/project.yml` | MODIFY | DUNEWidget target + App Group entitlements |
| `*ViewModel.swift` (3 files) | MODIFY | 점수 계산 후 WidgetDataWriter 호출 |

### Key Code

```swift
// Merge-on-write pattern — preserve other VMs' scores
static func writeConditionScore(_ score: ConditionScore?) {
    guard let defaults = sharedDefaults() else { return }
    let existing = loadExisting(from: defaults)
    let updated = WidgetScoreData(
        conditionScore: score?.score,
        conditionStatusRaw: score?.status.rawValue,
        conditionMessage: score?.narrativeMessage,
        readinessScore: existing?.readinessScore,  // preserve
        ...
        updatedAt: Date()
    )
    save(updated, to: defaults)
}
```

## Prevention

### Checklist Addition

- [ ] Widget Extension target에 새 source 추가 시 App Group entitlement 확인
- [ ] Domain 모델 변경 시 WidgetScoreData 필드 동기화 확인
- [ ] 새 점수 타입 추가 시 WidgetDataWriter에 write 메서드 추가

## Lessons Learned

- Widget Extension은 main app의 Domain/UseCase 재사용이 어려움 → 계산 결과만 전달
- App Group UserDefaults는 프로세스 간 공유에 적합하지만, race condition 방어 필요 (MVP에서는 @MainActor 직렬화로 충분)
- xcodegen `app-extension` 타입은 `INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier` 설정 필요
