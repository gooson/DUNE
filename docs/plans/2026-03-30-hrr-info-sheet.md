---
tags: [heart-rate, recovery, hrr1, info-sheet, ui]
date: 2026-03-30
category: plan
status: approved
---

# HRR₁ Info Sheet — Recovery 행 info 버튼

## Problem Statement

운동 상세 심박수 그래프 아래 `HeartRateRecoveryRow`에 HRR₁ 수치와 등급이 표시되지만, 사용자가 이 지표의 의미를 이해할 수 있는 설명이 없음.

## Scope (MVP)

- `HeartRateRecoveryRow`에 `info.circle` 버튼 추가
- 탭 시 `HeartRateRecoveryInfoSheet` 표시
- 시트 내용: 정의, 측정 방법, 등급 기준 테이블
- en/ko/ja 3개 언어 번역

## Affected Files

| File | 변경 내용 |
|------|----------|
| `Presentation/Shared/Extensions/HeartRateRecovery+View.swift` | `HeartRateRecoveryRow`에 info 버튼 + sheet binding 추가, `HeartRateRecoveryInfoSheet` 정의 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja 번역 추가 |

## Implementation Steps

### Step 1: HeartRateRecoveryInfoSheet 작성

기존 InfoSheet 패턴 (`WASOInfoSheet`) 그대로 따름:
- `ScrollView` + `VStack` 구조
- `presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)`
- `InfoSheetHelpers.SectionHeader` 재사용
- 섹션: Definition, How It's Measured, Rating Guide (테이블)

### Step 2: HeartRateRecoveryRow에 info 버튼 추가

기존 `WakeAnalysisCard` 패턴:
- `@State private var showingInfoSheet = false`
- "Recovery" Label 오른쪽에 `Button` + `info.circle` 아이콘
- `.sheet(isPresented:)` → `HeartRateRecoveryInfoSheet()`

### Step 3: Localization

`Localizable.xcstrings`에 새 문자열 en/ko/ja 등록:
- "What is Heart Rate Recovery?"
- "Heart Rate Recovery (HRR₁) measures how quickly your heart rate drops after exercise ends. A faster drop indicates better cardiovascular fitness and autonomic nervous system health."
- "Apple Watch measures your heart rate at the end of your workout (peak) and again about 60 seconds later (recovery). The difference between these two values is your HRR₁."
- "Rating Guide"
- Rating row labels/ranges

## Test Strategy

- **유닛 테스트**: 불필요 — 순수 UI 변경, 기존 모델/로직 변경 없음
- **빌드 검증**: `scripts/build-ios.sh` 통과
- **시각적 검증**: 기존 HeartRateRecoveryRow가 사용되는 2개 화면에서 info 버튼 동작 확인

## Risks / Edge Cases

- `HeartRateRecoveryRow`는 shared 컴포넌트로 `HealthKitWorkoutDetailView`와 `ExerciseSessionDetailView` 양쪽에서 사용됨 → sheet state를 Row 내부에 두므로 양쪽 자동 적용
- sheet 내 문자열이 길어질 수 있으므로 `.medium` + `.large` 두 detent 지원
