---
tags: [posture, navigation, ui, wellness]
date: 2026-03-16
category: plan
status: draft
---

# 자세평가 섹션 듀얼 진입점 + 목록 탭 네비게이션

## Problem Statement

현재 `PostureAssessmentLinkView`(WellnessView 내 자세평가 섹션)에는:
1. 카메라 촬영(PostureCaptureView)만 진입점이 있고, 실시간 분석(RealtimePostureView) 진입점이 없음
2. 기존 평가 목록을 탭하면 상세로 이동하는 경로가 없음 — "View All"만 있어 히스토리 목록으로만 이동

## Goal

- 자세평가 섹션에 "카메라 촬영"과 "실시간 분석" 두 개의 액션을 분리 배치
- 최근 평가 목록(records)을 개별 탭하면 PostureDetailView로 네비게이션

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Wellness/WellnessView.swift` | `PostureAssessmentLinkView`에 `onRealtime` 콜백 추가, 목록 탭 → NavigationLink |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 번역 추가 (필요 시) |

## Implementation Steps

### Step 1: PostureAssessmentLinkView 수정

1. `onRealtime` 콜백 파라미터 추가
2. 빈 상태(no records): 카메라 촬영 + 실시간 분석 두 버튼을 나란히 배치
3. 기존 기록 있을 때:
   - 상단: "Camera Capture" / "Realtime Analysis" 두 개 액션 버튼
   - 최근 기록(최대 3개): 각 행을 `NavigationLink(value: PostureRecordDestination(id:))`로 감싸서 탭 시 상세 이동
4. 기존 "View All" 네비게이션은 유지

### Step 2: WellnessView 연결

- `PostureAssessmentLinkView`에 `onRealtime: { isShowingRealtimePosture = true }` 전달
- `PostureRecordDestination` 네비게이션은 이미 PostureHistoryView에 정의됨 → WellnessView에도 `.navigationDestination(for: PostureRecordDestination.self)` 추가 필요

### Step 3: Localization

- 새 문자열 있으면 en/ko/ja 등록
- 기존 "Realtime Analysis" 등은 이미 xcstrings에 등록됨

## Test Strategy

- 빌드 검증: `scripts/build-ios.sh`
- PostureRecordDestination 네비게이션이 WellnessView에서도 동작하는지 확인
- 기존 PostureHistoryView의 네비게이션과 충돌 없는지 확인

## Risks & Edge Cases

- `PostureRecordDestination`이 WellnessView와 PostureHistoryView 양쪽에 `.navigationDestination`이 등록되면 push 스택에서 중복 등록 충돌 가능 → WellnessView에서는 `@Query` records를 직접 가지고 있으므로 독립적으로 destination 정의 가능
- records가 0개일 때 두 버튼 레이아웃이 깨지지 않는지 확인
