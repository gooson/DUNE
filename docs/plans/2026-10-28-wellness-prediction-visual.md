---
tags: [wellness, sleep, prediction, visual, accessibility]
date: 2026-10-28
category: plan
status: in-progress
---

# 오늘 밤 수면 카드의 시각적 위계

텍스트만 이어지는 예측 카드를 큰 점수·달 상징·0–100 게이지·신뢰도 배지·실제 팁 영역으로 나눈다. 수면색과 기존 카드, 상세/펼침 경로를 유지한다. 큰 글씨는 세로 배치와 자연 줄바꿈을 사용한다. 가상 단계나 추세·확률을 만들지 않는다.

## Affected Files

| 파일 | 내용 |
|---|---|
| WellnessSleepPredictionCard.swift | 점수 그래픽·신뢰도·팁·반응형 배치 |
| WellnessViewModel.swift | 기존 UI 전용 예측 fixture의 점수·신뢰도 선택 |
| WellnessFlowUITests.swift | 0/37/78/100·신뢰도·펼침·상세·큰 글씨·빈 상태 |
| 디자인맵 | 새 캡처와 검증 범위 |

## Implementation Steps

1. 레이아웃/테마 기준과 기존 예측 모델을 대조한다.
2. V1 점수/달, V2 게이지·신뢰도·팁 강조를 적용한다.
3. 기존 전용 iPhone에서 두 신규 검사와 상세 진입을 확인하고 iPad에서 기본 크기의 상태를 확인한다.
4. 원본 PNG·소스/기기 출처와 미갱신 범위를 기록한다. 전체 회귀는 실행하지 않는다.
