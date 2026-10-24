---
tags: [design, dashboard, spacing, sleep]
date: 2026-10-24
category: plan
status: implemented-validation-blocked
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

## /run 검증·출시 계획

2026-10-24 사용자가 `/run`을 요청했다. 현재 브랜치의 Today 보조 카드 변경을 대상으로 Plan→Work→UI→Review→Quality→Resolve→Compound→Pre-Ship→Ship를 수행한다. 기존 계획을 보강하며 다른 세 탭의 이전 시안 차이를 새 기능으로 확장하지 않는다.

### 조사와 기존 패턴

- 진행·브리핑·회복 카드의 실제 호출부는 DashboardView다. `latestSleepStages` 추가 프로퍼티는 Dashboard에서만 소비한다. 기존 수면 부족 계산·저장 구조는 변경하지 않는다.
- `2026-03-29-observation-tracking-feedback-loop.md`의 weather/coaching `@State` 캐시 경계를 유지한다.
- 기존 차트 축 잘림 해결책과 SwiftUI 차트의 clipping 규칙을 대조한다. 축 숫자의 공간을 확보하면서 `.clipped()`를 유지한다.
- 관련 brainstorm과 완료 TODO를 검색했다. 이번 브랜치에 해당하는 열린 TODO 파일은 없다.
- 새 SDK API 도입은 없다. 저장소의 `.plotDimension(padding:)` 사용례와 Apple 디자인 로컬 layout reference를 대조한다.

### 테스트 전략

1. `scripts/build-ios.sh`로 새 파일이 등록된 현재 프로젝트의 iOS 빌드를 확인한다.
2. 미실행된 DashboardViewModel 수면 연결 테스트 두 개를 전용 iPhone에서 제한 실행한다. 기존 단위 실행기가 selector를 지원하지 않으므로 저장소 잠금·deadline·동일 xcodebuild 설정을 적용한 제한 호출을 사용한다. 전체 단위 테스트로 확장하지 않는다.
3. UI 계획기를 실행하고 실제 소비자를 대조해 Today 지원 카드 테스트와 Dashboard smoke를 선택한다. 이전 UI 2건은 소스·환경 증거가 충분한 경우만 재사용하며, 새로 필요한 selector를 실행한다. iPad와 Duo의 영향 T03 캡처는 공통 잠금과 전용 기기 소유권이 확보된 후 진행한다.
4. iPhone의 기존 기본·최대 글씨 실제 PNG는 새 이미지로 위장하지 않는다. 소스가 바뀌면 영향을 받는 상태를 새로 촬영하고 출처를 갱신한다.
5. 앱 외형을 바꾸지 않는 문서·출시 변경은 앱 전체 UI를 다시 실행할 근거로 사용하지 않는다.

### 위험·엣지 케이스

- 겹치는 수면 구간은 가장 늦은 종료 시각을 사용한다. 누락·빈 자료·비유한 값에서는 임의 단계나 시간을 만들지 않는다.
- 큰 글씨에서 진행 타일은 세로로 배치하고 코칭·경고 문장은 잘리지 않아야 한다.
- 무효화된 권한·부분 실패 후 이전 수면 단계가 남는지 리뷰한다.
- 시간제한·잠금 실패는 환경 실패로 기록하고 원인 변화가 확인될 때만 1회 재시도한다. 실행 중 커밋 훅의 로그 정리를 피하고 검증 로그는 `.codex-checks/`에 보존한다.
- iPad·Duo 미검증은 iPhone 통과로 대신하지 않는다. 최신 소스에 필요한 게이트를 통과하지 못하면 PR 머지를 완료로 표시하지 않는다.

### 출시

현재 diff의 5관점 리뷰와 SwiftUI·Apple UX·UI 테스트 판단을 모아 P1/P2를 해결한다. 최종 소스 기준 해결책 문서를 작성하고 clean 상태·원격 권한·기존 PR을 확인한 뒤 PR 생성·머지·전용 시뮬레이터와 브랜치 정리를 수행한다.

## /run 현재 결과 (2026-10-24)

- Work: 제품 UI·지표/단계 동시 반영, 단계 범례/시간 단위, 필수 브리핑 존재 검사 구현과 커밋 완료. 최신 iOS 빌드56cab7da 성공.
- 단위: 정확한 Swift Testing 식별자4개 실행4/통과4(2c1380d4).
- UI: 공통+Today32개 실행29개 통과3개 실패. 알림2건은 기준과 동일한 자동 브리핑 시트가 앞에 있어 탭하지 못했으며 기준 소스 비교는 공용 잠금으로 미실행. 회복 카드 스크롤1건은 재검증 후 실제 탭바 경계와 일치한 카드가 검사 도구의 임의4pt 여유에 걸린 것으로 확인했다.
- 330dd2eb: 실제 뷰포트 경계로 검사 코드를 수정·구문 확인·커밋했다. 자동 재시도 한도 이후의 추가 실행 승인을 요청했으며, 응답 전 해당 검사를 다시 실행하지 않는다.
- 새 실제 iPhone PNG5장과 출처를 보존했다. iPad·Duo 접힘·펼침의 새 캡처는 미실행이다.
- 5관점 소스 검토와 SwiftUI·Apple UX·UI 범위·앱 품질 검토 결과를 준비했다. 새 코드의 열린 P1/P2/P3는0/0/0이나 필수 UI 게이트는 미완료다. Phase3 이후의 완료나 PR 머지로 표시하지 않는다.
