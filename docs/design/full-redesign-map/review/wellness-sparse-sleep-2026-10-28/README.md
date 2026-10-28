---
tags: [wellness, sleep, sparse-data, design-map, ios, ipados]
date: 2026-10-28
category: solution
status: reviewed
---

# 최근 수면의 적은 기록 배치 수정

[새 실제 화면10장](index.html) · [개별 출처](manifest.json) · [검증 기록](proof/verification.json)

`52988932`의 실제 앱을 전용 iPhone18 Pro와 iPad Pro13-inch(M5)에서 실행했다. 실제 사용자의 건강 기록이 아닌 UI 전용 fixture다. 수면 기록1·2·4·7개, 중간 결측일을 포함한다. 막대는16pt 폭, 날짜 위치는 오늘까지7칸이며 누락일에는 막대를 그리지 않는다. 한 기록은 평균을 표시하지 않는다.

| 대상 | 최신 소스 검사 | 새 원본 |
|---|---|---|
| iPhone · 밝음 · 1/2/4/7개 | `testSparseSleepBarsKeepCalendarPositionsAndWidth` 통과 | 4장 |
| iPhone · 다크/최대 접근성 글씨 · 2개 | `testSparseSleepDarkAndAccessibility` 통과 | 2장 |
| iPad · 밝음 · 1/2/4/7개 | `testSparseSleepBarsKeepCalendarPositionsAndWidth` 통과 | 4장 |

최신 소스3개 device-case가 통과했다. 일반 iPhone의0개 빈 상태와 수면/예측의 독립 상세 진입은 최초 실행에서 각각 통과했다. 그 이후 변경은 값이 있는 그래프·날짜 축·평균 줄바꿈과 캡처 정렬에 한정되어 빈 분기와 내비게이션 목적지의 통과 결과는 재사용한다. 이를 최신 소스에서 전부 다시 실행한 것으로 계산하지 않는다.

최초 실행은4개 중2개 통과·2개 실패했다. 그래프 상위 식별자가 개별 막대의 식별자를 덮은 실제 AX 트리를 확인하고 상위 식별자를 제거했다. 관련2건의 조건부 재실행은 통과했다. 이어 육안 검사에서 최대 글씨의 날짜가 말줄임표로 보이는 별도 문제를 발견했다. 날짜 축을 독립3개 레이블로 바꾸고 평균의 줄바꿈을 허용한 최신 소스에서 위3개 device-case를 확인했다. 실패 결과도 proof에 보존한다.

최초 테스트 종료 후 Xcode의 `simctl diagnose`가 결과 정리를 지연했다. 종료된 테스트의 실패 로그를 유지하고 해당 실행의 정확한 부모 PID·대상 UDID를 확인한 뒤 진단 수집 자식만 종료했다. 다른 테스트나 기기는 중단하지 않았다. 이후 DesignCapture plan으로 진단 자동 수집을 제외했다.

두 번의 프로젝트 필수 iOS 빌드가 통과했다. 최종 빌드 로그는 `proof/ios-build-final.log.gz`에 보존한다. 문자열 카탈로그 포맷, diff 공백 검사, 테마 맵 동기화도 통과했다. 새 번역 키·점수 계산·HealthKit 쿼리·저장 스키마·테마 팔레트 변경은 없다.

자동 UI 범위 판정은 test fixture의 Data 경로 때문에 full fallback이다. production 기본 데이터는 환경값이 없으면 기존 경로를 유지하고 fixture는 `--uitesting`에서만 동작한다. 호출부는 iOS Wellness의 카드 한 곳이며 Watch·Vision View는 바뀌지 않았다. 전체 회귀는 요청되지 않아 이 카드의 관련 targeted 검사로 한정했다.

## 미갱신 범위

H01의 Duo 접힘·펼침, iPad 다크·최대 글씨, 다른 언어/테마와 실제 HealthKit 권한은 이번 실행에서 별도로 확인하지 않았다. 전용 iPhone의 신고 상태와 iPad의 넓은 폭을 우선하는 bounded 검증 범위다. 해당 기기·상태의 별도 UI 실행과 새 캡처가 재개 조건이며 이전 Flow66장을 이번 수정의 증거로 바꾸지 않는다. iPhone PNG는 그래프와 날짜 축에 맞춰 스크롤한 상태이며 상단 제목/최신 값은 내비게이션 뒤에 있을 수 있다. 이는 카드 잘림의 증거가 아닌 스크롤 위치다. iPad PNG에서는 수면 카드 전체를 확인한다. 최대 글씨의 평균은 줄바꿈하고 세 날짜는 말줄임 없이 표시됨을 새 PNG에서 확인했다.
