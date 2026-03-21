---
topic: watchos-accelerometer-posture-monitoring
date: 2026-03-22
status: draft
confidence: medium
related_solutions: []
related_brainstorms:
  - 2026-03-15-posture-assessment-system
---

# Implementation Plan: watchOS 가속도계 기반 일상 자세 모니터링

## Context

TODO #136. Apple Watch 가속도계/자이로스코프를 활용하여 일상 중 자세를 패시브하게 모니터링.
카메라 기반 자세 분석(iOS)은 주기적 측정인 반면, 이 기능은 일상 모니터링으로 보완.

### 기술적 현실

Watch는 **손목**에 착용 → 척추/어깨 자세를 직접 측정할 수 없음.
대신 다음을 추론할 수 있음:

1. **활동 상태 전환** (CMMotionActivityManager) → 장시간 앉은 자세 감지 → 스트레칭 알림
2. **걸음걸이 품질** (CMDeviceMotion) → 팔 흔들림 대칭성, 보행 규칙성, 손목 기울기 패턴

### 기존 코드베이스 활용

| 기존 컴포넌트 | 재활용 | 위치 |
|-------------|--------|------|
| `MotionTrackingService` | CMPedometer 패턴 참고 (NSLock, snapshot) | `DUNE/Data/Motion/` |
| `MotionTrackingServiceProtocol` | 프로토콜 패턴 참고 | `DUNE/Domain/Services/` |
| `PostureReminderScheduler` | 알림 스케줄링 패턴 참고 | `DUNE/Data/Services/` |
| `WorkoutManager` | Watch @Observable 싱글턴 패턴 참고 | `DUNEWatch/Managers/` |
| `WatchConnectivityManager` | Watch↔iPhone 데이터 전송 | `DUNEWatch/` |

## Requirements

### Functional

- 장시간 정적 자세(앉기/서기) 감지 후 스트레칭 알림 (configurable 간격, 기본 45분)
- 걸음걸이 품질 점수 (0-100): 팔 흔들림 대칭성 + 보행 규칙성
- 일일 자세 요약: 앉은 시간, 서있는 시간, 걸음걸이 점수 평균
- 설정 on/off 토글 (Watch 설정 + iPhone 설정 동기화)
- 일일 요약을 iPhone으로 WatchConnectivity 전송

### Non-functional

- 배터리 영향 최소화: CMMotionActivityManager 사용 (저전력), CMDeviceMotion은 걷기 시에만 제한적 수집
- Swift 6 strict concurrency 준수 (@Sendable, actor isolation)
- Domain 레이어에 CoreMotion import 금지
- watchOS 26+ 전용

## Approach

### 이중 센서 전략

1. **CMMotionActivityManager** (항시 저전력): 활동 상태 변화 감지 (stationary/walking/running)
   - 앉은 시간 누적 → 임계값 초과 시 로컬 알림
2. **CMDeviceMotion** (걷기 시에만 수집): attitude/userAcceleration 분석
   - 걷기 감지 → 10초간 50Hz 샘플링 → 걸음걸이 점수 계산 → 중단
   - 배터리 보호: 걷기당 최대 1회, 5분 쿨다운

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| CMMotionManager 상시 수집 | 최대 정확도 | 배터리 급속 소모 | **거부** |
| CMMotionActivityManager만 | 최소 배터리 | 걸음걸이 분석 불가 | 절반 채택 (활동 감지) |
| **이중 전략 (Activity + 제한적 DeviceMotion)** | 균형있는 배터리/기능 | 구현 복잡도 증가 | **채택** |
| HealthKit 워크아웃 세션 배경 실행 | 안정적 배경 실행 | 운동 세션 충돌 | **거부** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | **New** | CMMotionActivityManager + CMDeviceMotion 통합 모니터 |
| `DUNEWatch/Managers/GaitAnalyzer.swift` | **New** | DeviceMotion → 걸음걸이 점수 계산 |
| `DUNEWatch/Views/PostureMonitorSettingsView.swift` | **New** | Watch 설정 토글 + 임계값 조절 |
| `DUNEWatch/Views/Components/PostureSummaryCard.swift` | **New** | 일일 자세 요약 카드 |
| `DUNEWatch/DUNEWatchApp.swift` | **Modify** | PostureMonitor 인스턴스 주입 |
| `DUNEWatch/ContentView.swift` | **Modify** | 자세 요약 카드 추가 |
| `DUNEWatch/WatchConnectivityManager.swift` | **Modify** | 자세 데이터 전송 메서드 추가 |
| `DUNEWatch/Resources/Info.plist` | **Modify** | NSMotionUsageDescription 추가 |
| `DUNE/project.yml` | **Modify** | DUNEWatch target에 CoreMotion.framework 의존성 추가 |
| `Shared/Resources/Localizable.xcstrings` | **Modify** | en/ko/ja 번역 추가 |
| `DUNEWatch/Resources/Localizable.xcstrings` | **Modify** | Watch 전용 문자열 추가 |
| `DUNETests/GaitAnalyzerTests.swift` | **New** | 걸음걸이 분석 유닛 테스트 |
| `DUNETests/WatchPostureMonitorTests.swift` | **New** | 모니터 로직 유닛 테스트 |

## Implementation Steps

### Step 1: Domain 모델 + 프로토콜 정의

- **Files**: `DUNEWatch/Managers/WatchPostureMonitor.swift` (프로토콜 부분)
- **Changes**:
  - `PostureActivityState` enum: `.stationary`, `.walking`, `.running`, `.unknown`
  - `GaitQualityScore` struct: `symmetry: Double`, `regularity: Double`, `overall: Int`
  - `DailyPostureSummary` struct: `sedentaryMinutes: Int`, `standingMinutes: Int`, `walkingMinutes: Int`, `averageGaitScore: Int?`, `stretchRemindersTriggered: Int`, `date: Date`
  - `WatchPostureMonitorProtocol` 정의
- **Verification**: 컴파일 통과

### Step 2: GaitAnalyzer 구현

- **Files**: `DUNEWatch/Managers/GaitAnalyzer.swift`, `DUNETests/GaitAnalyzerTests.swift`
- **Changes**:
  - `CMDeviceMotion` 배열 (10초 분량) → 걸음걸이 점수 변환
  - 팔 흔들림 대칭성: pitch oscillation의 좌우 peak 대칭 비교
  - 보행 규칙성: userAcceleration.y의 peak interval 표준편차
  - 최종 점수: `(symmetry * 0.5 + regularity * 0.5) * 100` → 0-100 정수
  - 입력값 범위 검증: acceleration magnitude guard, NaN/Inf 방어
- **Verification**: 유닛 테스트 통과

### Step 3: WatchPostureMonitor 코어 구현

- **Files**: `DUNEWatch/Managers/WatchPostureMonitor.swift`, `DUNETests/WatchPostureMonitorTests.swift`
- **Changes**:
  - `@Observable @MainActor final class WatchPostureMonitor`
  - `CMMotionActivityManager.startActivityUpdates` → 활동 상태 추적
  - 정적 상태 시간 누적 (sedentaryTimer)
  - 임계값 초과 시 `UNUserNotificationCenter` 로컬 알림
  - 걷기 감지 시 `CMMotionManager.startDeviceMotionUpdates` → 10초 후 자동 중단
  - 일일 요약 집계 로직
  - NSLock 기반 thread-safety (MotionTrackingService 패턴)
- **Verification**: 유닛 테스트 + Watch 시뮬레이터 실행

### Step 4: 프로젝트 설정 업데이트

- **Files**: `DUNE/project.yml`, `DUNEWatch/Resources/Info.plist`
- **Changes**:
  - DUNEWatch dependencies에 `CoreMotion.framework` 추가
  - Info.plist에 `NSMotionUsageDescription` 추가
  - xcodegen 재생성
- **Verification**: `scripts/build-ios.sh` 성공

### Step 5: Watch UI — 설정 뷰 + 요약 카드

- **Files**: `DUNEWatch/Views/PostureMonitorSettingsView.swift`, `DUNEWatch/Views/Components/PostureSummaryCard.swift`, `DUNEWatch/ContentView.swift`
- **Changes**:
  - 설정 토글: 모니터링 on/off, 알림 간격 (30/45/60분)
  - 요약 카드: 오늘 앉은 시간, 걸음걸이 점수 (걷기 있었으면)
  - ContentView 홈에 카드 통합
- **Verification**: Watch 시뮬레이터 Preview

### Step 6: WatchConnectivity 동기화

- **Files**: `DUNEWatch/WatchConnectivityManager.swift`
- **Changes**:
  - `sendPostureSummary(_ summary: DailyPostureSummary)` 메서드 추가
  - 일일 자정에 전날 요약 전송 (또는 앱 재활성화 시)
- **Verification**: Watch 시뮬레이터 → iPhone 시뮬레이터 데이터 전달 확인

### Step 7: Localization

- **Files**: `DUNEWatch/Resources/Localizable.xcstrings`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - 새 문자열 en/ko/ja 3개 언어 등록
  - Watch 전용 문자열은 Watch xcstrings에만
  - `String(localized:)` 패턴 준수
- **Verification**: 번역 키 누락 없음

### Step 8: DUNEWatchApp 통합 + 알림 권한

- **Files**: `DUNEWatch/DUNEWatchApp.swift`
- **Changes**:
  - `WatchPostureMonitor` 인스턴스 생성 및 environment 주입
  - 앱 시작 시 모니터링 활성화 여부 확인 + 시작
  - UNUserNotificationCenter 권한 요청 (이미 있으면 스킵)
- **Verification**: Watch 앱 실행 시 모니터링 시작 확인

## Edge Cases

| Case | Handling |
|------|----------|
| CoreMotion 권한 거부 | 설정 화면에 권한 안내 메시지 표시, 모니터링 비활성 |
| 시뮬레이터에서 CMMotionManager 미지원 | `isDeviceMotionAvailable` 체크 + 시뮬레이터 fallback (mock 데이터 모드) |
| 운동 세션 중 중복 알림 | `WorkoutManager.isActive` 확인 → 운동 중에는 앉은 시간 카운터 일시정지 |
| 수면 중 오탐 | 야간 시간대(22-06시) 알림 자동 억제 |
| 배터리 부족 시 | Battery level < 20% → DeviceMotion 수집 중단, ActivityManager만 유지 |
| 걷기 10초 미만 | GaitAnalyzer에 최소 5초 데이터 요구, 미달 시 점수 산출 건너뜀 |
| 하루 동안 걷기 없음 | `averageGaitScore: nil`로 처리, 카드에 "No walking data" 표시 |

## Testing Strategy

- **Unit tests**:
  - `GaitAnalyzerTests`: 대칭/비대칭 모션 데이터로 점수 검증, NaN/빈 배열 방어
  - `WatchPostureMonitorTests`: 상태 전환 로직, 타이머 누적, 알림 트리거 조건
  - `DailyPostureSummary` 집계 정확성
- **Manual verification**:
  - Watch 시뮬레이터에서 설정 토글 동작 확인
  - 실기기 필요 (CMMotionManager는 시뮬레이터에서 미작동)
  - 배터리 영향 모니터링 (Instruments Energy gauge)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시뮬레이터에서 CoreMotion 미작동 | 높음 | 높음 | 시뮬레이터 감지 → mock 모드 자동 전환 |
| 배터리 소모 과다 | 중간 | 높음 | DeviceMotion은 걷기당 10초만 수집 + 5분 쿨다운 |
| 걸음걸이 점수 정확도 부족 | 중간 | 중간 | MVP는 상대적 비교 중심, 절대 점수 보정은 후속 작업 |
| WorkoutManager 세션과 충돌 | 낮음 | 높음 | CMMotionActivityManager는 세션 무관, DeviceMotion만 운동 중 억제 |
| WatchConnectivity 전송 실패 | 낮음 | 낮음 | 로컬 저장 우선 + 다음 활성화 시 재전송 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**:
  - CMMotionActivityManager 기반 앉은 시간 감지는 확실 (Apple API 안정)
  - 걸음걸이 점수 알고리즘은 학술 연구 기반이지만 Watch 손목 데이터 특유의 노이즈 보정 필요
  - 시뮬레이터 테스트 제한이 있어 실기기 검증 필수
  - 배터리 영향은 제한적 DeviceMotion 수집으로 관리 가능하나 실측 필요
