---
date: 2026-10-28
status: implemented
category: plan
tags: [watchos, stair-climber, location, reminder]
---

# 계단 기구 이탈 후 종료 안내

## 문제와 선택

계단 기구에서 내려와 밖에서 걸어도 종료 안내가 없다. 이전 HealthKit 보행 거리 기반 추정은 기구 위에서도 증가하는 값을 실제 이동으로 해석해 오탐했으므로 복원하지 않는다. 손잡이를 잡아 지표가 정적인 경우에도 일반 정지 알림과 자동 종료는 계속 제외한다.

## 구현

### Affected Files

| 파일 | 변경 |
|---|---|
| `DUNEWatch/Managers/StairMachineExitDetector.swift`, `StairMachineExitMonitor.swift` | GPS·걸음 기반 판단과 권한/위치 수집 생명주기 |
| `DUNEWatch/Managers/WorkoutManager.swift` | 계단 세션 연결, 안내 상태와 계속 운동 선택의 복구 |
| `DUNEWatch/Views/SessionPagingView.swift`, Watch `Resources/` | 시스템 확인창과 en/ko/ja 문구·권한 설명 |
| `DUNEWatchTests/StairMachineExit*Tests.swift`, `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | 감지·권한·복구·계속/종료 회귀 검증 |
| `DUNE/project.yml`, 생성 프로젝트 | CoreLocation과 새 소스·리소스 등록 |
| `docs/design/layout-map/`, `docs/design/phone-design-map/` | C10/C19 배치 기준과 실제 화면 출처 |

### Implementation Steps

1. 계단 운동 중에만 Core Location을 사용한다. 정확도 20m 이내의 최근 위치로 60초 이상·오차를 제외한 순이동 100m 이상·40걸음 이상·위치 표본 4개 이상을 함께 확인한다. 운동 시작 120초 전에는 안내하지 않는다. 긴 수집 공백·순서 역전·차량 속도·GPS 급변은 후보를 폐기한다. 실내에서 GPS를 받지 못해도 실외 첫 유효 위치부터 관찰할 수 있다.
2. C10은 기존 계단 진행 화면, C19는 시스템 종료 확인 안내다. 진동과 함께 종료/계속 운동만 제공한다. 안내 중 기록과 시간은 계속 증가한다. 응답 없음은 자동 종료 근거가 아니며, 계속 운동을 선택하면 해당 세션에서 다시 묻지 않는다.
3. 위치 권한 요청 이유를 en/ko/ja로 제공한다. 거부·정확도 부족은 운동을 방해하지 않는다. 위치는 메모리에서만 처리하고 저장·전송하지 않는다. 일시정지·종료·초기화 시 수집을 중단하고 재개 시 후보를 새로 만든다.

## 변경 범위와 검증

- Watch Managers의 감지기·위치 수집기·WorkoutManager 연결, SessionPagingView 알림, Watch Info 및 번역 리소스.
- 감지기 단위 테스트: 실제 이탈·정적 GPS·걸음만 증가·오차·지연·급변·수집 공백·중복 억제.
- Watch UI: C10 무알림 지속, C19 안내·계속 운동·명시적 종료. 새 원본 캡처를 디자인맵에 연결한다. iPhone/iPad/Duo 화면은 변경하지 않는다.
- HealthKit/GPS 실기기 센서와 손목을 내린 백그라운드 진동은 시뮬레이터로 인증하지 않는다.

공식 참고: [Apple Core Location 백그라운드 위치](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background). 임계값은 제품의 보수적인 초기 정책이며 Apple의 보장값이 아니다.

## 결과

최종 관련 Watch 단위 34개·최초 UI 3개와 최종 문구 UI 1개 통과, C10/C19 실제 화면 갱신. 같은 세션 복구 후에도 ‘계속 운동’ 선택을 유지한다. [구현·검증과 실기기 제한](../solutions/general/2026-10-28-watch-stair-gps-exit-reminder.md)을 따른다.
