---
tags: [watch, posture, ux, sync, i18n, watchconnectivity]
date: 2026-03-22
category: plan
status: draft
---

# Watch Posture UX + iPhone Sync + i18n

## Problem Statement

1. **톱니바퀴 버튼 가독성**: `CarouselHomeView.swift`의 자세 모니터링 설정 진입 톱니바퀴(gearshape)가 `font(.system(size: 12))`로 너무 작아서 탭하기 어려움
2. **iPhone 동기화 부재**: Watch에서 수집하는 오늘의 앉은 시간, 워킹 시간, 발송된 알림 횟수가 iPhone에서 볼 수 없음. WatchConnectivity를 통한 `DailyPostureSummary` 전송 경로가 없음
3. **다국어 누락**: PostureMonitorSettingsView와 PostureSummaryCard에 하드코딩 영어 문자열 존재

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNEWatch/Views/CarouselHomeView.swift` | 수정 | 톱니바퀴 아이콘 크기 확대 |
| `DUNEWatch/Views/PostureMonitorSettingsView.swift` | 수정 | 하드코딩 문자열 i18n 처리 |
| `DUNEWatch/Views/Components/PostureSummaryCard.swift` | 수정 | "Sitting today", "Gait" 등 i18n |
| `DUNEWatch/WatchConnectivityManager.swift` | 수정 | sendPostureSummary 추가 |
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | 수정 | 요약 전송 트리거 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | 수정 | postureSummary 수신 처리 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | 수정 | Watch 자세 요약 카드 추가 |
| `DUNEWatch/Resources/Localizable.xcstrings` | 수정 | ko/ja 번역 추가 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | iOS용 번역 추가 |
| (신규) `DUNE/Presentation/Wellness/Components/WatchPostureSummaryCard.swift` | 생성 | iPhone용 자세 요약 카드 뷰 |

## Implementation Steps

### Step 1: 톱니바퀴 버튼 크기 확대
- `CarouselHomeView.swift` line 121: `.font(.system(size: 12))` → `.font(.system(size: 17))`
- `.foregroundStyle(.secondary)` 유지
- watchOS 표준 toolbar 아이콘 크기(17pt)에 맞춤

### Step 2: Watch → iPhone 자세 요약 동기화
- `WatchConnectivityManager`에 `sendPostureSummary(_ summary: DailyPostureSummary)` 추가
  - `sendMessage` + `transferUserInfo` fallback
- `WatchPostureMonitor`에서 주기적으로 (활동 상태 전환 시 + 앱 foreground 시) 요약 전송
- `ParsedWatchIncomingMessage`에 `postureSummaryData: Data?` 필드 추가
- `WatchSessionManager.handleDecodedMessage`에서 postureSummary 디코딩 → stored property로 보관
- iOS `WatchSessionManager`에 `receivedPostureSummary: DailyPostureSummary?` 추가

### Step 3: iPhone Wellness 뷰에 Watch 자세 요약 카드
- `WatchPostureSummaryCard.swift` 생성: 앉은 시간, 워킹 시간, 알림 횟수 표시
- `WellnessView`의 Posture Assessment 섹션 위에 배치
- `WatchSessionManager`의 `receivedPostureSummary`를 environment로 전달

### Step 4: 다국어 처리
- Watch `PostureMonitorSettingsView`:
  - `"Tracks sitting time and walking posture using motion sensors."` → `String(localized:)`
  - `"Posture Monitoring"`, `"Stretch Reminder"`, `"Sitting"`, `"Walking"`, `"Gait Score"`, `"Reminders Sent"`, `"Today"`, `"Remind me to stretch after"` — 이미 LocalizedStringKey로 처리됨 확인 필요
- Watch `PostureSummaryCard`: `"Sitting today"`, `"Gait %lld"` 확인
- Watch xcstrings + iOS xcstrings에 ko/ja 번역 추가

## Test Strategy

- 빌드 검증: `scripts/build-ios.sh`
- WatchConnectivity 동기화: 실기기 필요 (시뮬레이터에서 WC 사용 불가)
- 다국어: xcstrings 파일에 번역 키 존재 확인

## Risks & Edge Cases

- WatchConnectivity가 비활성 상태일 때: 기존 패턴(transferUserInfo fallback) 따름
- Watch 미착용 시: iPhone 카드에 "No data from Watch" 상태 표시
- postureSummary 날짜 불일치: 자정 경계에서 reset될 수 있음 → date 필드로 당일 확인
