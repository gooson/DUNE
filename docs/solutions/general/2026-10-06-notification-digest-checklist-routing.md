---
tags: [notification, navigation, daily-digest, life-checklist, legacy-payload]
date: 2026-10-06
category: solution
status: implemented
---

# 요약·체크리스트 알림의 빈 상세 화면 수정

## Problem

`Today's Summary`와 `Life Checklist` 예약 알림은 목적지를 `notificationHub`로 저장했다. 알림함은 이 목적지를 알림 본문만 다시 보여주는 `NotificationMessageDetailView`로 처리했다. 요약 알림은 실제로 생성된 요약을 보여주지 않았고, 체크리스트 알림은 습관을 확인하거나 완료할 수 있는 화면으로 이동하지 않았다.

## Solution

- `dailyDigest`, `lifeChecklist` 목적지를 추가했다. 요약은 Today의 실제 건강 데이터로 생성한 문장과 컨디션·수면·걸음 수를 보여주고, 체크리스트는 Life 탭의 `My Habits` 섹션으로 이동한다.
- 알림함 행과 시스템 알림 응답에 같은 목적지를 적용했다.
- 기존에 저장된 알림과 이미 예약된 `notificationHub` payload는 `insightType`으로 새 목적지를 복원한다.
- 나머지 알림 유형의 목적지를 점검했다. HRV, RHR, 수면, 걸음 수, 체성분 단일 지표는 지표 상세로, 자세·운동·취침 알림은 대응 기능 화면으로 연결된다. 여러 체성분 값을 합친 알림은 단일 지표로 잘못 표현하지 않도록 값이 포함된 알림 본문을 유지한다.

## Prevention

새 알림 유형에는 알림을 눌렀을 때 열 실제 화면을 지정한다. 예약 payload, 저장된 알림, 알림함 행, 콜드 스타트 응답을 함께 검증한다. 기존 payload 형식을 바꿀 때는 `insightType`을 이용한 이전 버전 복원 경로를 확인한다.

## Verification

- `scripts/build-ios.sh`: 통과.
- iPhone 18 Pro (iOS 27.0) 관련 단위 테스트: 34개 통과, 실패 0개.
- 같은 시뮬레이터의 알림 라우팅 UI 테스트: 5개 통과, 실패 0개. 시스템 알림 응답과 알림함 행에서 요약·체크리스트 화면을 확인했다.
