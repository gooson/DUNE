---
topic: Watch workout Live Activity
date: 2026-10-24
status: approved
confidence: high
related_solutions:
  - architecture/2026-09-20-iphone-duo-adaptive-experience.md
  - general/2026-10-14-rest-live-activity-layouts.md
related_brainstorms:
  - 2026-03-03-watch-cardio-fitness-style-ui.md
---

# Implementation Plan: Watch 운동 라이브 액티비티

## Context

기존 라이브 액티비티는 iPhone 세트 사이 휴식에만 연결되어 Watch에서 시작한 운동은 나타나지 않는다. DUNE Watch의 근력·유산소 세션 전체를 iPhone 잠금 화면과 Dynamic Island에 표시한다.

## Requirements

- Watch 운동 시작 시 iPhone이 잠겨 있어도 HealthKit mirroring으로 앱을 깨우고 라이브 액티비티를 요청한다.
- 운동명, 활성 경과 시간, 심박수, 활동 칼로리와 유효한 거리를 표시한다. 일시 정지 시 시간을 멈추고 종료·연결 해제 시 제거한다.
- Live Activity 비활성화·미러링 실패가 Watch 운동 기록을 막지 않는다. 기존 휴식 타이머와 완료 기록 동기화는 유지한다.
- 민감한 운동 수치를 로그에 공개하지 않고, 잘못된 수치·순서가 뒤바뀐 업데이트를 거부한다.

## Approach

Watch `HKWorkoutSession.startMirroringToCompanionDevice()`와 iPhone의 앱 초기화 시 등록하는 `workoutSessionMirroringStartHandler`를 사용한다. SDK의 HKHealthStore.h는 이 handler의 background Live Activity 일회성 시작 권한을 명시한다. handler에서 첫 데이터 도착을 기다리지 않고 기본 운동 상태로 즉시 시작한 뒤 소형 Codable snapshot을 5초 간격과 상태 변경 시 전달한다. 기존 WatchConnectivity는 완료 기록용으로 유지한다.

공식 근거: https://developer.apple.com/videos/play/wwdc2023/10023/ · https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler

### Alternatives

| 방법 | 판단 |
|------|------|
| WatchConnectivity만 사용 | 백그라운드 Live Activity 시작 권한이 없어 제외 |
| 원격 push-to-start 서버 | 서버·토큰 관리 없이 해결 가능한 범위여서 제외 |
| 기존 휴식 attributes 재사용 | 운동 전체와 countdown 의미가 달라 별도 attributes 사용 |

## Affected Files

| 파일 | 변경 |
|------|------|
| Shared/WatchWorkoutSnapshot.swift | 검증 가능한 공통 snapshot 계약 |
| Shared/WatchWorkoutAttributes.swift | 별도 ActivityKit attributes |
| DUNEWatch/Managers/WorkoutManager.swift | 미러링과 snapshot 송신·복구·정리 |
| DUNE/Presentation/Exercise/WatchWorkoutMirrorManager.swift | 조기 handler 등록, 수신·상태 lifecycle |
| DUNE/Presentation/Exercise/WatchWorkoutActivity.swift | 직렬 ActivityKit 시작·갱신·종료 |
| DUNE/App/DUNEApp.swift | 앱 초기화 시 handler 설치 |
| DUNEWidget/WatchWorkoutLiveActivity.swift | 잠금 화면·Dynamic Island·small family |
| DUNEWidget/WellnessDashboardWidget.swift, DUNE/project.yml | 위젯과 공통 소스 등록 |
| DUNETests/WatchWorkout*Tests.swift | snapshot 검증·순서·일시 정지·종료 회귀 |
| Shared/Resources/Localizable.xcstrings | 필요한 신규 문구 en/ko/ja |
| docs/design/layout-map/, docs/design/phone-design-map/ | 별도 시스템 화면 맵 및 캡처 상태 |

## Implementation Steps

1. snapshot/attributes 계약과 검증을 구현한다. Codable roundtrip, NaN/Infinity/음수, 오래된 상태를 테스트한다.
2. Watch 미러링과 iPhone 수신을 연결한다. 초기 handler에서 즉시 요청하고 ActivityKit 작업은 직렬 처리한다. 종료·재연결 경합을 검증한다.
3. 기존 휴식 위젯 패턴에 맞춰 운동 Live Activity를 추가하고 번역과 디자인맵을 동기화한다.
4. 빌드, 관련 unit/UI, 5관점 리뷰와 품질 검토, 해결책 문서, PR 생성·merge를 수행한다.

## Edge Cases / Risks

| 상황 | 대응 |
|------|------|
| iPhone 백그라운드 초기 실행 | handler를 앱 init 최우선에 등록하고 snapshot을 기다리지 않음 |
| 미러링 실패·권한 없음 | 기록 세션을 유지하고 실패를 기록 |
| 정지·재개 | 활성 누적 시간과 상태 timestamp로 표시 |
| 종료·새 세션·지연된 callback | 세션 identity와 직렬 ActivityKit 작업으로 이전 callback 배제 |
| Watch 복구 | 복구된 세션에 mirroring과 송신 재설정 |
| 기기 단절·프로세스 종료 | delegate 정리 및 staleDate로 오래된 숫자 표시 방지 |
| 시뮬레이터 HealthKit 제한 | seed 경로로 시스템 표면을 검증하고 실제 쌍 기기 검증은 별도 명시 |

## Testing Strategy

- `scripts/build-ios.sh`: iOS + embedded Watch/widget 컴파일.
- 관련 Swift Testing만 선택 실행: snapshot/수신 state machine/ActivityKit driver mock의 lifecycle.
- `scripts/plan-ui-tests.py --base main` 초기·최종 분석. 변경한 운동 플로우 targeted smoke만 실행하며 full 미실행은 명시한다.
- Live Activity 실제 시스템 캡처: 가능한 iPhone portrait running/paused/Dynamic Island. 테스트 통과와 실제 캡처 증거를 구분한다.
- 실제 Watch↔iPhone: 잠긴 iPhone에서 시작, 근력/유산소, 일시 정지/재개, 종료, 연결 해제, 복구. 연결된 실기기가 없으면 미검증으로 기록한다.

## Confidence

높음: 공식 mirroring background-start 계약과 기존 Watch 세션 공통 시작 경로를 활용한다. 시스템 표면 및 쌍 기기 실행은 환경에 의존한다.
