---
tags: [notification, T12, readability, body-composition]
date: 2026-11-14
category: plan
status: implementing
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
