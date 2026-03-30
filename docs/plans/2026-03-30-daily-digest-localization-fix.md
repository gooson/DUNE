---
tags: [localization, xcstrings, daily-digest, i18n]
date: 2026-03-30
category: plan
status: draft
---

# 오늘의 요약(Daily Digest) 영어 출력 문제 수정

## Problem Statement

`DailyDigestCard`의 "오늘의 요약" 본문 텍스트가 한국어/일본어 locale에서도 영어로 출력됨.
스크린샷에서 확인: 스트레스 메시지("스트레스가 잘 관리되고 있습니다.")만 한국어로 표시되고 나머지는 영어.

## Root Cause

`GenerateDailyDigestUseCase.buildTemplateSummary()`에서 `String(localized:)` 를 올바르게 사용하고 있으나,
해당 키들이 `Shared/Resources/Localizable.xcstrings`에 등록되지 않아 영어 fallback 발생.

### 키 상태 분석

| 키 (format specifier 포함) | xcstrings 존재 | ko/ja 번역 |
|---|---|---|
| `"Today's condition score was %lld (%@%lld from yesterday)."` | X | X |
| `"Today's condition score was %lld."` | X | X |
| `"You completed %@."` | X | X |
| `"Today was a rest day."` | O | O |
| `"Last night's sleep: %lldh %lldm."` | X | X |
| `"Last night's sleep: %lld hours."` | X | X |
| `"Sleep debt remains at %lldh %lldm. Consider an earlier bedtime tonight."` | X | X |
| `"Sleep debt: %lld minutes. Almost caught up!"` | X | X |
| `"%@ steps today."` | X (유사: `"%lld steps today"` 존재하나 타입/마침표 불일치) | X |
| `"Stress levels are well managed."` | O | O |
| `"Stress is at a moderate level."` | O | O |
| `"Stress is elevated — prioritize recovery."` | O | O |
| `"Stress is high — take time to rest and recover."` | O | O |

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `Shared/Resources/Localizable.xcstrings` | 누락된 9개 키 + ko/ja 번역 추가 |

## Implementation Steps

### Step 1: xcstrings에 누락된 키 추가

9개 누락 키를 `Localizable.xcstrings`에 추가하고 ko/ja 번역을 함께 등록.

### Step 2: 테스트 추가

`GenerateDailyDigestUseCaseTests.swift`에서 한국어 번역이 누락되지 않았는지 검증하는 테스트 추가.
(단, `String(localized:)`는 시뮬레이터 locale에 의존하므로, 키 존재 여부를 Bundle lookup으로 검증)

## Test Strategy

- 기존 `GenerateDailyDigestUseCaseTests` 유닛 테스트 통과 확인
- 빌드 검증: `scripts/build-ios.sh`
- xcstrings 키 일치 검증: 코드의 모든 `String(localized:)` 키가 xcstrings에 존재하는지 확인

## Risk / Edge Cases

- format specifier 불일치: `\(steps.formatted())`는 `String`을 반환하므로 `%@` 사용. 기존 `"%lld steps today"` 키와 다름.
- 복합 보간 키의 argument 순서: ko/ja에서 어순이 달라도 positional specifier 불필요 (argument 순서가 의미상 유지됨)
