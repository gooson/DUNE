---
tags: [testing, ci, async, rpe, sleep, whats-new]
date: 2026-03-12
category: solution
status: implemented
---

# CI 테스트 실패 일괄 수정

## Problem

CI에서 4개 테스트 스위트가 실패:
1. `AverageSetRPETests` — RPE 8.0이 effort 6으로 매핑 (기대값 5)
2. `VisionSharePlayWorkoutViewModelTests` — AsyncStream 이벤트 미소비로 상태 검증 실패
3. `WellnessViewModelTests` — 수면 예측 confidence가 `.medium` (기대값 `.low`)
4. `WhatsNewManagerTests` — JSON 카탈로그와 테스트 기대값 불일치

## Root Causes

### 1. RPE 공식 드리프트
`averageSetRPE(sets:)` 함수에서 `round()` 함수가 추가되어 RPE 8.0 → effort 매핑이 변경됨.
- `normalized * 9.0` = 4.5 → `round()` = 5.0 → `Int()` + 1 = **6** (잘못됨)
- 의도: `Int(4.5)` = 4 → + 1 = **5** (올바름)

### 2. AsyncStream 테스트 타이밍
`Task.yield()`는 다른 Task가 AsyncStream 이벤트를 소비했음을 보장하지 않음. cooperative scheduling에서 yield는 "다른 작업에 기회를 줌"이지만 특정 Task의 완료를 보장하지 않음.

### 3. Zero-padded 수면 데이터
`buildSleepWeeklySeries()`가 항상 7개 엔트리로 zero-padding → `sleepDetailTrend.count`가 실제 데이터 가용일이 아닌 7로 고정 → confidence 레벨이 `.medium`으로 과대 평가.

### 4. WhatsNew JSON 동기화 누락
`whats-new.json` v0.2.0에 새 기능이 추가되었으나 테스트 기대값이 업데이트되지 않음.

## Solution

| 파일 | 수정 |
|------|------|
| `WorkoutIntensityService.swift:80` | `Int(round(normalized * 9.0))` → `Int(normalized * 9.0)` |
| `VisionSharePlayWorkoutViewModelTests.swift` | `Task.yield()` → `Task.sleep(for: eventPropagationDelay)` (100ms) |
| `WellnessViewModel.swift:147` | `.count` → `.filter { $0.minutes > 0 }.count` |
| `WhatsNewManagerTests.swift` | count 11→12, feature ID set 업데이트 |

## Prevention

1. **수학 공식 변경 시**: 테스트의 경계값(최솟값, 최댓값, 중간값)이 여전히 통과하는지 확인
2. **AsyncStream 테스트**: `Task.yield()` 대신 명시적 시간 지연 또는 testable hook 사용
3. **Zero-padding 컬렉션**: `.count`가 "실제 데이터 수"를 의미하는지 검증
4. **JSON 카탈로그 변경 시**: 관련 테스트도 함께 업데이트
