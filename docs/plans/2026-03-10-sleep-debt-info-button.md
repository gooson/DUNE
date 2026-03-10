---
tags: [sleep, deficit, info-button, sheet, ui]
date: 2026-03-10
category: plan
status: draft
---

# 수면 부채 게이지 i 버튼 + 설명 시트 추가

## Problem Statement

수면 부채 게이지(`SleepDeficitGaugeView`)에 계산 방식을 설명하는 UI가 없어, 사용자가 "오늘 많이 잤는데 왜 부채가 있지?"와 같은 혼란을 겪음.

## Scope

MVP: SleepDeficitGaugeView 타이틀 옆에 `info.circle` 버튼 추가 → 탭 시 설명 시트 표시.

## 영향 파일

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Presentation/Sleep/SleepDeficitGaugeView.swift` | **MODIFY** | 타이틀 옆 i 버튼 + `@State showingInfo` 추가 |
| `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift` | **NEW** | 설명 시트 View |
| `Shared/Resources/Localizable.xcstrings` | **MODIFY** | 새 문자열 en/ko/ja 추가 |

## 기존 패턴 참조

- `FatigueInfoSheet.swift`: 동일한 info sheet 패턴 (`.presentationDetents([.medium])`, `.presentationDragIndicator(.visible)`)
- `MuscleRecoveryMapView.swift`: `info.circle` 버튼 → sheet 트리거 패턴
- `ConditionExplainerSection.swift`: `info.circle.fill` + 설명 텍스트 패턴

## Implementation Steps

### Step 1: SleepDebtInfoSheet 생성

새 파일 `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift` 생성:
- FatigueInfoSheet 패턴 참조 (ScrollView + VStack + sections)
- `.presentationDetents([.medium])` + `.presentationDragIndicator(.visible)`
- 내용:
  1. 헤더: `info.circle.fill` + "How Sleep Debt Works"
  2. 기준선 섹션: 14일 평균이 기준선 (아이콘: `chart.line.flattrend.xyaxis`)
  3. 계산 방식 섹션: 7일간 평균 미만인 날의 부족분 누적 (아이콘: `calendar`)
  4. 초과 수면 설명: 평균보다 많이 자도 부채 상쇄 안됨 (아이콘: `moon.zzz`)
  5. 레벨 기준 테이블: good/mild/moderate/severe 시간 범위

### Step 2: SleepDeficitGaugeView 수정

- "Sleep Debt" 텍스트 옆에 `info.circle` 버튼 추가
- `@State private var showingInfoSheet = false`
- `.sheet(isPresented: $showingInfoSheet)` 연결

### Step 3: Localization

xcstrings에 새 문자열 en/ko/ja 3언어 등록.

## 테스트 전략

- View 전용 변경이므로 유닛 테스트 면제 (SwiftUI View body)
- 빌드 검증으로 충분

## 리스크/엣지 케이스

- `.presentationDetents([.medium])`: 콘텐츠가 medium 높이를 초과할 수 있음 → `.medium, .large` 2개 detent 제공
- Localization: 일본어가 길어질 수 있음 → 간결한 문구 사용
