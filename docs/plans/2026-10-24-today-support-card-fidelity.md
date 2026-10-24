---
tags: [design, dashboard, spacing, sleep]
date: 2026-10-24
category: plan
status: implemented-pending-device-validation
---

# Today 보조 카드 시안 적용

수정 후 실제 화면을 제공한다. 최종 시안의 T03 진행·브리핑·회복 세 카드에 한정하며 다른 세 탭의 검토 항목은 별도로 남긴다.

## Affected Files

| 대상 | 변경 |
|---|---|
| DashboardSupportCard·DailyProgressRingCard·TodayBriefCard | 보조 표면·17pt 패딩·18pt 모서리, 균등 목표 타일, 정보 위계 |
| RecoverySleepCard·DashboardView·DashboardViewModel | 실제 지난 수면 단계 연결, 날짜 범위·축 여유 |
| Localizable.xcstrings | 추가 문구 en/ko/ja |
| TodaySupportCardsUITests | 밝음·어두움·큰 글씨 배치와 새 캡처 |
| 실제 화면맵·리뷰 보고서 | 새 PNG 출처, 남은 항목 구분 |

## Implementation Steps

1. 기존 시안의 17pt 패딩·18pt 모서리·보조 표면을 전용 컴포넌트로 적용한다. 공통 InlineCard는 일괄 변경하지 않는다.
2. 진행에 실제 10,000걸음·8시간 목표를 표시하고 두 항목을 같은 폭으로 배치한다. 큰 글씨에서는 쌓는다.
3. 날씨 권한·실제 코칭을 보존하면서 브리핑 헤더·제안·상세 행동을 구분한다.
4. 실제 수면 단계가 있으면 지난 수면의 시간·날짜·타임라인을 보여 준다. 없으면 임의 단계·시각을 만들지 않는다. 수면 부족 계산은 변경하지 않는다.
5. 수면 이력은 실제 표시 범위의 날짜를 명시하고 축 눈금 여유를 확보한다. 7개 기록을 무조건 7일로 표시하지 않는다.
6. 전용 iPhone의 영향 단위·UI 검증과 캡처 후 육안 확인한다. iPad도 영향 화면만 확인하고 Duo의 기존 보류 상태는 유지한다.

## 완료 기준

새 캡처에서 균등 목표 타일·카드 좌우 정렬·축 잘림을 확인한다. 기기·테스트·revision을 보존한다. 기존 시안을 기준으로 앱을 수정한다.

## 결과

제품 소스 `29e54f9a`, iPhone UI 테스트 2건 통과와 실제 PNG 6장을 [검증 기록](../design/full-redesign-map/review/today-support-cards-2026-10-24/README.md)에 보존했다. iPad·Duo와 추가 단위 검사는 공통 시뮬레이터 잠금 해제 후 재개할 대상으로 남긴다. 전체 기기 품질 게이트 통과나 배포 완료로 표시하지 않는다.
