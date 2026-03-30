---
tags: [localization, xcstrings, daily-digest, String(localized:), missing-key]
date: 2026-03-30
category: solution
status: implemented
---

# Daily Digest 요약 텍스트 영어 출력 문제

## Problem

DailyDigestCard의 "오늘의 요약" 본문이 한국어/일본어 locale에서도 영어로 표시됨.
스트레스 메시지("스트레스가 잘 관리되고 있습니다.")만 한국어로 표시되고 나머지는 영어 fallback.

### 근본 원인

`GenerateDailyDigestUseCase.buildTemplateSummary()`에서 `String(localized:)` 를 올바르게 사용하고 있었으나,
해당 키 8개가 `Localizable.xcstrings`에 등록되지 않아 영어 fallback 발생.

스트레스 관련 4개 키와 "Today was a rest day."는 이미 등록되어 있었기 때문에 해당 메시지만 번역됨.

## Solution

`Shared/Resources/Localizable.xcstrings`에 누락된 8개 키를 en/ko/ja 번역과 함께 추가:

| 키 | 비고 |
|---|---|
| `"Today's condition score was %lld (%@%lld from yesterday)."` | 3개 인자: score(Int), sign(String), delta(Int) |
| `"Today's condition score was %lld."` | delta 없는 경우 |
| `"You completed %@."` | workout summary(String) |
| `"Last night's sleep: %lldh %lldm."` | hours + mins |
| `"Last night's sleep: %lld hours."` | 정시 수면 |
| `"Sleep debt remains at %lldh %lldm. Consider an earlier bedtime tonight."` | hours + mins |
| `"Sleep debt: %lld minutes. Almost caught up!"` | 분 단위만 |
| `"%@ steps today."` | `.formatted()` 반환값(String) 사용 → `%@` |

### 주의: `%@` vs `%lld` for steps

기존 `"%lld steps today"` 키(다른 용도)와 구분 필요. UseCase에서 `steps.formatted()` 호출 결과가 `String`이므로 `%@` 사용이 정확.

## Prevention

1. 새 `String(localized:)` 추가 시 **반드시** xcstrings에 3개 언어 동시 등록 (localization.md 체크리스트 P1)
2. `GenerateDailyDigestUseCase` 같이 동적으로 문장을 조합하는 UseCase는 모든 분기의 키를 xcstrings에 등록했는지 검증

## Lessons Learned

- `String(localized:)` 사용이 올바르더라도 xcstrings에 키가 없으면 **조용히** 영어 fallback — 런타임 에러나 경고 없음
- 스크린샷으로 문제를 발견했을 때 **부분 번역**(일부만 한국어, 나머지 영어)이면 xcstrings 키 누락을 의심
