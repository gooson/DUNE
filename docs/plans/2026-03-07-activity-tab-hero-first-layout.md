---
tags: [activity-tab, hero-card, quick-start, suggested-workout, search, layout]
date: 2026-03-07
category: plan
status: draft
---

# Plan: Activity 탭 Hero-First 레이아웃 재배치

## Summary

Activity 탭의 섹션 순서를 재배치하여 Hero Card를 최상단으로 이동하고,
QuickStart 섹션을 제거한 후 검색 기능을 추천 운동 섹션에 통합합니다.

## Before / After

| Before | After |
|--------|-------|
| ① QuickStart (검색+템플릿+인기/최근) | ① Hero Card (CTA 없음) |
| ② Hero Card + Start Workout CTA | ② Recovery Map + Weekly Stats |
| ③ Injury Warning | ③ Injury Warning |
| ④ Recovery Map + Weekly Stats | ④ 검색+추천 운동+템플릿 (통합) |
| ⑤ Suggested Workout + Training Volume | ⑤ Training Volume |
| ⑥ Recent Workouts ... | ⑥ Recent Workouts ... |

## Affected Files

| 파일 | 변경 | 범위 |
|------|------|------|
| `DUNE/Presentation/Activity/ActivityView.swift` | 섹션 순서 재배치, QuickStart 제거, CTA 제거, recentExerciseIDs/popularExerciseIDs computed 유지 | Major |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | 검색바 추가, 템플릿 스트립 추가, 검색 결과 표시 | Major |
| `DUNE/Presentation/Activity/Components/ActivityQuickStartSection.swift` | 제거 대상 (파일 삭제) | Delete |
| `Shared/Resources/Localizable.xcstrings` | "Quick Start" 키 orphan 정리, "Start Workout" 키 orphan 정리 | Minor |

## Implementation Steps

### Step 1: SuggestedWorkoutSection에 검색+템플릿 통합

**목표**: SuggestedWorkoutSection이 검색바, 검색 결과, 템플릿 스트립을 포함하도록 확장

**변경 사항**:
1. SuggestedWorkoutSection에 새 파라미터 추가:
   - `library: ExerciseLibraryQuerying` — 검색용
   - `recentExerciseIDs: [String]` — 검색 정렬용
   - `popularExerciseIDs: [String]` — 검색 정렬용
   - `onStartTemplate: (WorkoutTemplate) -> Void` — 템플릿 시작
   - `onBrowseAll: () -> Void` — 전체 브라우저 열기
2. `@State private var searchText = ""` 추가
3. `@Query` for `CustomExercise`, `WorkoutTemplate` 추가
4. 검색 로직 이식 (`QuickStartSupport` 활용)
5. View body 변경:
   - 최상단: 검색바 (기존 ActivityQuickStartSection의 searchField 재사용)
   - 검색 중: 검색 결과 표시 (추천 운동 카드 대체)
   - 검색 비활성: 기존 추천 운동 카드 표시
   - 최하단: 템플릿 스트립 (검색 비활성 시 + 템플릿 존재 시)
   - 최하단: "All Exercises" 링크

**Verification**: 빌드 성공, 검색 입력 시 추천 운동 대체 확인

### Step 2: ActivityView 섹션 재배치

**목표**: Hero Card 최상단, CTA 제거, QuickStart 제거, 새 섹션 순서 적용

**변경 사항**:
1. QuickStart SectionGroup 블록 (lines 104-120) 삭제
2. Hero Card VStack에서 Start Workout CTA 버튼 (lines 137-156) 삭제
3. Hero Card를 `!isLoading` 조건 블록 최상단으로 이동 (이미 최상단이므로 CTA 삭제만)
4. 섹션 순서 재배치:
   - Hero Card
   - Recovery Map + Weekly Stats
   - Injury Warning
   - Suggested Workout (이제 검색+템플릿 포함) — 독립 섹션 (iPad side-by-side 해제)
   - Training Volume — 독립 섹션
   - Recent Workouts ...
5. `suggestedWorkoutSection()` 메서드에 새 파라미터 전달 추가
6. iPad side-by-side: Suggested Workout + Training Volume 분리 (각각 독립)

**Verification**: 빌드 성공, 섹션 순서 확인

### Step 3: ActivityQuickStartSection 파일 삭제

**목표**: 더 이상 사용되지 않는 컴포넌트 제거

**변경 사항**:
1. `ActivityQuickStartSection.swift` 파일 삭제
2. `DUNE/project.yml`에서 자동 포함이므로 별도 조치 불필요 (xcodegen glob)

**Verification**: 빌드 성공, QuickStartSection 참조 없음 확인

### Step 4: Localization 정리

**목표**: orphan 키 제거 및 새 문자열 확인

**변경 사항**:
1. "Quick Start" — SectionGroup 타이틀에서만 사용되었음 → xcstrings에서 삭제
2. "Start Workout" — CTA 버튼에서만 사용되었음 → 다른 곳에서도 사용하는지 확인 후 삭제
3. "Search exercises", "Popular", "Recent", "All Exercises", "Templates", "No Exercises" — 기존 문자열 재사용 확인
4. "Custom" 배지 — SuggestedWorkoutSection으로 이식된 exerciseRow에서 사용

**Verification**: xcstrings orphan 없음

## Test Strategy

- **테스트 면제**: SwiftUI View body 변경 (UI 테스트 영역)
- **빌드 검증**: `scripts/build-ios.sh`
- **수동 검증**: 시뮬레이터에서 Activity 탭 레이아웃 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 검색 결과에서 "All Exercises" 접근 경로 유실 | 검색 비활성 시 "All Exercises" 링크 유지 |
| iPad side-by-side 레이아웃 깨짐 | SuggestedWorkout+Volume 분리 후 각각 full-width |
| 템플릿 스트립이 SuggestedWorkout 하단에서 시각적으로 어색 | 기존 스타일 유지, 충분한 spacing |
| QuickStartSupport 유틸리티 unused 될 수 있음 | 검색 로직에서 그대로 사용하므로 유지 |

## Alternatives Considered

1. **검색을 상단 toolbar에 배치**: 기각 — 기존 + 버튼과 충돌, 검색 결과 표시 위치 애매
2. **QuickStart 축소 유지**: 기각 — 사용자가 제거 요청함
3. **Suggested Workout + Volume iPad side-by-side 유지**: 기각 — 검색바가 추가되면 SuggestedWorkout 너비가 좁아져 UX 저하
