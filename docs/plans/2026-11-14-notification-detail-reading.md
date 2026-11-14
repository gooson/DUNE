---
tags: [notification, T12, readability, body-composition]
date: 2026-11-14
category: plan
status: implemented-with-capture-limit
---

# T12 알림 상세 수치 강조

사진의 체성분 알림은 큰 종·제목 히어로와 작은 본문 카드로 구성돼 짧은 측정값을 찾기 어렵다. 사용자가 추가 개편을 요청했다. 기존 T12 계획의 후속 작업으로 제목 영역을 줄이고 저장된 측정 문장을 항목별 큰 값으로 배치한다.

## 배치와 데이터

- 작은 원래 유형 아이콘, 전체 제목, 실제 저장 시각을 하나의 헤더에 둔다.
- 체성분 유형의 본문 전체가 `이름: 값` 형식이면 원래 이름·값·단위·순서를 그대로 카드에 표시한다. ASCII/전각 콜론과 CRLF를 허용한다. 어느 한 줄이라도 해석할 수 없으면 본문 전체를 원문으로 표시한다. 일반 알림도 원문을 표시한다.
- 값의 수치 변환·판정·추세 추정 없이 표시 형태만 분리한다. 모델·저장 형식과 기존 목적지는 유지한다.
- 기본 글씨에서는 두 열, 접근성 글씨에서는 한 열이다. 본문 최대 폭은 680pt이며 모든 텍스트는 자연 높이와 스크롤·선택을 제공한다.

## Affected Files

| 파일 | 변경 |
|---|---|
| `NotificationHubView.swift` | 목적지에 실제 유형·시각 전달, 작은 헤더·원문/수치 카드 |
| `NotificationMessageContent.swift` | 체성분 문장 표시용 분리, 전체 원문 대체 |
| `NotificationMessageContentTests.swift` | 다국어·혼합 원문·빈 값·일반 알림 경계 |
| `TestDataSeeder.swift`, `DesignMapAdditionalRoutesTests.swift` | 사진과 같은 2수치 fixture, 값·시각·복귀·큰 글씨 |
| 레이아웃·테마·실제 화면맵 | 제안과 새 native 검증 출처를 구분 |

## Implementation Steps

1. 기존 레이아웃 계약·테마 시안과 이 계획에 후속 범위를 저장한다.
2. 표시 모델·뷰·필요한 테스트를 구현하고 단위별로 보존한다.
3. 표시 분리 단위 테스트, T12 일반/체성분/어두운 최대 글씨를 전용 iPhone에서 검증한다. iPad·Duo는 영향 화면 T12만 캡처하며 실행 제약 시 미갱신을 기록한다.
4. 새 실제 PNG·AX를 확인하고 맵과 검증 한계를 갱신한다.

## 검증 예산

한 worktree에서 한 실행기만 사용한다. 관련 unit/UI만 선택하며 unit/UI 각 1200초 deadline, build jobs 2, index store OFF를 따른다. 같은 원인 재시도는 근거가 있는 1회로 제한한다. Watch 추가 요청은 별도 cardio zone 계획·파일로 구현하고 실행은 순차 진행한다.

## 2026-11-14 검증 결과

- 문장 분리 단위 테스트 5개 통과. 초기 stale 파서 바이너리의 세 경계 실패를 보존했고 마지막 파서로 다시 컴파일한 결과를 사용한다.
- 최종 iPhone 체성분 기본·다크 최대 글씨와 일반 본문 다크 최대 글씨 3건 통과. 일반 본문의 기본 검사는 초기 집계 안에서 개별 통과했고 해당 기본 분기 출력은 동일하다. 날짜는 12·24시간 설정 차이를 반영한 테스트로 검증한다.
- iPad 기본 1건, Duo 접힘 1건 통과. 접힘은 전후 LCD active와 7 checkpoint ACK를 확인했다. 숫자 힌지 각도는 현재 CLI로 측정되지 않았다.
- [실제 PNG·AX와 출처](../design/full-redesign-map/review/notification-cardio-2026-11-14/index.html)에 완료한 T12만 출판했다. 기존 이미지·다른 화면의 출처를 유지한다.
- Duo 펼침은 setter 이후 LCD active/LCD-1 inactive여서 UI 실행 전에 중단했다. 공식 CLI 도움말과 검토된 setter의 실제 결과를 확인했고 기기 허브 접근도 Mac 잠금으로 차단됐다. 펼침 T12는 미갱신이다.
- 추가 Watch 요청 C01·C02: 사용자 승인 추가1회에서 러닝 시간 우선6존·계단6존·계단 미수신3개 UI 검사가 통과했다. 40mm 기본 글씨의 새2장과 출처를 실제 맵에 반영했고 하단 겹침 P2는 해소됐다. 큰 글씨·AOD·VoiceOver는 별도 미검증이다.
- 이전 운동 카테고리3개 커밋은 원래 브랜치에 보존하고 이번 PR에서 제외했다. 실제 기준은 최신 `origin/main`이며 앱/seed/선택 테스트 소스7개는 이전 통과본과 바이트가 동일하다. 원문 분리 unit·알림 UI 증거를 재사용했다.
