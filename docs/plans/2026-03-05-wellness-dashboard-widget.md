---
tags: [widget, widgetkit, condition, readiness, wellness]
date: 2026-03-05
category: plan
status: approved
---

# Plan: Wellness Dashboard Widget

## Overview

WidgetKit Extension을 추가하여 홈 화면에서 Condition, Training Readiness, Wellness 3개 점수를 한눈에 확인할 수 있게 합니다. Main app에서 계산된 점수를 App Group UserDefaults를 통해 widget에 공유합니다.

## Architecture Decision

**Score 계산 위치**: Main App → App Group UserDefaults → Widget 읽기
- UseCase 의존성(HRV baseline, sleep 데이터 등)이 복잡하므로 extension에서 재현하지 않음
- Main app이 foreground 진입 시 + HealthKit observer delivery 시 점수 갱신 → UserDefaults에 저장
- Widget TimelineProvider가 UserDefaults에서 읽어 표시

## App Group

- Identifier: `group.com.raftel.dailve`
- 용도: Main app ↔ Widget Extension 간 UserDefaults 공유

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/project.yml` | MODIFY | Widget Extension target + scheme 추가, App Group entitlement |
| `DUNE/Resources/DUNE.entitlements` | MODIFY | App Group 추가 |
| `DUNEWidget/WellnessDashboardWidget.swift` | CREATE | Widget definition + TimelineProvider |
| `DUNEWidget/WellnessDashboardEntry.swift` | CREATE | TimelineEntry 모델 |
| `DUNEWidget/Views/SmallWidgetView.swift` | CREATE | Small (2×2) 레이아웃 |
| `DUNEWidget/Views/MediumWidgetView.swift` | CREATE | Medium (4×2) 레이아웃 |
| `DUNEWidget/Views/LargeWidgetView.swift` | CREATE | Large (4×4) 레이아웃 |
| `DUNEWidget/WidgetScoreProvider.swift` | CREATE | App Group UserDefaults 읽기 |
| `DUNEWidget/Resources/DUNEWidget.entitlements` | CREATE | Widget entitlements |
| `DUNEWidget/DesignSystem.swift` | CREATE | Widget용 DS subset (score colors) |
| `Shared/WidgetScoreData.swift` | CREATE | App ↔ Widget 공유 데이터 구조 |
| `DUNE/Data/Services/WidgetDataWriter.swift` | CREATE | Main app → App Group 점수 저장 |
| `DUNE/App/DUNEApp.swift` | MODIFY | WidgetDataWriter 연결 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | MODIFY | 점수 갱신 시 Widget 데이터 저장 |
| `DUNETests/WidgetScoreDataTests.swift` | CREATE | 공유 데이터 모델 테스트 |
| `DUNETests/WidgetDataWriterTests.swift` | CREATE | 저장/읽기 테스트 |

## Implementation Steps

### Step 1: Shared Data Model
- `Shared/WidgetScoreData.swift`: App Group으로 공유할 Codable 모델
- App Group identifier 상수 정의

### Step 2: App Group Entitlements
- `DUNE.entitlements`에 `com.apple.security.application-groups` 추가
- `DUNEWidget.entitlements` 생성

### Step 3: WidgetDataWriter (Main App)
- `UserDefaults(suiteName:)`에 WidgetScoreData JSON 저장
- `WidgetCenter.shared.reloadAllTimelines()` 호출

### Step 4: DashboardViewModel 연결
- `loadData()` 완료 시 WidgetDataWriter로 점수 저장
- ActivityViewModel, WellnessViewModel에서도 각자 점수 저장

### Step 5: Widget Extension Target
- `project.yml`에 `DUNEWidget` target 추가 (type: app-extension)
- Widget scheme 추가
- build-ios.sh는 DUNE scheme이 all targets 빌드하므로 dependency로 추가

### Step 6: Widget Views
- Small: 3개 점수 숫자 + worst status label
- Medium: 3개 점수 나란히 + status + 도트 인디케이터
- Large: 3개 점수 + narrative message + 업데이트 시간

### Step 7: Unit Tests
- WidgetScoreData Codable 라운드트립
- WidgetDataWriter 저장/로드 검증

## Timeline Policy

- `.after(date)`: 다음 정시(매시 정각)에 새로고침
- Main app이 점수 갱신 시 `WidgetCenter.shared.reloadAllTimelines()` 호출로 즉시 반영
