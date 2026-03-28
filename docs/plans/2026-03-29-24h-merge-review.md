---
tags: [review, merge-audit, localization, sleep, personal-records, animation]
date: 2026-03-29
category: plan
status: draft
---

# 24h Merge Review Plan

## Problem Statement

최근 24시간 동안 20개 PR, 120개 커밋, ~110개 파일이 main에 머지되었다.
주요 변경 영역: sleep 분석 5개 기능, personal records 오버홀, rich animation 시스템,
weekly stats 수정, migration dead code 정리, watch inputType-aware UI, 기타 버그 수정.

이 변경사항을 종합 리뷰하고 문제점을 수정한다.

## Affected Areas

| 영역 | 변경 파일 수 | 주요 리스크 |
|------|-------------|-----------|
| Sleep 분석 | ~25 | 새 UseCase 5개 — 입력 검증, 나눗셈 방어 |
| Personal Records | ~12 | 1RM/RepMax/Volume PR — 계산 정확성 |
| Animation | ~10 | 무한 반복 애니메이션 — 성능, .task 규칙 |
| Weekly Stats | ~8 | period 정렬, lastWeek 빈 카드 수정 |
| Watch | ~8 | inputType-aware UI, stretch reminder |
| Migration | ~3 | dead code 삭제, AppSchema 리네임 |
| Localization | 2 | 새 문자열 73개 — ko/ja 누락 확인 |
| Charts/Detail | ~10 | clipping, chart top padding |

## Initial Findings (Pre-Review)

### L10N — 신규 키 번역 누락 (4건)
1. `Force Sync` — SettingsView.swift:224 — ko/ja 번역 없음
2. `+%@ kg` — WorkoutCompletionSheet.swift:188 — ko/ja 번역 없음
3. `+%@pt` — SleepEnvironmentCard.swift:60 — ko/ja 번역 없음
4. `~%@` — SleepDebtRecoveryCard.swift:16 — ko/ja 번역 없음

## Implementation Steps

### Step 1: L10N 수정
- Localizable.xcstrings에 4개 키의 ko/ja 번역 추가

### Step 2: 에이전트 분석 결과 기반 수정
- Sleep UseCase 검증 이슈
- Personal Records 계산 이슈
- Animation 패턴 이슈
- Chart/Detail 이슈

### Step 3: 빌드 + 테스트 검증

## Test Strategy

- `scripts/build-ios.sh` 빌드 통과
- `xcodebuild test ... DUNETests` 유닛 테스트 통과
- Localization 키 완전성 검증 (python3 스크립트)

## Risks / Edge Cases

- sleep UseCase에서 나눗셈/log/sqrt 방어 누락 가능
- animation .repeatForever가 .onAppear에서 시작될 수 있음
- 새 PR 타입 계산에서 overflow 가능
