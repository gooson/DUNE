---
topic: watch-posture-not-worn-detection
date: 2026-04-05
status: approved
confidence: high
related_solutions: [docs/solutions/architecture/2026-03-22-watchos-accelerometer-posture-monitoring.md, docs/solutions/general/2026-03-22-watch-bedtime-reminder-restoration.md]
---

# Implementation Plan: 워치 자세 모니터링 — 미착용 시 안내 개선

## Context

현재 `WatchPostureSummaryCard`(iOS 웰니스탭)의 empty state는 두 가지만 구분:
1. Watch 앱 미설치 → "Apple Watch required"
2. Watch 앱 설치 + summary nil → "No posture data yet"

워치를 벗어놓거나 충전 중이면 `CMMotionActivityManager`가 activity 업데이트를 제공하지 않으므로
모니터링이 실질적으로 중단되지만, iOS 카드에서는 이를 구분하지 못한다.
사용자는 왜 데이터가 수집되지 않는지 알 수 없다.

## Requirements

### Functional

- Watch가 미착용 상태이면 iOS 웰니스탭에 "워치를 착용하세요" 안내를 표시한다.
- Watch에서 모니터링이 비활성화(사용자 설정 off)이면 "모니터링을 켜세요" 안내를 표시한다.
- Watch에서 모니터링이 활성화 상태이지만 데이터가 없으면 "워치를 착용하세요"를 표시한다.

### Non-functional

- 기존 `DailyPostureSummary` 전송 경로를 유지한다 (WC sendMessage + transferUserInfo).
- backward-compatible: 새 필드가 없는 기존 payload도 정상 처리.

## Approach

### 1. DailyPostureSummary에 모니터링 상태 추가

`DailyPostureSummary`에 `isMonitoringEnabled: Bool` 필드를 추가한다.
이 값은 Watch 설정의 posture monitoring on/off 상태를 반영한다.

### 2. WatchPostureMonitor에서 상태 포함 전송

`buildDailySummary()`에서 `isEnabled` 값을 summary에 포함한다.
`startMonitoringIfEnabled()`에서 disabled 상태여도 summary를 전송하여 iOS가 상태를 알 수 있게 한다.

### 3. WatchPostureSummaryCard empty state 분기 개선

| 조건 | 표시 |
|------|------|
| Watch 앱 미설치 | "Apple Watch required" (기존) |
| Watch 앱 설치 + summary nil | "Wear your Apple Watch" (변경) |
| Watch 앱 설치 + summary 있음 + isMonitoringEnabled == false | "Enable posture monitoring" |
| Watch 앱 설치 + summary 있음 + 데이터 모두 0 | "Wear your Apple Watch" |
| Watch 앱 설치 + summary 있음 + 데이터 있음 | metrics row (기존) |

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| WKApplication active state 감지 | 정확한 wrist 상태 | watchOS API 미제공, background 제약 | 기각 |
| DeviceMotion 인풋 유무 기반 추론 | 추가 인프라 불필요 | 지연 시간, false positive 가능 | 기각 |
| isMonitoringEnabled + 데이터 유무 | 단순, 정확한 설정 상태, 데이터 유무로 착용 추론 | 착용하고도 데이터 없는 초기 몇 분 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | Modify | `DailyPostureSummary`에 `isMonitoringEnabled` 필드 추가 |
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | Modify | `buildDailySummary()`에 `isEnabled` 포함, disabled 시에도 summary 전송 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | Modify | 새 필드 backward-compatible 디코딩 |
| `DUNE/Presentation/Wellness/Components/WatchPostureSummaryCard.swift` | Modify | empty state 분기 개선 |
| `Shared/Resources/Localizable.xcstrings` | Modify | 새 UI 문자열 en/ko/ja 추가 |
| `DUNEWatchTests/WatchPostureMonitorTests.swift` | Modify | 새 summary 필드 테스트 |
| `DUNEWatchTests/GaitAnalyzerTests.swift` | Modify | DailyPostureSummary Codable 테스트 업데이트 |

## Implementation Steps

### Step 1: DailyPostureSummary 모델 확장

`WatchConnectivityModels.swift`에 `isMonitoringEnabled: Bool` 추가.
backward-compatible을 위해 `CodingKeys` + custom `init(from:)` 사용.

### Step 2: WatchPostureMonitor 전송 로직 수정

- `buildDailySummary()`에 `isEnabled` 포함
- `startMonitoringIfEnabled()`에서 disabled 상태일 때도 iOS에 "monitoring disabled" summary 전송
- `setEnabled(false)` 시 disabled summary 전송

### Step 3: WatchSessionManager 디코딩 수정

`isMonitoringEnabled` 필드가 없는 기존 payload에 대해 `true` 기본값.

### Step 4: WatchPostureSummaryCard empty state 개선

5가지 상태 분기 구현 + 적절한 아이콘/메시지.

### Step 5: Localization

새 문자열 en/ko/ja 추가.

### Step 6: 테스트 업데이트

기존 DailyPostureSummary Codable 테스트 + WatchPostureMonitor 테스트 업데이트.

## Test Strategy

- **Unit**: DailyPostureSummary Codable round-trip (새 필드 포함/미포함)
- **Unit**: WatchPostureMonitor.buildDailySummary() 에 isEnabled 반영 확인
- **Unit**: WatchPostureSummaryCard의 각 상태별 표시 텍스트 검증 (가능하면)
- **Integration**: WatchConnectivity 경로에서 backward-compatible 디코딩

## Risks & Edge Cases

- **Backward compatibility**: 기존 Watch 앱이 새 필드 없이 전송 → `decodeIfPresent` + default true
- **초기 착용 직후 데이터 없는 짧은 구간**: 모니터링 enabled + 데이터 0 → "착용하세요" 표시되지만 1-2분 후 데이터 들어오면 자동 전환됨. 허용 가능한 UX
