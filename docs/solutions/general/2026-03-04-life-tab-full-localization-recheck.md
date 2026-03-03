---
tags: [localization, life-tab, xcstrings, i18n, workout-name]
date: 2026-03-04
category: solution
status: implemented
---

# 라이프탭 전 화면 다국어 재점검 (운동명 포함)

## Problem

라이프탭 전반에서 ko/ja 번역 누락이 남아 있어 일부 UI가 영어로 표시되었다.

### Symptoms

- 자동 업적 카드의 그룹명/단축 운동명(`Routine Consistency`, `Workout 5x`, `Arms` 등)이 영어로 노출
- 사이클 상태 문구(`Due`, `Done · Next ...`, `Snooze 1 Day`)가 영어로 노출
- 히스토리/폼 화면 일부 키(`History`, `No History`, `Complete once per cycle`, `Recurring`)가 번역되지 않음
- 리마인더 문구(`%@ is due today`) 키가 없어서 영어 fallback 발생

### Root Cause

- `LifeView`에서 사용자 대면 문자열을 런타임 `String` 하드코딩으로 생성 (`Text(String)` 경로)
- `DUNE/Resources/Localizable.xcstrings`의 관련 키가 비어 있거나(`{}`), 아예 누락되어 있음

## Solution

라이프탭 런타임 문자열 경로를 localized API로 정리하고, 누락된 String Catalog 키를 ko/ja로 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | 자동 업적 그룹명/운동명/streak 텍스트를 `String(localized:)`로 전환 | 런타임 문자열도 로케일 기반으로 표시되도록 보장 |
| `DUNE/Resources/Localizable.xcstrings` | 기존 빈 키 6개 번역 채움 + 라이프탭 신규 키 29개 추가 | 전 화면에서 발생하던 영어 fallback 제거 |
| `docs/plans/2026-03-04-life-tab-full-localization-recheck.md` | 구현 계획 기록 | 재현 가능한 작업 흐름 보존 |

### Key Coverage

- 기존 누락 채움: `My Habits`, `Recurring`, `Due`, `Next due %@`, `Best streak %@w`, 예시 문구
- 신규 추가(대표):
  - 자동 업적: `Routine Consistency`, `Strength Split`, `Running Distance`, `Workout 5x`, `Workout 7x`, `Arms`, `Lower Body`
  - 사이클 상태: `Due today · Tap to complete`, `Overdue · Tap to complete`, `Done · Next %@`, `Skipped · Next %@`, `Snoozed · Next %@`
  - 폼/히스토리: `Complete once per cycle`, `Every %lld days`, `%lld days per week`, `History`, `No History`, `No cycle actions recorded yet.`
  - 리마인더: `%@ is due today`, `%@ is due in 1 day`, `%@ is due in %lld days`, `Life Checklist`

## Validation

- `jq empty DUNE/Resources/Localizable.xcstrings`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/LifeViewModelTests -only-testing DUNETests/LifeAutoAchievementServiceTests -quiet`
  - 1회 시뮬레이터 bootstrap crash 재시도 후 통과

## Prevention

- 라이프탭처럼 `Text(String)` 경로를 사용하는 경우, 문자열 생성 시점에 `String(localized:)` 강제 적용
- `xcstrings` 점검 시 "키 존재 여부"뿐 아니라 `ko/ja value != null`까지 확인
- 신규 UI 문자열 추가 시 다음 체크를 release 전 고정:
  - [ ] 코드 경로 localization 적용 (`Text("...")` 또는 `String(localized:)`)
  - [ ] `xcstrings` en/ko/ja 모두 채움
  - [ ] 포맷 키(`%@`, `%lld`)가 코드 보간 타입과 일치하는지 확인
