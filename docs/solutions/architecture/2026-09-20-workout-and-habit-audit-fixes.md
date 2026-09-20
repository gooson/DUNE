---
tags: [healthkit, deduplication, background-delivery, watchos, pause, habits, statistics]
date: 2026-09-20
category: architecture
status: implemented
---

# 운동 집계·백그라운드 완료·습관 달성 판정 일관성

## Problem

- 주간 통계용 ManualExerciseSnapshot에 HealthKit 연결 ID가 없어 같은 운동을 로컬 기록과 HealthKit에서 각각 합산했다.
- HKObserverQuery 콜백의 defer가 비동기 처리 Task 생성 직후 실행되어 처리 완료 전에 백그라운드 전달을 종료했다.
- Watch 운동 중 타이머는 일시정지를 제외하지만 종료 요약, 저장, MET 칼로리 추정은 시계상 경과 시간을 사용했다.
- 습관 관리와 streak는 목표 미달 기록도 완료로 세고, 보고서는 개별 로그만 검사해 같은 날 나눈 입력과 중복 로그를 다르게 집계했다.

## Solution

1. 운동 snapshot에 healthKitWorkoutID를 보존한다. TrainingVolumeAnalysisService가 유효한 로컬 기록에 연결된 HealthKit 운동을 제외한 뒤 현재·이전 기간 및 일별 기록을 집계한다. 로컬 종목과 세트 볼륨은 유지하며, 연결되지 않은 운동은 유지한다.
2. HealthKit observer 오류에서는 즉시 completion을 호출하고, 정상 경로에서는 refresh·알림·취침 일정 처리가 끝난 뒤 호출한다. SDK의 non-Sendable completion은 잠금으로 한 번만 소비하는 wrapper로 Task에 전달한다.
3. WorkoutManager에서 종료 순간의 activeElapsedTime을 고정한다. 종료 중인 pause도 제외하고 요약 화면을 오래 열어 둬도 시간이 증가하지 않는다. 요약 표시·종목별 배분·저장·MET 계산이 같은 시간을 사용한다. 새 운동과 reset에서 고정값을 지운다.
4. HabitStreakService.completedDates에서 습관별 일별 합계를 목표와 비교한다. skip/snooze 및 비정상 값을 제외하고 하루 한 번만 달성으로 집계한다. 관리 화면, streak, 주간·월간 보고서, heatmap이 같은 판정을 사용한다. 관리 화면 캐시는 로그 값과 목표 변경도 감지한다.

## Validation

- 각 수정 커밋의 iOS 앱 빌드 통과(embedded Watch 포함).
- Watch 시뮬레이터 런타임이 없어 실제 WorkoutElapsedTime 소스를 임시 macOS Swift package에 추출해 테스트했다. 시간 계산 및 기존 저장·전송 회귀 테스트 8개 통과.
- iPhone 17 / iOS 27.0: 고유 단위 테스트 75개(매개변수별 80회) 통과. 최초 74개 실행 후 프로젝트를 재생성해 새 observer 테스트를 포함하고, 최종 LifeViewModel 수정도 재검증했다. 실패·스킵 0건.
- iPhone 18 Pro / iOS 27.0: 주간 통계 요약·기간 전환 및 습관 화면 UI 테스트 3개 통과.
- SwiftUI 상태 갱신, Apple UX 표시 일관성, 테스트 커버리지 관점의 자체 검토 완료. UI 배치와 조작 방식 변경은 없다.

## Prevention

- 여러 저장소를 집계하는 snapshot은 원본의 연결 ID를 보존한다. 기간별 요약과 과거 차트에도 같은 중복 제거를 적용한다.
- 외부 시스템에 전달하는 완료 신호는 Task 생성 시점이 아니라 비동기 처리 완료 시점에 보낸다.
- 운동의 표시·저장·칼로리 계산은 같은 종료 시점의 pause-aware 시간을 사용한다.
- 습관 달성은 로그 수가 아니라 일별 목표 충족 여부로 판정하며 모든 통계에서 재사용한다.

## Lessons Learned

연결 ID, 완료 시점, 목표값은 단순 부가 정보가 아니라 집계의 정확성을 결정하는 입력이다. 이를 변환이나 비동기 경계에서 잃지 않도록 하고 중복·지연·부분 입력을 회귀 테스트로 고정한다.
