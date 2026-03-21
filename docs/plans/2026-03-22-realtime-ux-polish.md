---
tags: [posture, ux, camera, exercise-picker]
date: 2026-03-22
category: plan
status: draft
---

# Plan: 실시간 분석 UX 개선

## Overview

1. 기본 카메라를 전면(front)으로 변경
2. 운동 선택 버튼에 안내 문구 표시 (미선택 시)

## Affected Files

| File | Change |
|------|--------|
| `Presentation/Posture/RealtimePostureViewModel.swift` | `cameraPosition` 기본값 `.back` → `.front` |
| `Presentation/Posture/RealtimePostureView.swift` | exerciseModeButton에 "Select Exercise" 문구 추가 |
| `Shared/Resources/Localizable.xcstrings` | "Select Exercise" en/ko/ja |

## Implementation Steps

### Step 1: 기본 카메라 전면으로 변경
- `cameraPosition: CameraPosition = .back` → `.front`

### Step 2: 운동 선택 버튼 문구
- 운동 미선택 시: `figure.stand` 아이콘 + "Select Exercise" 문구
- 운동 선택 시: `figure.strengthtraining.traditional` 아이콘 + 운동명 (기존 동작 유지)

### Step 3: Localization
- "Select Exercise" → ko: "운동 선택", ja: "エクササイズ選択"

## Test Strategy

- 빌드 통과 확인
- 실기기: 전면 카메라로 시작되는지 확인
- 실기기: 운동 미선택 시 "운동 선택" 문구 보이는지 확인

## Risks

- 전면 카메라 기본 시 뒤에서 찍어야 하는 운동(squat side view)은 카메라 전환 필요 — 이미 전환 버튼 존재
