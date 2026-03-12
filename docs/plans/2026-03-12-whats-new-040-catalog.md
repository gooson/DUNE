---
tags: [whats-new, catalog, release-notes, localization]
date: 2026-03-12
category: plan
status: approved
---

# What's New 0.4.0 카탈로그 업데이트

## Problem Statement

0.3.0 이후 다수의 주요 기능이 추가되었으나 What's New 카탈로그에 반영되지 않아
사용자가 새 기능을 인지하지 못함.

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Data/Resources/whats-new.json` | 0.4.0 릴리스 항목 추가 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja 번역 |
| `DUNETests/WhatsNewManagerTests.swift` | 0.4.0 파싱 테스트 추가 |

## 0.4.0 Feature List

### 1. Set-Level RPE (activity)
- **id**: `setLevelRPE`
- **symbol**: `gauge.with.dots.needle.33percent`
- iOS 슬라이더 RPE 피커 + Watch 자동 RPE 추정

### 2. New Themes (settings)
- **id**: `newThemes`
- **symbol**: `paintbrush.fill`
- Arctic Dawn, Solar Pop, Hanok, Shanks 4개 테마 추가

### 3. Stair Climber (activity)
- **id**: `stairClimber`
- **symbol**: `figure.stair.stepper`
- 계단 오르기 + 층수(flights climbed) 추적

### 4. Cardio Fitness (wellness)
- **id**: `cardioFitness`
- **symbol**: `heart.circle.fill`
- VO2 Max 자동 수집 + 카디오 피트니스 표시

### 5. Watch Cardio UX (watch)
- **id**: `watchCardioUX`
- **symbol**: `applewatch.and.arrow.forward`
- Apple Fitness 스타일 멀티페이지 + 스와이프 제어

### 6. Workout Rewards (activity)
- **id**: `workoutRewards`
- **symbol**: `trophy.fill`
- 마일스톤 달성 + 달성 히스토리

### 7. Sleep Deficit Analysis (wellness)
- **id**: `sleepDeficit`
- **symbol**: `chart.bar.fill`
- 개인화된 수면 부족 분석 + 평균 취침시간 카드

### 8. Life Tab Improvements (life)
- **id**: `lifeTabUpgrade`
- **symbol**: `sparkle`
- 자동 운동 달성, 반복 습관, 체크리스트 리마인더

## Implementation Steps

### Step 1: whats-new.json 수정
- 0.4.0 릴리스를 `releases` 배열 맨 앞에 추가
- 8개 feature 항목 작성

### Step 2: Localizable.xcstrings 번역 추가
- introKey + 8개 feature의 titleKey/summaryKey = 17개 문자열
- en/ko/ja 3개 언어 동시 등록

### Step 3: 테스트 업데이트
- WhatsNewManagerTests에 0.4.0 파싱 테스트 추가
- feature 개수, ID 검증

## Test Strategy

- 기존 WhatsNewManagerTests 패턴 준수
- 0.4.0 릴리스 파싱, feature ID 매칭, localization key 비어있지 않음 검증
- 빌드 후 WhatsNewView 프리뷰에서 0.4.0 표시 확인

## Risks / Edge Cases

- JSON 오타 시 런타임 파싱 실패 → 기존 WhatsNewManager fallback으로 빈 배열 반환
- xcstrings 키 불일치 시 영어 fallback 표시 → 키를 영어 텍스트로 사용하므로 최소한 영어는 표시
- WhatsNewView 프리뷰의 preferredVersion을 0.4.0으로 바꿔서 확인 필요
