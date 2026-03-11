---
tags: [testing, ci, ai-prompt, healthkit, watchos, rpe, localization]
date: 2026-03-12
category: solution
status: implemented
---

# CI Nightly Test Failures Fix (Run #22971198790)

## Problem

CI nightly run에서 6건 테스트 실패:
- iOS unit tests: 2건 (AIWorkoutTemplateGenerator, DashboardViewModel)
- Watch UI tests: 4건 (SetInputSheet overflow)

## Root Causes & Solutions

### 1. AI Prompt: `localizedName` vs `name` (AIWorkoutTemplateGenerator.swift)

**문제**: `topRecentExercises()`가 `definition.localizedName`을 사용하여 한국어 locale에서 "푸시업"을 반환. AI 프롬프트 생성 컨텍스트에서는 영어 canonical name이 필요.

**해결**: `definition.localizedName` → `definition.name`

**교훈**: AI 프롬프트에 전달하는 운동 이름은 항상 canonical `name`(영어)을 사용. `localizedName`은 사용자 대면 UI 전용.

### 2. Test Snapshot: Empty SharedHealthSnapshot (DashboardViewModelTests.swift)

**문제**: 테스트가 `makeEmptySharedSnapshot()`을 주입했지만, `safeHRVFetch()`는 snapshot이 non-nil이면 snapshot 경로를 사용. 빈 snapshot에서 빈 metrics를 반환하여 `sortedMetrics.contains { $0.category == .hrv }` 실패.

**해결**: 테스트의 shared snapshot에 MockHRVService와 동일한 HRV/RHR 데이터를 포함.

**교훈**: `safeHRVFetch()`는 snapshot non-nil이면 snapshot 우선. 테스트에서 snapshot 경로를 사용하려면 snapshot에 기대 데이터를 포함해야 함. `makeEmptySharedSnapshot()` != "snapshot 경로를 타지 않겠다"가 아니라 "빈 데이터로 snapshot 경로를 탄다"는 의미.

### 3. Watch SetInputSheet Overflow (SetInputSheet.swift)

**문제**: RPE 피커 추가 후 VStack 콘텐츠가 watch 화면을 초과. 하단 요소(RPE, Done 버튼)가 off-screen.

**해결**: VStack을 ScrollView로 래핑. `.digitalCrownRotation`은 ScrollView 외부에서 `.focusable(true)` + `.focused()`와 함께 유지.

**주의사항**: ScrollView와 `.digitalCrownRotation` 공존 시, focus system이 Crown을 weight input에 라우팅. 스크롤은 touch gesture로 수행. 기기별 테스트로 Crown 동작 확인 권장.

## Prevention

1. **AI 프롬프트 코드 리뷰 시**: `localizedName` 사용을 발견하면 AI 컨텍스트인지 UI 컨텍스트인지 확인
2. **SharedHealthSnapshot 테스트**: snapshot 경로를 테스트할 때는 반드시 기대 데이터가 포함된 snapshot 사용
3. **Watch UI 레이아웃 변경 시**: 새 컨트롤 추가 후 smallest watch (41mm) 시뮬레이터에서 모든 요소 접근 가능 여부 확인
