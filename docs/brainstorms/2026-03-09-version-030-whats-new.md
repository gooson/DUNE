---
tags: [version, release, whats-new, 0.1.0, 0.2.0, 0.3.0]
date: 2026-03-09
category: brainstorm
status: draft
---

# Brainstorm: 버전 체계 정리 및 v0.3.0 업데이트

## Problem Statement

1. `whats-new.json`에 0.1.0이 없어 초기 기능이 누락되어 있다
2. 0.2.0 항목에 0.1.0 기능(Condition Score, Muscle Map, Wellness)이 섞여 있다
3. v0.2.0 이후 ML 예측, 3D 근육맵, 취침 알림 등 새 기능을 v0.3.0으로 반영해야 한다

## Target Users

- 기존 DUNE 사용자 (업데이트 후 What's New 시트에서 새 기능 확인)
- 신규 사용자 (첫 실행 시 전체 기능 소개)

## Success Criteria

1. `whats-new.json`에 0.1.0 / 0.2.0 / 0.3.0 세 릴리스가 명확히 분리
2. `project.yml` 전체 타겟 MARKETING_VERSION → 0.3.0
3. 각 버전의 기능 목록이 중복 없이 시간순으로 정리

---

## 0.1.0 — Foundation (8개)

| # | id | title | area | summary |
|---|---|---|---|---|
| 1 | exerciseLogging | Exercise Logging | activity | Log sets, reps, and weight with custom exercises, draft recovery, and search filters. |
| 2 | conditionScore | Condition Score | today | Check your HRV and resting heart rate to see how ready your body is each day. |
| 3 | workoutTemplates | Workout Templates | activity | Create, edit, and start workouts from saved templates for a faster session. |
| 4 | progressiveOverload | Progressive Overload | activity | Track 1RM estimates and view exercise history charts to measure your progress. |
| 5 | muscleMap | Muscle Map | activity | See which muscle groups are recovered, overloaded, or ready on an interactive body map. |
| 6 | watchWorkout | Apple Watch | watch | Track workouts on Apple Watch and sync completed sessions back to iPhone. |
| 7 | wellnessTab | Wellness | wellness | View sleep, body, and active indicators together in one score-driven dashboard. |
| 8 | iPadSupport | iPad Support | settings | Full iPad layout with sidebar navigation and universal design. |

**introKey**: "Track workouts, check your condition, and see your progress — all built around your body's data."

---

## 0.2.0 — Polish & Expansion (11개)

기존 11개에서 0.1.0 중복 3개(Condition Score, Muscle Map, Wellness) 제거 → 8개
+ 신규 4개(Cardio Live Tracking, Coaching Insights, Localization, Air Quality) 추가 → **12개**

| # | id | title | area | summary | 변경 |
|---|---|---|---|---|---|
| 1 | widgets | Widgets | today | Add DUNE widgets to your Home Screen and glance at your key scores without opening the app. | 유지 |
| 2 | weather | Weather Guidance | today | Check live weather, outdoor fitness guidance, and hourly conditions before you head out. | 유지 |
| 3 | sleepDebt | Sleep Debt | today | Spot your weekly sleep debt and compare recent rest against your baseline. | 문구 정리 |
| 4 | notifications | Notifications | today | Review unread insights and jump back into important updates any time. | 유지 |
| 5 | trainingReadiness | Training Readiness | activity | Open recovery details, weekly stats, and suggestions built around your recent training. | 유지 |
| 6 | habits | My Habits | life | Track daily habits and keep auto achievements moving with your routine. | 유지 |
| 7 | themes | Themes | settings | Switch between eight visual themes from Settings and make the app feel more like yours. | 유지 |
| 8 | watchQuickStart | Quick Start | watch | Start workouts faster on Apple Watch and sync completed sessions back to iPhone. | 유지 |
| 9 | cardioLiveTracking | Cardio Live Tracking | activity | Track distance, pace, and heart rate in real time during runs and walks. | **신규** |
| 10 | coachingInsights | Coaching Insights | today | Get personalized coaching cards with actionable tips based on your condition and trends. | **신규** |
| 11 | localization | Localization | settings | Full support for English, Korean, and Japanese across every screen. | **신규** |
| 12 | airQuality | Air Quality | today | Check PM2.5 and PM10 levels alongside weather before your outdoor session. | **신규** |

**introKey**: "Widgets, weather, coaching, sleep debt, cardio tracking, themes, and three languages — all in one update."

---

## 0.3.0 — Intelligence & 3D (6개)

| # | id | title | area | summary |
|---|---|---|---|---|
| 1 | sleepPrediction | Sleep Prediction | wellness | See tonight's predicted sleep quality based on your recent patterns and today's activity. |
| 2 | injuryRisk | Injury Risk | activity | Get a daily injury risk score based on your training load, recovery, and workout history. |
| 3 | workoutRecommendations | Workout Recommendations | activity | Receive personalized exercise suggestions based on muscle fatigue and training balance. |
| 4 | weeklyReport | Weekly Report | activity | Review a Foundation Models summary of your week — volume, intensity, and key highlights. |
| 5 | muscleMap3D | 3D Muscle Map | activity | Explore your muscle recovery on an upgraded 3D body model with smoother detail. |
| 6 | bedtimeReminder | Bedtime Reminder | wellness | Set a nightly reminder to wind down and protect your sleep schedule. |

**introKey**: "Sleep predictions, injury alerts, smart workout picks, weekly reports, a 3D muscle map, and bedtime reminders — your training just got smarter."

---

## 제외 항목

| 기능 | 이유 | 예정 버전 |
|------|------|----------|
| Cinematic Ocean Scene | 사용자 결정 | 미정 |
| visionOS 전반 (Chart3D, USDZ 공유, Settings 윈도우) | 별도 릴리스 | 0.4.0 |

## Constraints

- `whats-new.json` releases 배열: 0.3.0 (최신) → 0.2.0 → 0.1.0 순서
- `project.yml` 5개 타겟 MARKETING_VERSION 동시 변경
- introKey와 summaryKey는 영어 (xcstrings에서 ko/ja 번역)

## Scope

### MVP (Must-have)
- `project.yml` 5개 타겟 MARKETING_VERSION → 0.3.0
- `whats-new.json`에 3개 릴리스 완전 재구성
- xcstrings에 새 What's New 문자열 ko/ja 번역

### Nice-to-have (Future)
- App Store 메타데이터 업데이트 (별도 작업)

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] 구현 후 빌드 검증 (`scripts/build-ios.sh`)
