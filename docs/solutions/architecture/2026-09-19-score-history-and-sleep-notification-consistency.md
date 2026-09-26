---
tags: [charts, cancellation, trend-line, sleep, healthkit, notification]
date: 2026-09-19
category: solution
status: implemented
---

# 점수 차트와 수면 알림의 데이터 일관성

## Problem

- Condition·Wellness·Readiness 상세의 추세선은 데이터 조회 또는 토글 시에만 계산되어 과거로 스크롤하면 이전 날짜 범위에 남았다.
- Wellness·Readiness 상세는 비동기 결과로 화면 상태를 바꾼 뒤 취소 여부를 검사했다. 이전 기간 조회가 늦게 완료되면 새 차트, 오류, 로딩 상태를 덮어쓸 수 있었다.
- 수면 알림은 자정 이후 시작한 anchored delta를 전체 수면 시간처럼 합산했다. 밤을 넘는 수면과 분할 동기화에서 불완전한 총량을 사용했다.

## Solution

### 점수 차트

- 세 ViewModel의 scrollPosition 변경 시 추세선을 재계산한다. 데이터가 부족한 창에서는 nil로 지워 오래된 선을 제거한다.
- Wellness·Readiness는 기존 Condition 상세와 같은 요청 ID 방식으로 최신 요청을 판정한다.
- 조회 시작 시 period를 캡처한다. await 이후 데이터 반영 전, 오류 반영 전, 로딩 종료 시 요청 ID를 검사한다. 취소된 요청은 화면 상태를 수정하지 않는다.
- day 조회에 저장된 점수 서비스가 없는 경우 하위 점수도 함께 비운다.

### 수면 알림

- sleepAnalysis 관찰 이벤트는 anchor 조회를 거치지 않고 SleepQuerying.fetchLastNightSleepSummary를 호출한다.
- SleepQueryService의 기존 수면 창·소스 중복 제거·늦은 기상 처리를 재사용한다.
- SleepNotificationResolver는 전체 요약으로 오늘의 수면 시간을 대체한 뒤 수면 부족 또는 완료 알림을 평가한다.
- 요약 누락·비정상 총량·조회 오류에서는 부분 데이터로 대체하지 않고 알림을 생략한다.

## Validation

- 앱 빌드 성공.
- iPhone 17 / iOS 27.0: 관련 유닛 테스트 43개, 매개변수별 53회 실행 통과. 실패 및 스킵 0건.
- 회귀 테스트에는 세 점수 차트의 과거·빈 구간 이동, 취소를 무시한 지연 응답/오류, 새 요청의 로딩 상태 보존을 포함한다.
- 수면 회귀 테스트에는 부분 기록 20분을 전체 480분으로 대체, nil/0/음수/NaN/Infinity 및 조회 오류, anchor 샘플 없이 관찰 이벤트 처리까지 포함한다.
- iPhone 18 Pro / iOS 27.0: Condition·Wellness·Readiness 추세선 스크롤 UI 테스트 3개 최종 통과.
- UI 테스트는 기존 seeded/mock 긴 기록을 사용해 각 점수 화면에서 Trend를 켜고 가로 드래그한다. 기존 UI 테스트 전용 probe를 재사용해 추세선 endpoint 날짜가 이동하는지 확인한다. probe는 `--uitesting`에서만 표시된다.

## Prevention

- UI 테스트는 번역된 버튼명 대신 안정된 accessibilityIdentifier를 사용하고, UIKit 기반 probe는 SwiftUI의 상위 ID 상속 영향을 받으므로 고유 label prefix로 조회한다.
- 파생 차트 데이터의 의존값에는 원본 데이터뿐 아니라 현재 보이는 날짜 범위도 포함한다.
- 취소 검사는 상태 변경 전에 수행하고, 오래된 요청의 오류·defer 처리도 최신 요청의 상태를 건드리지 않게 한다.
- HealthKit anchored query 결과는 증분이다. 일/밤 단위 총량이 필요하면 원본 서비스로 전체 구간을 조회한다.

## Lessons Learned

같은 데이터를 표시하더라도 계산 시점과 조회 범위가 다르면 화면과 알림이 서로 다른 결과를 보일 수 있다. 최신 요청과 전체 조회 범위를 명시적으로 유지해야 한다.
