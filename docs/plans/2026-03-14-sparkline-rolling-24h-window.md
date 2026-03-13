---
tags: [sparkline, rolling-window, hourly-tracking, ux]
date: 2026-03-14
category: plan
status: approved
---

# Sparkline Rolling 24시간 윈도우

## Problem Statement

Sparkline이 `startOfDay` 이후 데이터만 표시하여, 새벽(01:17 등) 시점에 데이터 포인트 1-2개로 의미있는 추세선 불가. 어제 데이터와 연결하여 하루 시작 시점에도 유의미한 시각화 필요.

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Domain/Models/HourlySparklineData.swift` | `HourlyPoint`에 `index` 추가, `includesYesterday` 플래그 |
| `DUNE/Data/Services/ScoreRefreshService.swift` | fetch 범위 24h, sequential index 할당 |
| `DUNE/Presentation/Shared/Components/HourlySparklineView.swift` | 차트 x축 동적 도메인 |
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift` | 라벨 분기 Today/24h |
| `DUNE/Presentation/Shared/Components/HeroScoreCard.swift` | 라벨 분기 Today/24h |
| `DUNETests/HourlySparklineDataTests.swift` | 새 필드 테스트 |

## Implementation Steps

### Step 1: Domain Model 확장
- `HourlyPoint`에 `index: Int` 추가 (차트 순서 포지셔닝)
- `Identifiable` 채택, `id = index`
- `HourlySparklineData`에 `includesYesterday: Bool` 추가
- `.empty` 업데이트

### Step 2: Service 레이어 변경
- `loadTodaySparklines()`: `startOfDay` → `now - 24h` fetch
- `buildSparkline()`: `enumerated().map`으로 sequential index 할당
- `includesYesterday` 계산: 스냅샷 중 startOfDay 이전 존재 여부

### Step 3: View 레이어 변경
- `HourlySparklineView`: `point.index` 기반 x축, 동적 도메인
- `ConditionHeroView`, `HeroScoreCard`: 라벨 분기

### Step 4: 테스트
- 기존 테스트 `index` 파라미터 추가
- `includesYesterday` 플래그 테스트
- `HourlyPoint.id` identity 테스트

## Test Strategy

- 기존 delta direction 테스트 유지 (index 파라미터 추가)
- `includesYesterday` true/false 분기 테스트
- `HourlyPoint.Identifiable` 준수 테스트
- 빌드: `scripts/build-ios.sh`

## Risks & Edge Cases

1. **24h 윈도우에 데이터 없음**: `.empty` 반환 (기존 동작 유지)
2. **fetchLimit 48**: 24h × 1/hour + 여유분. 과다 fetch 방지
3. **시간 wrap-around**: clock hour 22→23→0→1 순서가 chart에서 깨질 수 있음 → `index` 필드로 순서 보장
4. **Localization**: "24h"는 번역 불필요 (숫자+단위 약어)
