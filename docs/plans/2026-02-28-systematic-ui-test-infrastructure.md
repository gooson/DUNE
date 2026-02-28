---
tags: [ui-test, infrastructure, accessibility, ci, smoke-test]
date: 2026-02-28
category: plan
status: approved
---

# Plan: 체계적인 UI Test 인프라 + Smoke Tests

## Summary

UI 테스트 인프라를 재구축하고 전체 화면 Smoke Tests를 작성합니다.

## Implementation Steps

### Step 1: AXID enum 마이그레이션 + 확장
- `DUNEUITests/Helpers/UITestHelpers.swift` 전면 재작성
- 3단계 네이밍 `{tab}-{section}-{element}` 통일
- 기존 ID 마이그레이션 매핑 적용

### Step 2: 앱 코드 accessibility identifier 추가/마이그레이션
- 기존 identifier를 신규 AXID로 교체 (6개 파일)
- 신규 identifier 추가: Dashboard, Activity, Wellness, Life, Settings hero/section

### Step 3: UITestBaseCase 생성
- 공용 setUp (launch argument, 인터럽션 모니터)
- 빈 상태 / seed-mock 두 모드 지원
- iPhone-only guard

### Step 4: TestDataSeeder 구현
- `--seed-mock` launch argument 감지
- SwiftData 레코드 시딩 (ExerciseRecord, BodyCompositionRecord, InjuryRecord, HabitDefinition+Log)
- DUNEApp.swift에 seeder 호출 추가

### Step 5: Smoke Tests 작성 (5개 파일)
- DashboardSmokeTests / ActivitySmokeTests / WellnessSmokeTests / LifeSmokeTests / SettingsSmokeTests

### Step 6: 기존 테스트 마이그레이션
- DailveUITests → NavigationSmokeTests (DashboardSmokeTests에 통합)
- ExerciseUITests → ActivitySmokeTests에 통합
- BodyCompositionUITests → WellnessSmokeTests에 통합
- HealthKitPermissionUITests → Manual/ 폴더로 이동
- LaunchTests → Launch/ 폴더로 이동

### Step 7: Xcode Test Plan 생성
- UITests-CI.xctestplan: Manual 제외
- test-ui.sh 업데이트: test plan 사용

### Step 8: CI workflow 수정
- continue-on-error 제거
- test plan 기반 실행

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| DUNEUITests/Helpers/UITestHelpers.swift | Rewrite | AXID 3단계 체계 |
| DUNEUITests/Helpers/UITestBaseCase.swift | Create | 공용 setUp |
| DUNEUITests/Smoke/DashboardSmokeTests.swift | Create | Dashboard 전체 화면 |
| DUNEUITests/Smoke/ActivitySmokeTests.swift | Create | Activity 전체 화면 |
| DUNEUITests/Smoke/WellnessSmokeTests.swift | Create | Wellness 전체 화면 |
| DUNEUITests/Smoke/LifeSmokeTests.swift | Create | Life 전체 화면 |
| DUNEUITests/Smoke/SettingsSmokeTests.swift | Create | Settings 화면 |
| DUNEUITests/Manual/HealthKitPermissionUITests.swift | Move | Manual 폴더 |
| DUNEUITests/Launch/LaunchUITests.swift | Move+Rename | Launch 폴더 |
| DUNE/App/DUNEApp.swift | Edit | seed-mock 호출 |
| DUNE/App/TestDataSeeder.swift | Create | Mock 데이터 시더 |
| DUNE/Presentation/Dashboard/DashboardView.swift | Edit | AXID 추가 |
| DUNE/Presentation/Activity/ActivityView.swift | Edit | AXID 마이그레이션 |
| DUNE/Presentation/Wellness/WellnessView.swift | Edit | AXID 추가 |
| DUNE/Presentation/Life/LifeView.swift | Edit | AXID 추가 |
| DUNE/Presentation/Settings/SettingsView.swift | Edit | AXID 추가 |
| DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift | Edit | AXID 마이그레이션 |
| DUNE/Presentation/Exercise/ExerciseView.swift | Edit | AXID 마이그레이션 |
| DUNE/Presentation/Injury/InjuryFormSheet.swift | Edit | AXID 마이그레이션 |
| DUNE/Presentation/Life/HabitFormSheet.swift | Edit | AXID 마이그레이션 |
| DUNEUITests/TestPlans/UITests-CI.xctestplan | Create | CI test plan |
| scripts/test-ui.sh | Edit | test plan 사용 |
| .github/workflows/test-ui.yml | Edit | continue-on-error 제거 |
| 기존 UI 테스트 파일 4개 | Delete | 새 구조로 대체 |
