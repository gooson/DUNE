---
tags: [charts, interaction, overlay, drag, wellness, shared-components, ux]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 공통 차트 드래그 선택 정확도 및 근접 오버레이 개선

## Problem Statement

현재 상세 차트 공통 컴포넌트는 `chartXSelection` 기반 선택과 상단 고정형 `ChartSelectionOverlay`를 사용한다. 이 구조는 구현은 단순하지만, 실제 사용성 측면에서 두 가지 문제가 있다.

- 롱프레스 후 좌우 드래그 시 손가락 위치와 선택된 데이터 포인트가 어긋나 보일 수 있다
- 날짜/값 오버레이가 차트 상단 고정이라 사용자가 현재 어떤 점을 보고 있는지 즉시 연결하기 어렵다

BMI 화면에서 이 문제가 가장 눈에 띄지만, 실제 원인은 특정 화면이 아니라 공통 차트 컴포넌트 구조에 있다. 따라서 개별 차트 보정보다 공통 선택 시스템 자체를 재설계해야 한다.

핵심 목표는 다음 두 가지다.

1. 롱프레스 후 드래그 시 선택 포인트가 손가락과 시각적으로 일관되게 따라오도록 만든다
2. 날짜/값 오버레이를 선택된 그래프 포인트 근처에 띄워 인지 연결성을 높인다

## Target Users

- Health 상세 차트에서 최근 추세를 직접 탐색하는 iPhone 사용자
- BMI, Weight, Sleep, Steps, HRV, RHR 등 여러 메트릭을 동일한 인터랙션 방식으로 사용하고 싶은 사용자
- 작은 화면에서도 손가락 가림 없이 값을 빠르게 읽고 싶은 사용자

## Success Criteria

1. 롱프레스 후 드래그 시 선택 Rule/Point가 사용자의 손가락 위치와 자연스럽게 대응한다
2. 선택 오버레이가 항상 해당 포인트 근처에 표시되어 시선 이동이 줄어든다
3. 오버레이가 좌우 끝점과 상하 경계에서 카드 밖으로 잘리지 않는다
4. `Area`, `Dot`, `Bar`, `Range` 등 공통 차트 전체에서 동일한 상호작용 규칙이 적용된다
5. `week`, `month`, `sixMonths`, `year` 등 모든 기간에서 동작이 일관된다

## Proposed Approach

### 1) 기본 `chartXSelection` 의존도를 줄이고 직접 선택 좌표를 계산

공통 차트에서 기본 `chartXSelection`만 사용하는 대신 `chartOverlay` + `ChartProxy` + `GeometryReader` 조합으로 plot area 좌표를 직접 읽는다.

- 롱프레스 시작 후 드래그를 활성화
- 현재 터치 위치를 plot area 좌표계로 정규화
- 해당 x 위치에 가장 가까운 데이터 포인트를 직접 선택
- 선택 상태를 `selectedDate`뿐 아니라 화면 좌표까지 함께 보관

이 구조로 바꾸면 스크롤 가능한 차트, 축 여백, mark width 차이 때문에 생기는 체감 오차를 더 정확하게 제어할 수 있다.

### 2) 공통 선택 모델 도입

현재는 각 차트가 `selectedDate -> selectedPoint`만 계산한다. 이를 공통 구조로 확장한다.

- 선택된 데이터 포인트
- plot area 기준 anchor position
- 오버레이가 위/아래 어느 쪽에 배치되어야 하는지
- 좌우 clamp 결과

즉, 선택 로직과 오버레이 배치 로직을 각 차트에서 반복하지 않고 공유 가능한 형태로 추상화한다.

### 3) 오버레이를 상단 고정형에서 포인트 근접형으로 변경

기존 `ChartSelectionOverlay`는 차트 상단 전체 폭을 차지하는 헤더형이다. 이를 선택된 포인트 근처에 떠 있는 플로팅 캡슐 형태로 바꾼다.

- 기본 배치: 선택 포인트 위쪽
- 상단 공간 부족 시: 선택 포인트 아래쪽
- 우측 끝점 근처: 왼쪽으로 clamp
- 좌측 끝점 근처: 오른쪽으로 clamp
- 카드 경계를 넘지 않도록 최종 위치 보정

이렇게 하면 사용자는 수직 가이드선, 선택 점, 날짜/값 정보를 하나의 시야 영역에서 읽을 수 있다.

### 4) 차트 유형별 mark 표현은 유지하고 선택 시스템만 공통화

차트별 시각 언어는 그대로 두되 선택 방식만 통합한다.

- `AreaLineChartView`: 선택 점 + 수직 Rule + 근접 오버레이
- `DotLineChartView`: 선택 점 + 수직 Rule + 근접 오버레이
- `BarChartView`: 선택 막대 강조 + 수직 Rule + 근접 오버레이
- `RangeBarChartView`: 선택 바 강조 + 수직 Rule + 근접 오버레이

즉, 차트 종류별로 다른 것은 mark 스타일뿐이고, selection gesture / anchor / overlay placement는 공유한다.

### 5) 전 기간 일괄 대응

이번 범위는 일부 기간만 먼저 고치는 방식이 아니라 전체 기간을 한 번에 정리한다.

- `week`, `month`: 일 단위 선택 정확도
- `sixMonths`: 주 단위 집계에서 주 시작점 기준 선택 일관성
- `year`: 월 단위 집계에서 월 버킷 선택 일관성
- 스크롤 가능한 가로 차트에서도 보이는 영역 기준으로 자연스럽게 동작

## Constraints

- 공통 차트 컴포넌트 구조를 유지하면서 변경해야 한다
- 상세 화면별 개별 핫픽스가 아니라 shared chart layer에서 해결해야 한다
- 기존 trend line, y-axis scale, scroll position, accessibility descriptor 동작은 깨지면 안 된다
- 선택 오버레이 추가로 차트 레이아웃이 흔들리거나 높이가 변하면 안 된다
- 다크 테마/현재 디자인 시스템의 glass surface 스타일과 시각적으로 맞아야 한다

## Edge Cases

1. 첫 포인트 또는 마지막 포인트 선택 시 오버레이가 카드 밖으로 나가는 문제
2. 최고점 근처에서 오버레이가 위로 잘리는 문제
3. 최저점 근처에서 아래 배치 시 x축 라벨과 겹치는 문제
4. 데이터 포인트가 매우 적을 때와 매우 많을 때 선택 반응 차이
5. `sixMonths`/`year`처럼 집계 버킷이 큰 경우 실제 날짜와 선택 버킷 체감이 어긋나는 문제
6. 차트를 수평 스크롤한 직후 선택을 시작할 때 좌표계가 흔들리는 문제
7. 동일 값이 연속된 평평한 선 그래프에서 어느 포인트가 선택되었는지 인지가 약한 문제

## Scope

### MVP (Must-have)

- [ ] 공통 차트 선택 방식을 `chartOverlay` 기반 직접 좌표 계산으로 전환
- [ ] 선택 상태에 포인트 좌표/오버레이 anchor 정보를 포함하는 공통 모델 도입
- [ ] `ChartSelectionOverlay`를 포인트 근접형 플로팅 오버레이로 개편
- [ ] `AreaLine`, `DotLine`, `Bar`, `RangeBar` 전체 차트에 동일한 동작 적용
- [ ] 좌우 끝점 clamp, 상하 반전 배치, 카드 내부 보정 처리
- [ ] `week`, `month`, `sixMonths`, `year` 전 기간 검증

### Nice-to-have (Future)

- [ ] 오버레이 진입/이탈 모션을 더 정교하게 다듬기
- [ ] 선택 포인트에 더 강한 haptic 단계 추가 검토
- [ ] iPad 가로폭에서 오버레이 정보량 확장
- [ ] VoiceOver 사용자를 위한 선택 포인트 낭독 패턴 강화

## Open Questions

1. 공통 선택 모델을 차트별 로컬 `@State`로 둘지, 재사용 가능한 modifier/helper로 분리할지 구현 시 결정이 필요하다
2. 롱프레스 시작 임계값과 드래그 민감도는 실제 디바이스 테스트로 최종 조정이 필요하다
3. 오버레이가 점 위/아래로 이동할 때 애니메이션 강도를 어느 정도까지 줄지 결정이 필요하다

## Next Steps

- [ ] `/plan common-chart-selection-overlay` 으로 구현 계획 생성
