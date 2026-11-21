---
topic: SDK compiler warnings in Health Query, Cardio Atlas and metric labels
date: 2026-11-21
status: implemented
confidence: high
related_solutions: [2026-10-30-grounded-siri-health-queries]
related_brainstorms: []
---

# Xcode 경고 38건 정리

| 영향 파일 | 구현과 검증 |
| --- | --- |
| HealthQueryIntent | 두 경로에서 답변 ID를 지정하는 snippet 바인딩을 상수로 변경한다. |
| CardioAtlasPlacePicker, CardioAtlasPlaceSearch, CardioAtlasPlaceSearchTests | MKMapItem의 좌표와 전체 주소를 사용한다. 주소 없는 장소, 한글 주소 검색, 거리 정렬, 선택 시 이름 대체 순서를 확인한다. |
| HealthQueryResultCard | 메모를 단일 서식 문자열로 조립한다. 사용자 원문, 강조 색상과 굵기, 생략 기호, 최대 50개 일치 제한을 유지한다. |
| TrainingReadinessDetailView, CardioMachineLevelHistoryView, WellnessSleepSummaryCard, BodyHistoryDetailView, CardioSecondaryPage, SessionSummaryView | 접근성 레이블을 보간으로 조립한다. 날짜·숫자 형식, 단위, 현재 고도와 수면 기록이 없는 경우 및 한·영·일 번역을 확인한다. |

## 검증

iOS와 내장 Watch 타깃을 빌드하고 경고 로그를 확인한다. 장소 검색 회귀는 CardioAtlasPlaceSearchTests, 인텐트는 HealthQueryIntentContractTests로 검증한다. 문자열 카탈로그는 빌드 전후 수동 추출 상태를 확인한다. 화면 구성, 접근성 동작이나 문구가 달라지는 경우 해당 화면의 UI 검증을 추가한다.

빌드 중 발견한 Watch 메타데이터 추출 경고는 인텐트를 선언하지 않은 Watch 앱에 한해 처리한다. 단위 테스트 컴파일에서 추가로 발견한 경고는 해당 테스트의 단언과 실패·재시도 순서를 보존하며 수정한다.
