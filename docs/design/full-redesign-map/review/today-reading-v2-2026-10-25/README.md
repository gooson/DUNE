---
tags: [today, swiftui, typography, dynamic-type, actual-capture]
date: 2026-10-25
category: testing
status: partial
---

# Today 하단 V2 실제 화면

[갤러리](index.html) · [출처 목록](capture-index.json) · [방향 시안](../../../theme-map/themes/dune-today-reading.html)

T03 회복·수면, 장기 스트레스, 오늘의 요약을 전용 iPhone 18 Pro / iOS27.0 / Xcode27.1에서 캡처했다. UDID는 `526653E1-C06C-4033-81F2-44E2693A0542`다. 고정 시각21시, ko_KR, seeded fixture, 자동 Morning Briefing 비활성 조건이다. 데이터 수치는 사용자 사진의 실제 건강 데이터가 아니다.

`TodayReadingUITests` 7건이44018fcc에서 모두 통과했다. 밝음·어두움·최대 접근성 글씨(AXXXL), 근거·원문 펼치기, 수면·스트레스 상세 진입, T10 일간 요약 소비자를 포함한다. 새 `testCurrentDeviceReadingCards`는 기본 밝음에서 세 카드의 주요 위치를 별도로 캡처한다. 갤러리16장은 T03의 원본 캡처다. 수면 기본 그래프의0·5·10눈금과 날짜를 육안 확인했다. 최대 글씨 화면은 긴 카드의 일부 viewport라 전체 차트/원문이 한 화면에 표시되는 것을 보증하지 않는다. 가로 겹침 없이 세로로 흐르는 가시 영역을 확인했다.

후속14d37e32는 T10 중복 지표와 빈 기록 판정, 중복 clamp를 수정했다. T03의 기존 캡처와 후속 수정의 소스 리비전을 혼동하지 않는다. 수정 전 T10 PNG는 갤러리에서 제외했고 최종 재검증 후 새 캡처로 교체한다.

| 영향 기기/상태 | 현재 증거 |
|---|---|
| iPhone T03 기본 밝음·어두움·AXXXL |44018fcc 실제 PNG16장 |
| iPhone T10 |44018fcc 기능 검사는 통과했으나 후속 중복 제거14d37e32의 캡처 대기 |
| iPad T03/T10 |시뮬레이터 잠금60초 대기에서2회 모두 시작 전 종료; 추가 자동 재시도 중단 |
| Duo 접힘·펼침 T03/T10 |같은 잠금 자원을 사용할 수 없어 미실행·미캡처 |
| Watch |변경된 카드 소비자 없음, 영향 제외 |

다른 기기의 새 PNG가 없어 기존 `actual/regular`·`ipad`·`duo`·`duo-open` 인덱스와 보드를 덮어쓰지 않았다. 통합 실제 화면 포털은 이 별도 갤러리로 연결한다. 기본 DUNE 외 다른 테마, 다른 OS, 실제 HealthKit 권한/센서 상태, 회전과 전체 UI 회귀는 이번 증거에 포함하지 않는다.

초기 공통 UI는36건 중34건 통과했다. 실패한2건은 변경되지 않은 DashboardSmokeTests의 알림함 진입과 최대 글씨 알림함 검사다. 실패 PNG에는 자동 Morning Briefing 시트가 앞에 있었다. 해당 경로를 수정하거나 재시도하지 않고 새 Today 클래스7건으로 영향 범위를 재확정했다. 이 결과를 전체 UI 통과로 보고하지 않는다.
