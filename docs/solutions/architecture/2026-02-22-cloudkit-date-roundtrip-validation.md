---
title: CloudKit Date Precision/Timezone Roundtrip Validation
date: 2026-02-22
tags: [cloudkit, swiftdata, date, timezone, validation]
status: in-progress
---

# CloudKit Date Precision/Timezone Roundtrip Validation

## Goal

SwiftData + CloudKit 동기화 후에도 `Date`의 절대 시각(UTC instant)과 밀리초 정밀도가 유지되는지 검증한다.

## Automated Guard (Added)

- `DailveTests/CloudKitDateRoundtripTests.swift`
  - JSON roundtrip에서 밀리초 정밀도 유지 검증
  - `WatchWorkoutUpdate` 인코딩/디코딩 시 `startTime/endTime` drift 검증
  - timezone 문자열 렌더링/파싱이 절대 시각을 바꾸지 않는지 검증

## Manual Device Validation (CloudKit)

### Preconditions

- iPhone + Apple Watch 모두 동일 iCloud 계정
- CloudKit 동기화 활성화 상태
- 앱 최신 빌드 설치

### Steps

1. Watch에서 운동 1건 기록 후 저장
2. iPhone에서 동기화된 같은 운동의 `Date` 확인
3. iPhone에서 같은 시각(초 단위 포함)으로 수동 레코드 1건 생성
4. Watch/iPhone 양쪽에서 동기화 완료 후 레코드 timestamp 비교
5. 시간대 변경 테스트:
   - iPhone 시간대를 `UTC`로 변경 후 timestamp 확인
   - 시간대를 `Asia/Seoul`로 변경 후 같은 레코드 timestamp 재확인

### Pass Criteria

- 동일 레코드의 epoch seconds drift < 0.001s
- 시간대 변경 전후 absolute instant는 동일
- UI 포맷만 locale/timezone에 맞게 변하고 원본 `Date` 값은 불변

## Notes

- 시뮬레이터/로컬 테스트로는 CloudKit transport 레이어를 완전히 재현할 수 없다.
- 따라서 위 수동 검증은 release 직전 회귀 체크로 유지한다.
