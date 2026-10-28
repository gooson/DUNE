---
tags: [wellness, sleep, prediction, swiftui, visual-hierarchy, accessibility]
date: 2026-10-28
category: solution
status: reviewed
---

# 수면 예측 카드의 텍스트 위계와 시각 정보

## Problem

오늘 밤 수면의 점수·해석·신뢰도·팁을 같은 정렬의 텍스트로 이어 표시해 점수가 작고 카드 오른쪽은 비어 보였다. 낮은 신뢰도와 낮은 점수도 다른 의미인데 비슷한 본문으로 읽혔다.

## Solution

예측 점수는 큰 숫자와 실제0–100 가로 게이지로, outlook은 기존 달 SF Symbol과 문구로 표시한다. 신뢰도는 실제 low/medium/high의3단계 배지와 기존 문구를 함께 사용한다. 팁은 수면색의 옅은 별도 영역으로 구분한다. 링을 추가하거나 가상 시간·단계·추세를 만들지 않는다. 큰 글씨는 세로 배치와 자연 줄바꿈을 사용한다. 상태는 기존 모델이 제공하고 상세와 기록 펼침은 독립 동작을 유지한다.

## Prevention

대표37점·낮은 신뢰도 다크, 78점·보통 신뢰도 밝음, 점수0/100 경계, 큰 글씨와 예측 없음을 구분해 확인한다. 빈 일별 수면 목록만으로 예측이 없다고 가정하지 않는다. 기존 단계 요약의 fallback이 있으므로 UI 전용 none fixture로 카드의 빈 상태를 명시한다. 실제 기본 데이터 경로는 바꾸지 않는다.

스크롤 캡처에서 midpoint hittable만으로 텍스트 전체가 보인다고 판단하지 않는다. 특히 큰 글씨 배지는 전체 frame과 탭바/내비게이션을 대조한다.

## Lessons Learned

값의 크기·게이지·상징·배경 영역을 사용하면 같은 데이터와 문구를 유지하면서 읽기 순서를 만들 수 있다. 신뢰도를 확률로 바꾸거나 장식 그래프를 실제 추세처럼 보이게 만들 필요가 없다. Astra 검토와 [실제 화면·검증 범위](../../design/full-redesign-map/review/wellness-prediction-visual-2026-10-28/index.html)를 함께 보존한다.
