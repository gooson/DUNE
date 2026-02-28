---
tags: [settings, preferences, theme, workout-defaults, exercise-defaults]
date: 2026-02-28
category: plan
status: approved
---

# Plan: Settings Hub

## Summary

Today 탭 toolbar gear icon → Settings push navigation. 전체 설정 허브 구현.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Data/Persistence/Models/ExerciseDefaultRecord.swift` | NEW | SwiftData @Model — 운동별 기본 무게 |
| `Data/Persistence/WorkoutSettingsStore.swift` | NEW | UserDefaults 싱글턴 — 글로벌 운동 기본값 |
| `Presentation/Settings/SettingsView.swift` | NEW | 설정 메인 화면 |
| `Presentation/Settings/Components/ExerciseDefaultsListView.swift` | NEW | 운동별 기본값 목록 |
| `Presentation/Settings/Components/ExerciseDefaultEditView.swift` | NEW | 운동별 기본값 편집 |
| `Presentation/Settings/Components/ThemePickerSection.swift` | NEW | 테마 선택 UI (Coming Soon) |
| `Presentation/Dashboard/DashboardView.swift` | MODIFY | toolbar gear icon + navigationDestination |
| `Presentation/Shared/WorkoutDefaults.swift` | MODIFY | Store에서 읽기 |
| `App/DUNEApp.swift` | MODIFY | ExerciseDefaultRecord를 ModelContainer에 등록 |
| `DUNETests/WorkoutSettingsStoreTests.swift` | NEW | 설정 저장소 테스트 |

## Implementation Steps

### Step 1: Data Layer
1. ExerciseDefaultRecord @Model 생성
2. WorkoutSettingsStore 싱글턴 생성
3. DUNEApp ModelContainer에 ExerciseDefaultRecord 등록
4. WorkoutDefaults를 Store에서 읽도록 수정

### Step 2: Presentation Layer
1. SettingsView 생성 (Form 기반)
2. ThemePickerSection 생성 (Desert Warm 선택됨 + Coming Soon 표시)
3. ExerciseDefaultsListView 생성
4. ExerciseDefaultEditView 생성

### Step 3: Integration
1. DashboardView에 toolbar gear icon 추가
2. navigationDestination으로 SettingsView push

### Step 4: Tests
1. WorkoutSettingsStore 테스트

### Step 5: Build + Ship
1. xcodegen + build verification
2. Commit + PR
