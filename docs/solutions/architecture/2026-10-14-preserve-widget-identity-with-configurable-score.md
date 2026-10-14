---
tags: [widgetkit, app-intents, widget-identity, ios27, health-privacy]
category: architecture
date: 2026-10-14
severity: important
related_files: [DUNEWidget/SingleMetricWidget.swift, DUNEWidget/WellnessDashboardWidget.swift, Shared/WidgetScoreData.swift]
related_solutions: []
---

# Solution: 기존 위젯을 유지하며 설정 가능한 점수 위젯 추가

## Problem

### Symptoms

기존 DUNE Today는 `StaticConfiguration`으로 세 점수를 보여준다. 사용자가 하나의 점수만 큰 세로형 위젯에서 확인하려면 별도 설정 가능한 위젯이 필요하다.

### Root Cause

기존 위젯의 kind 또는 설정 타입을 바꾸면 설치된 위젯의 정체성과 호환성이 달라진다. 선택한 점수만 보여 주는 요구를 기존 위젯 변경으로 처리하기에 적절하지 않다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNEWidget/WellnessDashboardWidget.swift` | 기존 위젯 뒤에 새 위젯 등록 | 기존 kind와 설정 보존 |
| `DUNEWidget/SingleMetricWidget.swift` | 별도 AppIntentConfiguration, provider, 크기별 view | 점수 선택 및 세로형 크기 지원 |
| `Shared/WidgetScoreData.swift` | 점수·상태·메시지를 함께 선택 | 필드 혼합 방지 및 단위 테스트 |
| `Shared/WidgetSurfaceAccessibility.swift` | 별도 kind와 family 계약 | 회귀 검사 |

### Key Code

```swift
AppIntentConfiguration(kind: "DUNESingleMetricWidget", intent: SingleMetricConfiguration.self,
                       provider: SingleMetricProvider()) { entry in
    SingleMetricWidgetView(entry: entry)
}
```

새 위젯은 기존 App Group 파일을 읽고 시간 단위로 갱신한다. 점수·상태·설명에는 `privacySensitive()`를 적용한다. 선택 점수별 갱신 시간이 없어 공유 갱신 시간은 표시하지 않는다. 링 트랙은 semantic primary 색상으로 명암 모드에 대응한다.

## Prevention

- 기존 widget kind와 `StaticConfiguration`을 변경하지 않는 계약 테스트를 유지한다.
- 위젯 선택 항목을 늘릴 때 공유 데이터 선택 함수와 AppEnum 매핑을 함께 확인한다.
- 새 WidgetKit family 추가 시 SDK 가용성과 위젯 갤러리 렌더링을 확인한다.

## Lessons Learned

WidgetKit의 새 크기를 기존 설치 위젯에 강제로 적용할 필요가 없다. 별도 kind가 사용자 선택을 제공하면서 기존 설치 상태를 보존한다.

## Pending Verification

호스트 충돌을 피하기 위해 이번 작업에서는 Xcode 빌드, 테스트, 시뮬레이터/UI 캡처를 실행하지 않았다. 병합 전 새 위젯의 gallery 설정, small/medium/large/portrait 배치, 명암 모드, 개인정보 가림 및 디자인맵 새 캡처를 검증한다.
