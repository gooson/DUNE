---
tags: [design, watch, cardio, heart-rate-zone]
date: 2026-11-14
category: plan
status: source-prepared-native-validation-pending
---

# C01·C02·C05–C07 · 시간 우선 유산소 심박 존

[DUNE 정적 시안](../theme-map/themes/dune-watch-cardio-time-zone.html)은 배치 검토용 예시이며 실제 Watch 캡처가 아니다. 기존 [러닝 거리 존 계약](watch-running-zone-proposal.md)과 동일한 현재 존 출처를 사용한다.

## 화면 계약

시간 우선 페이지는 종목과 작은 칼로리 값 → 큰 경과 시간 → 거리/페이스 또는 머신 레벨 → 한 줄의 심박·현재 존 → 얇은 `HRZoneBar` 순서다. 칼로리는 상단 오른쪽에 단위와 함께 둔다. 계단 운동의 레벨 숫자와 경과 시간 크기를 유지하고, 40mm 기본 글씨에서 심박·존·막대와 칼로리를 스크롤 없이 첫 화면에 배치한다. 큰 글씨에서 공간이 부족하면 기존 세로 스크롤로 접근한다. 러닝 거리 우선 페이지와 전용 존 페이지의 내비게이션은 유지한다.

`WorkoutManager.displayedZoneIndex`와 `displayedZoneCount`를 직접 사용한다. 5존 추정 또는 HealthKit의 가변 존 수에 따라 막대 칸 수가 바뀌며, 색은 기존 `HRZoneBar.color`를 사용한다. 존이 없으면 `Zone --`와 강조되지 않은 막대가 나온다. 심박은 별도로 `-- bpm`을 유지한다. 숫자/텍스트를 함께 제공해 색만으로 상태를 전하지 않는다.

## 검증 범위

- C02 계단 운동: 레벨·심박·칼로리와 존/막대 공존, 6존 및 심박 없음에서 첫 화면 프레임 확인.
- C01 러닝 시간 우선 보조 페이지: 기존 거리 우선 페이지와 같은 존 번호·칸 수.
- C05–C07 다른 시간 우선 유산소: 같은 컴포넌트 경로로 표시.
- 40mm 기본·큰 글씨·Always-On·VoiceOver는 네이티브 실행 후 별도로 확인한다. 이 문서는 실제 캡처 완료를 주장하지 않는다.

실제 디자인맵의 영향 화면 ID는 C01, C02, C05, C06, C07이다. 캡처 및 실제 맵 갱신은 Watch 실행 후 진행한다.
