---
tags: [rpe, slider, ux, watchos, ios, help]
date: 2026-03-12
category: plan
status: draft
---

# RPE 슬라이더 + 문맥 도움말 리디자인

## Problem

세트 종료 후 RPE 입력이 직관적이지 않음. 숫자(6.0-10.0)만 나열된 버튼은 각 값의 의미를 전달하지 못함.

## Solution Overview

1. iOS/Watch RPE 피커를 슬라이더 + 색상 스펙트럼으로 교체
2. `?` 버튼 → 도움말 시트로 RPE 개념 설명 제공

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Presentation/Exercise/Components/SetRPEPickerView.swift` | 리디자인 (버튼→슬라이더) |
| `DUNEWatch/Views/Components/WatchSetRPEPickerView.swift` | 리디자인 (그리드→슬라이더) |
| `DUNE/Presentation/Exercise/Components/RPEHelpSheet.swift` | 신규 |
| `DUNEWatch/Views/Components/WatchRPEHelpSheet.swift` | 신규 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja |
| `DUNEWatch/Resources/Localizable.xcstrings` | Watch 전용 새 문자열 en/ko/ja |

## Implementation Steps

### Step 1: iOS SetRPEPickerView 슬라이더 리디자인

- 기존 9-button HStack → `Slider(value:in:step:)` (6.0...10.0, 0.5)
- `.tint()` — 현재 값에 따라 rpeColors 매핑 색상 적용
- 헤더: RPE 값(큰 숫자) + displayLabel + RIR + `?` 도움말 버튼 + clear(✕) 버튼
- 하단: 카테고리 레이블 (Light → Max) — EffortSliderView 패턴 참고
- nil 처리: `@State isActive` — 미선택 시 "Tap to rate" 안내 + 탭하면 기본값 8.0

### Step 2: Watch WatchSetRPEPickerView 슬라이더 리디자인

- 기존 3×3 LazyVGrid → `Slider` (Digital Crown 자동 지원)
- 중앙 큰 숫자 + displayLabel + RIR
- 색상 tint 현재 값 연동
- `?` 도움말 버튼

### Step 3: RPE 도움말 시트 (iOS + Watch)

- RPEHelpSheet: "이 세트가 얼마나 힘들었나요?" 헤더
- RPE-RIR 매핑 4단계 (여유/적당/힘듦/한계)
- 한 줄 요약

### Step 4: xcstrings 번역 추가

- 새 문자열 en/ko/ja 3개 언어 등록

## Reusable Components

- `RPELevel.displayLabel`, `.rir`, `.format()` — 기존 도메인 모델 그대로 사용
- `rpeColors` 배열 — 슬라이더 tint에 재사용
- `DS.Animation.snappy`, `DS.Spacing.*`, `DS.Color.*` — 디자인 토큰
- `EffortSliderView` — 슬라이더 + 카테고리 레이블 구조 참고

## Interface Compatibility

- `SetRPEPickerView(rpe: $rpe)` — `@Binding var rpe: Double?` 동일 유지
- `WatchSetRPEPickerView(rpe: $rpe)` — `@Binding var rpe: Double?` 동일 유지
- 호출부 (TemplateWorkoutView, MetricsView 등) 변경 없음

## Edge Cases

- nil 상태(미선택): 슬라이더 비활성 + "Tap to rate" 텍스트
- 기존 rpe 값으로 진입: 자동 isActive=true + 슬라이더 위치 설정
- clear 후 재선택: isActive 토글 정상 동작
- Watch Crown 민감도: 0.5 step이므로 9단계만 — Crown 조작에 적합

## Test Strategy

- 도메인 모델 변경 없음 → 기존 RPELevelTests 통과 확인
- UI 변경이므로 Preview 검증 + 빌드 통과 중심
- 번역 누락 없는지 xcstrings 등록 확인

## Risks

- SwiftUI Slider의 `step: 0.5` 동작이 Digital Crown에서 정상인지 확인 필요
- 슬라이더가 인라인에 들어갈 때 높이 증가 — TemplateWorkoutView 레이아웃 확인
