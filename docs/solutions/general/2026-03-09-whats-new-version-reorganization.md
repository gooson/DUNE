---
tags: [whats-new, version, release, localization, xcstrings]
date: 2026-03-09
category: solution
status: implemented
---

# What's New 버전 체계 재구성

## Problem

`whats-new.json`에 0.1.0이 없어 초기 기능이 누락되었고, 0.2.0에 0.1.0 기능이 섞여 있었다. v0.3.0 신규 기능 추가도 필요했다.

## Solution

### 1. 3개 릴리스 분리

| 버전 | 이름 | 기능 수 | 핵심 |
|------|------|---------|------|
| 0.1.0 | Foundation | 8 | 운동 기록, 컨디션, 템플릿, 근육맵, Watch, iPad |
| 0.2.0 | Polish & Expansion | 12 | 위젯, 날씨, 코칭, 유산소 추적, 다국어, 대기질 |
| 0.3.0 | Intelligence & 3D | 6 | 수면 예측, 부상 위험, 운동 추천, 주간 리포트, 3D 근육맵, 취침 알림 |

### 2. 파일 변경

- `whats-new.json`: releases 배열 → 0.3.0 (최신) → 0.2.0 → 0.1.0 순서
- `project.yml`: 5개 타겟 MARKETING_VERSION → 0.3.0
- `Localizable.xcstrings`: 32개 새 문자열 en/ko/ja 번역

### 3. 중복 해결

conditionScore, muscleMap, wellness를 0.2.0에서 0.1.0으로 이동. 0.2.0에서 해당 항목 제거 + 신규 4개(cardioLiveTracking, coachingInsights, localization, airQuality) 추가.

## Prevention

- What's New 기능 추가 시 어떤 버전에 속하는지 brainstorm 단계에서 명확히 결정
- xcstrings에 새 키 추가 시 Python 스크립트로 일괄 처리 (수동 JSON 편집 시 오류 가능성 높음)
- `WhatsNewManager`의 `orderedReleases(preferredVersion:)` 패턴으로 표시 순서 제어
