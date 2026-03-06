---
tags: [watchos, workout, ux, haptic]
category: general
date: 2026-03-06
severity: important
related_files:
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatch/Helpers/WatchEffortInputPolicy.swift
  - DUNEWatchTests/WatchEffortInputPolicyTests.swift
related_solutions: []
---

# Solution: Separate Watch Workout Intensity Input Step with Haptic Feedback

## Problem

워치 운동 종료 화면에서 강도(RPE) 입력이 요약 카드 내부에 함께 있어, Apple Fitness처럼 입력에 집중하는 단계를 제공하지 못했다.

### Symptoms

- 강도 입력이 통계/운동 내역과 섞여 있어 입력 집중도가 낮음.
- 강도 값을 변경할 때 촉각 피드백이 없어 조작 감각이 약함.

### Root Cause

강도 UI가 `SessionSummaryView`의 단일 섹션(`effortSection`)으로만 존재했고, 별도 입력 시트/단계 및 햅틱 정책이 분리돼 있지 않았다.

## Solution

강도 입력을 별도 시트 단계로 분리하고, 디지털 크라운/슬라이더 변경 시 디바운스된 햅틱 클릭을 제공했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/SessionSummaryView.swift` | 요약 카드 + 별도 강도 입력 시트 추가, onAppear 자동 진입, 디지털 크라운 입력 연결, 햅틱 트리거 연결 | Apple Fitness와 유사한 별도 입력 단계 UX 제공 |
| `DUNEWatch/Helpers/WatchEffortInputPolicy.swift` | 강도 clamp/표시 문구/햅틱 디바운스 규칙 분리 | 강도 입력 정책을 재사용 가능하고 테스트 가능한 형태로 분리 |
| `DUNEWatchTests/WatchEffortInputPolicyTests.swift` | 정책 유닛 테스트 추가 | clamp/문구/햅틱 디바운스 회귀 방지 |

## Prevention

### Checklist Addition

- [ ] 워치 입력 UI 변경 시, 크라운 입력과 햅틱 피드백이 함께 동작하는지 확인
- [ ] 입력 정책(범위/디바운스)은 View 내부가 아닌 Helper 정책으로 분리

### Rule Addition (if applicable)

없음.

## Lessons Learned

입력 UI를 요약 화면에 포함시키는 것보다, 사용자가 값을 확정하는 단계를 명시적으로 분리하면 watchOS 상호작용 품질이 높아진다.
