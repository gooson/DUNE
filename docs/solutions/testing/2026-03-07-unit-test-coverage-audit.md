---
tags: [testing, unit-test, coverage, swift-testing, audit]
date: 2026-03-07
category: solution
status: implemented
---

# Unit Test Coverage Audit & Gap Fill

## Problem

프로젝트에 1,393개의 기존 유닛 테스트가 있었으나, 체계적인 커버리지 감사가 수행되지 않아 비-trivial 로직이 포함된 도메인 모델 8개가 테스트 없이 존재했다.

## Solution

### 감사 방법론

1. `DUNETests/` 전체 파일 목록과 `Domain/Models/` 소스 파일 대조
2. 각 모델의 computed property, validation, 분기 로직 식별
3. 테스트 면제 대상(단순 저장 프로퍼티, SwiftUI View, HealthKit 쿼리) 필터링
4. 67개 테스트를 7개 신규 파일 + 1개 기존 파일 확장으로 추가

### 추가된 테스트 파일

| 파일 | 테스트 수 | 대상 로직 |
|------|-----------|----------|
| HeartRateZoneCalculatorTests | 11 | computeZones 알고리즘, 갭 처리, 경계값 |
| MuscleFatigueStateTests | 10 | fatigueLevel 3경로, isRecovered, isOverworked, nextReadyDate |
| PeriodComparisonTests | 11 | percentage change 4속성, DailyVolumePoint |
| StrengthPersonalRecordTests | 6 | weight clamping, isRecent |
| InjuryInfoTests | 5 | isActive, durationDays, affectedMuscleGroups |
| WeatherSnapshotThresholdTests | 9 | threshold 경계값, isFavorableOutdoor, isStale |
| ActivityPersonalRecordKindTests | 3 | isLowerBetter, init mapping, sortOrder |
| ConditionScoreTests (확장) | 12 | narrativeMessage 분기, BaselineStatus 엣지 |

### 리뷰에서 발견/수정된 패턴

1. **Silent pass 방지**: `if let` 대신 `try #require`로 nil 경로 검증
2. **Locale-resilient 테스트**: `String(localized:)` 반환값은 locale에 따라 다르므로 특정 영어 문자열이 아닌 분기 동작(다른 입력 → 다른 출력) 검증
3. **Date() 플레이키니스**: 테스트 helper에서 `Date()` 대신 `static let fixedDate` 사용
4. **경계값 양면 테스트**: gap threshold 300s → 299s(포함) + 300s(제외) 양쪽 테스트
5. **objectVersion 보호**: `xcodegen generate` 직접 실행 금지 → `scripts/build-ios.sh` 경유 필수

## Prevention

- 새 도메인 모델 추가 시 `{Model}Tests.swift` 동시 생성 (testing-required.md 규칙)
- computed property에 분기 로직이 있으면 각 분기별 최소 1개 테스트
- `if let` 조건부 assertion 금지 → `try #require` 사용
- 날짜 의존 테스트는 고정 Date 사용
- xcodegen은 항상 스크립트 경유
