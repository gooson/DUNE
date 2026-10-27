---
tags: [wellness, sleep, chart, sparse-data, swiftui]
date: 2026-10-28
category: plan
status: implemented
---

# Wellness 최근 수면의 적은 기록 배치 수정

## 문제와 완료 기준

표본이 적으면 `Capsule`이 가로 공간을 채워 수면 시간을 세로 길이로 비교하기 어렵다. 7일 달력 위치를 고정하고 실제 기록만 폭16pt의 세로 막대로 표시한다. 누락일과0시간은 다르므로 누락일에 막대를 그리지 않는다. 평균·최신 기록·수면 상세의 기존 의미를 유지한다.

## Affected Files

| 파일 | 변경 |
|---|---|
| `WellnessSleepSummaryCard.swift` | 고정 날짜 슬롯·막대 폭·큰 글씨 날짜 축 |
| `SimulatorAdvancedMockData.swift` | UI 전용0/1/2/4/7개 기록 fixture, 중간 결측 포함 |
| `WellnessFlowUITests.swift` | 실제 폭·슬롯·평균 유무·빈 상태·다크/최대 글씨 검증 |
| 디자인맵·해결책 | 새 캡처와 검증 범위 기록 |

## Implementation Steps

1. 기존 레이아웃·테마 기준과 첨부 화면을 대조한다.
2. V1 가변 폭 제한 후 V2로7일 날짜 축과 빈 슬롯을 적용한다.
3. 전용 iPhone에서0/1/2/4/7개, 다크/최대 글씨, 독립 상세 진입을 targeted 검증한다.
4. 넓은 화면은 iPad에서 동일 fixture로 확인한다. Duo의 접힘·펼침은 동일 컴포넌트 영향 대상으로 명시하고 새 캡처 여부를 구분한다.
5. 새 실제 PNG·출처와 해결책을 보존하고 디자인맵에서 연결한다.

전체 UI 회귀는 요청 범위 밖이며 실행하지 않는다. 점수 계산·저장·HealthKit 실제 쿼리는 변경하지 않는다.

최신 소스 `52988932`에서 iPhone2·iPad1개 device-case가 통과했고, 별도 최초 실행의0개 빈 상태·상세 진입2개는 변경되지 않은 분기/경로의 결과를 재사용했다. iOS 빌드 통과. [새 원본10장과 미검증 범위](../design/full-redesign-map/review/wellness-sparse-sleep-2026-10-28/index.html)를 따른다.
