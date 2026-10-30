---
tags: [local-time, timezone, morning-briefing, coaching, today, regression]
date: 2026-10-31
category: general
status: implemented
---

# 로컬 시간에 맞는 아침 인사와 Today 인사이트

## Problem

자정에 앱을 열어도 브리핑이 자동 표시되고 제목은 `Good Morning`이었다. 표시 여부가 마지막 표시 날짜만 비교하고 시간을 검사하지 않았기 때문이다. 날짜 포매터의 시간대도 최초 생성 시점에 고정되어 있었다. 컨디션 상세의 `Today's Insight`는 점수만 보고 야간에도 운동을 권했고, AI 코칭에는 현재 로컬 시간 정보가 없었다.

## Solution

- `LocalDayPeriod`: 기기 로컬 시간 06:00–09:59 아침, 10:00–16:59 낮, 17:00–21:59 저녁, 22:00–05:59 밤. 11:59는 아침 인사 대상이 아니다.
- `MorningBriefingViewModel`: 로컬 아침에만 하루 한 번 자동 표시한다. 기존 `lastBriefingDate` 형식은 유지하고 호출 시점 시간대로 날짜를 계산한다. 야간 수동 열람은 아침 표시 기회를 소비하지 않는다.
- `MorningBriefingView`: 아침 밖에서 수동으로 열면 기능명 `Morning Briefing`을 제목으로 쓴다. 열린 상태에서 시간 경계를 지나면 제목도 갱신한다.
- `ConditionInsightGuidance`: 현재 로컬 밤에는 컨디션 점수와 관계없이 휴식 안내를 사용한다. 실제 컨디션 상태 설명은 유지한다.
- `CoachingEngine.generate(localHour:)`: Today 하단 인사이트의 야간 운동 권유·낮의 야외 운동 제안을 회복 안내로 대체한다. 회복·수면 경고와 폭염·한파 정보는 유지한다. Dashboard는 야간에 숨겨지는 브리프의 핵심 인사이트도 하단에 포함한다. 다른 소비자는 기존 생성 동작을 유지한다.
- `DashboardViewModel`·`DashboardView`: 기존 시간대 분류를 공용 모델로 연결하고, 분 단위 확인·앱 활성화·시간대 변경 때 시간 의존 문구를 갱신한다. 건강 데이터 전체를 다시 조회하지 않는다.
- `AICoachingMessageService`: 로컬 시각·시간대와 인사 금지, 야간 운동 시작 권유 금지를 프롬프트에 전달한다. 시간대가 바뀐 뒤 도착한 이전 AI 응답은 적용하지 않는다. 프롬프트 제약 검증과 실제 생성 결과의 품질은 구분한다.
- DEBUG `DashboardClock`: 기존 `--ui-dashboard-hour`를 브리핑·Today·상세 화면이 함께 사용한다. 실제 기기 시간을 변경하지 않는다.

## Verification

`LocalTimePresentationTests`, `AICoachingMessageServiceTests`, `CoachingEngineTests`의 최종 단위 테스트 40개가 통과했다 (`.xcodebuild/local-time-unit-final.log`). 24시간 인사 경계, 09:59/10:00/11:59, 서울·UTC·미국 서부, 야간 표시 기회 보존, 야간 운동 권유 제거 및 중요 정보 보존을 포함한다.

iPhone UI 2건, iPad·Duo 접힘·펼침 각 1건이 통과했고, 펼침의 검은 XCTest PNG를 대체하는 native 캡처 경로도 추가 1건 통과했다. [새 실제 PNG 17장과 실행별 출처](../../design/phone-design-map/actual/local-time-2026-10-31/index.html)를 통합 실제 화면맵에 연결했다. T03·T04·T09의 영향 문구를 육안으로 확인했다. Watch는 영향이 없다. 카탈로그 형식·manual 추출 상태 검사도 통과했다.

## Prevention

- 날짜가 바뀐 것과 아침이 된 것을 별도로 검사한다.
- 인사는 측정 데이터의 날짜나 UTC가 아닌 현재 기기 로컬 시각으로 결정한다.
- 00:00·05:59·06:00·09:59·10:00·11:59와 동일 순간의 시간대 차이를 회귀 검증한다.
- UI fixture의 시각과 사용자 설정을 고정하고, 아침 자동 표시를 기대하는 기존 캡처도 명시적으로 오전 6시를 사용한다.

## Lessons Learned

아침 브리핑이라는 기능명만으로 표시 시각이 제한되지는 않는다. 자동 표시 조건, 제목, 인사이트, AI 입력이 같은 로컬 시각 기준을 사용해야 한다.
