---
tags: [watchconnectivity, posture, sync, i18n, watchos, wellness]
date: 2026-03-22
category: general
status: implemented
---

# Watch Posture Data Sync to iPhone

## Problem

Watch 자세 모니터링 데이터(앉은 시간, 걷기 시간, 알림 횟수, 보행 점수)가 iPhone에서 볼 수 없었음. Watch에서 수집만 하고 WatchConnectivity를 통한 전송 경로가 없었음.

추가적으로:
- 톱니바퀴 설정 버튼이 12pt로 너무 작아서 탭하기 어려웠음
- 일부 Watch 자세 모니터링 문자열에 ko/ja 번역이 누락

## Solution

### 1. WatchConnectivity 동기화 인프라
- `DailyPostureSummary`를 Watch-only에서 공유 `WatchConnectivityModels.swift`로 이동
- `PostureFormatting`도 공유 모델로 이동 (Watch/iOS 양쪽에서 사용)
- Watch `WatchConnectivityManager.sendPostureSummary()` 추가 (sendMessage + transferUserInfo fallback)
- iOS `WatchSessionManager`에 `receivedPostureSummary` 저장 + 오늘 날짜 검증 + gait 범위 검증(0-100)
- Watch `WatchPostureMonitor`에서 활동 상태 전환 시 + 알림 발송 시 동기화 트리거 (60초 throttle)

### 2. iPhone UI
- `WatchPostureSummaryCard` 생성: 앉은 시간, 걷기 시간, 알림 횟수, 보행 점수 표시
- `WellnessView`의 Posture Assessment 섹션 위에 배치
- ViewModel을 통해 접근 (직접 singleton 접근 금지)

### 3. UX/i18n
- 톱니바퀴 아이콘 12pt → 17pt (watchOS 표준 toolbar 크기)
- Watch: "Walking", "Today" ko/ja 번역 추가
- iOS: "Sitting", "Gait", "Reminders", "Watch Posture" ko/ja 번역 추가

## Prevention

- WatchConnectivity DTO 추가 시 반드시 `WatchConnectivityModels.swift`에 정의 (Watch/iOS 양쪽 접근)
- WC 메시지 전송은 throttle 적용 (CoreMotion 콜백은 빈번하므로 무조건 전송하면 battery drain)
- View에서 직접 singleton 접근 금지 → ViewModel에서 중계

## Lessons Learned

1. Watch에서 iPhone으로 동기화할 때 `sendMessage`(즉시) + `transferUserInfo`(백그라운드 fallback) 이중 경로가 안정적
2. 반복 호출 가능한 동기화 트리거에는 throttle 필수 (activity state 전환은 초 단위로 발생 가능)
3. 공유 유틸리티(`PostureFormatting`)는 플랫폼별 복사 대신 공유 모델에 배치
