# Code Review Report

> Date: 2026-03-22
> Scope: Apple Watch 취침 리마인더 복원, 1시간 기본 리드타임 적용, 설정/로컬라이즈/스케줄링 회귀 점검
> Files reviewed: 9개

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | None |
| P2 - Important | 0 | None |
| P3 - Minor | 0 | None |

## P1 Findings (Must Fix)

- 없음

## P2 Findings (Should Fix)

- 없음

## P3 Findings (Consider)

- 없음

## Revalidated Findings

- `Stale after fix` [Architecture/Data] `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
  - 초기 구현은 `WCSession.isWatchAppInstalled`까지 요구해, Apple Watch는 페어링되어 있지만 DUNE watch companion을 설치하지 않은 사용자에게 알림이 전혀 예약되지 않았다.
  - 현재 HEAD에서는 해당 게이트를 제거하고 paired watch만 확인하도록 수정했으며, `Schedules reminder when watch is paired even if companion app is not installed` 테스트로 회귀를 막았다.

## Localization Verification

- `NotificationSettingsSection`의 신규 사용자 대면 문자열은 `Label`, `Picker`, `Text`를 통해 localized key로 처리된다.
- 알림 본문/제목은 `String(localized:)` 경로를 사용한다.
- `BedtimeReminderLeadTime`는 enum rawValue를 직접 UI에 노출하지 않고 `displayName` computed property를 경유한다.
- `Shared/Resources/Localizable.xcstrings`에 신규 key가 추가되어 설정 라벨과 안내 문구가 문자열 리소스와 연결된다.

## Positive Observations

- 취침 알림을 반복 알림에서 next one-shot 스케줄로 바꾸고, `HealthKitObserverManager`의 sleep observer에서 재무장하도록 연결해 다음 날 스케줄 갱신 경로를 확보했다.
- 리드타임 선택값과 기본값을 `BedtimeReminderLeadTime` 단일 source of truth로 유지해 설정 UI와 스케줄러 계산이 일치한다.
- 심박 기반 watch 착용 판정은 취침 직전 90분 창에서만 평가해, 낮 시간의 watch 사용 때문에 저녁 알림이 미리 취소되는 오탐을 줄였다.

## Next Steps

- [x] paired watch만으로 스케줄되도록 게이트 정리
- [x] scheduler 회귀 테스트 재실행
- [x] `/compound` 문서화 진행
