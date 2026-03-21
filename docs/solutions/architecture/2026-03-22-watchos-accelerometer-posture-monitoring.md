---
tags: [watchos, coremotion, accelerometer, posture, gait-analysis, sedentary-detection, battery]
date: 2026-03-22
category: architecture
status: implemented
---

# watchOS 가속도계 기반 일상 자세 모니터링

## Problem

사용자의 일상 자세를 패시브하게 모니터링하여:
1. 장시간 앉은 자세를 감지하고 스트레칭 알림 발송
2. 걸음걸이 품질을 분석하여 자세 피드백 제공

Apple Watch가 손목에 착용되므로 척추/어깨 직접 측정 불가 → 활동 상태 전환 + 보행 패턴 분석으로 접근.

## Solution

### 이중 센서 전략

| 센서 | API | 역할 | 배터리 |
|------|-----|------|--------|
| 활동 감지 | `CMMotionActivityManager` | 정적/걷기/달리기 상태 전환 | 극저 (OS 레벨) |
| 보행 분석 | `CMDeviceMotion` (50Hz) | 팔 흔들림 대칭성 + 보행 규칙성 | 중 (걷기당 10초만) |

### 핵심 아키텍처

```
PostureModels.swift (Domain Models)
  ├── PostureActivityState
  ├── GaitQualityScore
  └── DailyPostureSummary

GaitAnalyzer.swift (Pure Algorithm)
  └── CMDeviceMotion[] → GaitQualityScore

WatchPostureMonitor.swift (@Observable Manager)
  ├── CMMotionActivityManager → 앉은 시간 추적
  ├── CMDeviceMotion → GaitAnalyzer → 점수 계산
  ├── UNNotification → 스트레칭 알림
  └── buildDailySummary() → WatchConnectivity 전송용
```

### 배터리 보호 메커니즘

- **DeviceMotion 수집**: 걷기당 1회, 10초만, 5분 쿨다운
- **저배터리 억제**: Battery < 20% → DeviceMotion 수집 중단
- **재사용 OperationQueue**: 매 수집마다 새 큐 생성 방지

### 변경 파일

| File | Description |
|------|-------------|
| `DUNEWatch/Models/PostureModels.swift` | 도메인 모델 + 포맷팅 유틸 |
| `DUNEWatch/Managers/GaitAnalyzer.swift` | 걸음걸이 분석 알고리즘 |
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | 코어 모니터 (@Observable) |
| `DUNEWatch/Views/PostureMonitorSettingsView.swift` | 설정 UI |
| `DUNEWatch/Views/Components/PostureSummaryCard.swift` | 요약 카드 |
| `DUNE/project.yml` | CoreMotion.framework 의존성 |

## Prevention

### Swift 6 Concurrency + CoreMotion 패턴

1. **`nonisolated(unsafe) let`**: CoreMotion API는 자체 큐에서 동작 → MainActor 바운더리 넘나들 때 `nonisolated(unsafe)` 또는 `@Sendable` closure 필요
2. **Generation counter**: 비동기 센서 콜백이 in-flight일 때 stop 호출 → 세대 카운터로 stale 샘플 필터링
3. **Elapsed-time 누적**: `CMMotionActivityManager` 업데이트 간격은 비결정적(30초~수분) → 고정 1분 가산 금지, 실제 경과 시간 계산
4. **Daily reset**: 앱이 장시간 실행 중이면 자정 교차 시 리셋 누락 → periodic check에서 리셋 확인

### 리뷰에서 발견된 패턴

- **UserDefaults 캐싱**: `performance-patterns.md` 규칙 — computed property 금지, stored + setter 패턴
- **도메인 모델 분리**: 알고리즘 파일에 모델 혼합 금지 → 별도 Models/ 파일
- **의존성 주입**: `WorkoutManager.shared` 직접 참조 → `isWorkoutActive` 클로저 주입 (테스트 가능)
- **LocalizedStringKey**: View helper의 label 파라미터는 `String` 아닌 `LocalizedStringKey` (localization.md Leak Pattern 1)

## Lessons Learned

1. **손목 센서의 한계**: Watch 가속도계로는 척추/어깨 자세를 직접 측정할 수 없음 → 활동 패턴 + 보행 품질이 현실적 접근
2. **CMMotionActivityManager vs CMMotionManager**: 활동 감지는 저전력 API, DeviceMotion은 고전력 → 이중 전략으로 배터리 보호
3. **Swift 6 strict concurrency**: CoreMotion 콜백은 OperationQueue 스레드 → MainActor 전환 시 반드시 generation/cancellation guard
4. **watchOS 시뮬레이터 제한**: CMMotionManager는 시뮬레이터에서 미작동 → 실기기 테스트 필수
