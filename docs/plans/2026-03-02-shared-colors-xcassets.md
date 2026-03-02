---
tags: [asset-catalog, colors, shared, watchOS, xcodegen]
date: 2026-03-02
category: plan
status: implemented
---

# Shared Colors.xcassets로 iOS/watchOS 색상 통합

## Problem

현재 색상 asset이 iOS(`DUNE/Resources/Assets.xcassets/Colors/`)와 watchOS(`DUNEWatch/Resources/Assets.xcassets/Colors/`)에 **중복 정의**되어 있다. 색상 추가/변경 시 양쪽을 동기화해야 하며, 동기화 누락 시 런타임 에러 발생.

## Research 결과

| 항목 | 수량 |
|------|------|
| iOS 색상 | 100개 |
| watchOS 색상 | 62개 |
| 공유(중복) 색상 | 62개 (watchOS 전체가 iOS의 부분집합) |
| iOS 전용 색상 | 38개 |
| watchOS 전용 색상 | 0개 |
| 값이 다른 공유 색상 | 6개 |

### 값이 다른 6개 색상

| 색상 | 차이 | 판단 |
|------|------|------|
| Caution | watchOS: universal only, iOS: light+dark | iOS 값 사용 (watchOS는 dark만 표시하므로 dark 값이 적용됨) |
| Negative | watchOS: universal only, iOS: light+dark | iOS 값 사용 (동일 이유) |
| Positive | watchOS: universal only, iOS: light+dark | iOS 값 사용 (동일 이유) |
| ForestDeep | dark 값 상이 | iOS 값 사용 (Forest 테마 신규 추가, watchOS 값은 수동 조정 누락 가능성) |
| ForestMid | dark 값 상이 | iOS 값 사용 (동일 이유) |
| ForestMist | dark 값 상이 | iOS 값 사용 (동일 이유) |

> **결정**: 모든 공유 색상에 iOS 값을 사용. watchOS는 항상 dark mode이므로 light+dark 분리가 있어도 dark 값이 자동 적용됨.

## Solution

### 구조

```
Shared/
  Resources/
    Colors.xcassets/        ← 62개 공유 색상 (NEW)
      AccentColor.colorset/
      Caution.colorset/
      DesertBronze.colorset/
      Forest*.colorset/     (27개)
      Metric*.colorset/     (7개)
      Ocean*.colorset/      (16개)
      ...

DUNE/Resources/Assets.xcassets/
  Colors/                   ← 38개 iOS 전용 색상 (KEEP)
    Activity*.colorset/     (10개)
    HRZone*.colorset/       (5개)
    CardBackground.colorset/
    LaunchBackground.colorset/
    Ocean*Score/Card/Tab/Weather (14개)
    Score*.colorset/        (5개 base)
    ShareCard*.colorset/    (2개)
    TabLife.colorset/
    Weather*.colorset/      (4개 base)

DUNEWatch/Resources/Assets.xcassets/
  Colors/                   ← 비움 (DELETE all colorsets)
```

### project.yml 변경

```yaml
targets:
  DUNE:
    sources:
      - path: ../Shared/Resources/Colors.xcassets   # ADD
      - path: App
      - path: Data
      - path: Domain
      - path: Presentation
      - path: Resources

  DUNEWatch:
    sources:
      - path: ../Shared/Resources/Colors.xcassets   # ADD
      - path: ../DUNEWatch
      # ... existing shared sources
```

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `Shared/Resources/Colors.xcassets/**` | CREATE | 62개 공유 색상 (iOS 값 기준) |
| `DUNE/Resources/Assets.xcassets/Colors/` | DELETE 62 | 공유 색상 제거, iOS 전용 38개만 유지 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/` | DELETE ALL | 모든 색상 제거 (Colors 폴더 자체는 유지 가능) |
| `DUNE/project.yml` | EDIT | 양쪽 target에 shared source 추가 |

**코드 변경 없음**: `Color("ForestAccent")`, `DS.Color.*` 등 색상 참조 코드는 동일하게 동작.

## Implementation Steps

### Step 1: Shared Colors.xcassets 생성

1. `Shared/Resources/Colors.xcassets/Contents.json` 생성
2. 62개 공유 색상의 colorset 디렉토리 생성 (iOS 값 기준으로 복사)

### Step 2: 기존 중복 색상 제거

1. `DUNE/Resources/Assets.xcassets/Colors/`에서 62개 공유 색상 삭제
2. `DUNEWatch/Resources/Assets.xcassets/Colors/`에서 모든 색상 삭제

### Step 3: project.yml 업데이트

1. DUNE target의 sources에 `../Shared/Resources/Colors.xcassets` 추가
2. DUNEWatch target의 sources에 `../Shared/Resources/Colors.xcassets` 추가

### Step 4: 빌드 검증

1. `scripts/build-ios.sh` 실행 (xcodegen 재생성 + 빌드)
2. watchOS 시뮬레이터에서 `ForestAccent` 런타임 에러 해소 확인

## 38개 iOS 전용 색상 목록

```
ActivityCardio, ActivityCombat, ActivityDance, ActivityMindBody, ActivityOther,
ActivityOutdoor, ActivitySports, ActivityStrength, ActivityWater, ActivityWinter,
CardBackground, HRZone1, HRZone2, HRZone3, HRZone4, HRZone5,
LaunchBackground, OceanCardBackground, OceanMetricBody, OceanMetricSteps,
OceanMist, OceanScoreExcellent, OceanScoreFair, OceanScoreGood,
OceanScoreTired, OceanScoreWarning, OceanTabLife,
OceanWeatherCloudy, OceanWeatherNight, OceanWeatherRain, OceanWeatherSnow,
ScoreExcellent, ScoreFair, ScoreGood, ScoreTired, ScoreWarning,
ShareCardGradientEnd, ShareCardGradientStart, TabLife,
WeatherCloudy, WeatherNight, WeatherRain, WeatherSnow
```

## 62개 공유 색상 목록

```
AccentColor, Caution, DesertBronze, DesertDusk,
ForestAccent, ForestBronze, ForestCardBackground, ForestDeep, ForestDusk,
ForestMetricActivity, ForestMetricBody, ForestMetricHRV, ForestMetricHeartRate,
ForestMetricRHR, ForestMetricSleep, ForestMetricSteps,
ForestMid, ForestMist, ForestSand,
ForestScoreExcellent, ForestScoreFair, ForestScoreGood, ForestScoreTired, ForestScoreWarning,
ForestTabLife, ForestTabTrain, ForestTabWellness,
ForestWeatherCloudy, ForestWeatherNight, ForestWeatherRain, ForestWeatherSnow,
MetricActivity, MetricBody, MetricHRV, MetricHeartRate, MetricRHR, MetricSleep, MetricSteps,
Negative,
OceanAccent, OceanBronze, OceanDeep, OceanDusk, OceanFoam,
OceanMetricActivity, OceanMetricHRV, OceanMetricHeartRate, OceanMetricRHR, OceanMetricSleep,
OceanMid, OceanSand, OceanSurface, OceanTabTrain, OceanTabWellness,
Positive, SandMuted, SurfacePrimary,
TabTrain, TabWellness, TextSecondary, TextTertiary,
WellnessFitness, WellnessVitals
```

## Risks

- **6개 색상 값 변경**: watchOS에서 Caution/Negative/Positive의 dark variant가 새로 적용되고, ForestDeep/Mid/Mist의 dark 값이 iOS 기준으로 변경됨. 시각적 차이 미미할 것으로 예상.
- **xcodegen 경로**: `../Shared/Resources/Colors.xcassets`가 DUNEWatch 기준으로는 `../../Shared/...`가 될 수 있음. project.yml의 base path 확인 필요 (project.yml 기준 상대경로).

## Test Strategy

1. `scripts/build-ios.sh` 빌드 성공
2. iOS 시뮬레이터에서 테마 전환 (Desert → Ocean → Forest) 색상 정상 렌더링
3. watchOS 시뮬레이터에서 `ForestAccent` 런타임 에러 0건
