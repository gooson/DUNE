---
tags: [version, whats-new, release, 0.3.0]
date: 2026-03-09
category: plan
status: draft
---

# Plan: 버전 체계 정리 및 v0.3.0 업데이트

## Summary

`whats-new.json`에 0.1.0/0.2.0/0.3.0 세 릴리스를 명확히 분리하고, `project.yml`의 MARKETING_VERSION을 0.3.0으로 올린다. 새 문자열에 대한 ko/ja 번역을 xcstrings에 추가한다.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/Resources/whats-new.json` | 3개 릴리스 완전 재구성 |
| `DUNE/project.yml` | 5개 타겟 MARKETING_VERSION → 0.3.0 |
| `Shared/Resources/Localizable.xcstrings` | 새 What's New 문자열 ko/ja 번역 |

## Implementation Steps

### Step 1: whats-new.json 재구성

releases 배열을 0.3.0 → 0.2.0 → 0.1.0 순서로 재구성.

**0.1.0 — Foundation (8개)**:
1. exerciseLogging / Exercise Logging / activity
2. conditionScore / Condition Score / today
3. workoutTemplates / Workout Templates / activity
4. progressiveOverload / Progressive Overload / activity
5. muscleMap / Muscle Map / activity
6. watchWorkout / Apple Watch / watch
7. wellnessTab / Wellness / wellness
8. iPadSupport / iPad Support / settings

**0.2.0 — Polish & Expansion (12개)**: 기존 11개에서 conditionScore, muscleMap, wellness 제거 → 8개 + 신규 4개 추가
1. widgets / Widgets / today (유지)
2. weather / Weather Guidance / today (유지)
3. sleepDebt / Sleep Debt / today (문구 정리)
4. notifications / Notifications / today (유지)
5. trainingReadiness / Training Readiness / activity (유지)
6. habits / My Habits / life (유지)
7. themes / Themes / settings (유지)
8. watchQuickStart / Quick Start / watch (유지)
9. cardioLiveTracking / Cardio Live Tracking / activity (신규)
10. coachingInsights / Coaching Insights / today (신규)
11. localization / Localization / settings (신규)
12. airQuality / Air Quality / today (신규)

**0.3.0 — Intelligence & 3D (6개)**:
1. sleepPrediction / Sleep Prediction / wellness
2. injuryRisk / Injury Risk / activity
3. workoutRecommendations / Workout Recommendations / activity
4. weeklyReport / Weekly Report / activity
5. muscleMap3D / 3D Muscle Map / activity
6. bedtimeReminder / Bedtime Reminder / wellness

Verification: JSON 파싱 가능 여부 + 각 버전 features count 일치.

### Step 2: project.yml MARKETING_VERSION 변경

5개 타겟의 MARKETING_VERSION을 "0.2.0" → "0.3.0"으로 변경:
- DUNE (line ~124)
- DUNEWatch (line ~197)
- DUNEWidget (line ~243)
- DUNEVision (line ~375)
- DUNEVisionWidgets (line ~422)

Verification: `grep MARKETING_VERSION DUNE/project.yml` 결과 5개 모두 0.3.0.

### Step 3: xcstrings 번역 추가

새로 추가되는 문자열에 대해 en/ko/ja 번역 등록.

**0.1.0 문자열** (기존에 없는 것만):
- introKey + 8개 feature의 titleKey/summaryKey

**0.2.0 신규 4개**:
- Cardio Live Tracking 관련
- Coaching Insights 관련
- Localization 관련
- Air Quality 관련
- 새 introKey

**0.3.0 전체 6개**:
- 6개 feature의 titleKey/summaryKey
- introKey

Verification: xcstrings에 모든 새 키가 en/ko/ja 3개 언어로 존재.

## Test Strategy

- `scripts/build-ios.sh` 빌드 성공 확인
- JSON 구문 검증 (`python3 -c "import json; json.load(open(...))"`)
- 테스트 면제: SwiftUI View 영역 (What's New 시트는 UI 테스트 영역)

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| xcstrings 키 불일치 | 코드의 titleKey 문자열과 xcstrings 키가 정확히 일치하는지 확인 |
| JSON 파싱 실패 | python3 JSON 검증 + 빌드 테스트 |
| 기존 seen 버전 영향 | UserDefaults에 저장된 seenVersion은 semantic versioning 비교, 새 0.3.0이 0.2.0보다 크므로 정상 |
| 0.1.0 introKey가 길어져 UI 깨짐 | brainstorm에서 간결한 문구로 확정됨 |
