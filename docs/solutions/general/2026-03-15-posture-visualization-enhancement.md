---
tags: [posture, swiftui, overlay, visualization, color-coding, plumb-line, layer-boundaries]
date: 2026-03-15
category: solution
status: implemented
---

# Posture Visualization Enhancement (#116, #117, #119)

## Problem

자세 측정 결과 화면의 시각화가 부족:
1. 관절 연결선이 단일 색상(흰색) — 어떤 관절이 문제인지 즉시 파악 불가
2. Plumb line(이상 정렬선) 없음 — 실제 정렬과 이상 정렬의 편차를 직관적으로 비교 불가
3. 전면/측면 사진 아래에 해당 캡처의 개별 메트릭이 표시되지 않음

## Solution

### 1. 색상 코딩 오버레이 (#117)

`PostureMetricType.affectedJointNames` 매핑을 **Presentation 레이어 extension**(`PostureMetric+View.swift`)에 추가. 각 metric이 영향을 미치는 관절 이름을 `Set<String>`으로 반환.

`JointOverlayView`에서 `buildJointStatusMap()` static 함수로 metric 배열에서 `[jointName: PostureStatus]` 딕셔너리를 한 번 빌드한 후, 관절 점과 연결선에 `PostureStatus.color`를 적용:
- normal → 초록
- caution → 노랑
- warning → 빨강
- 매핑되지 않은 관절 → 흰색 (기본)

### 2. Plumb Line 시각화 (#116)

`plumbLine()` 메서드로 두 가지 선을 사진 위에 오버레이:
- **이상 정렬선** (cyan 점선): 최상단 앵커의 X 좌표에서 수직으로 내려오는 선
- **실제 정렬선** (흰색 실선): 실제 관절 위치를 연결하는 선

캡처 유형별 앵커:
- 정면: `centerHead` → `root`
- 측면: `centerHead` → `rightAnkle`

### 3. 전면/측면 비교 레이아웃 (#119)

`PostureResultView.captureImagesSection`을 재구성:
- 각 캡처 카드 아래에 해당 captureType 메트릭만 표시
- 색상 dot + 메트릭 이름 + 측정값의 간결한 요약
- 빈 캡처 카드에 안내 문구 표시

## Prevention

### Presentation 관심사를 Domain에 넣지 않기

`affectedJointNames`를 처음에 Domain `PostureMetricType`에 추가했다가 리뷰에서 지적받아 Presentation extension으로 이동. **관절 이름 → 색상 매핑**은 순수하게 UI 렌더링 관심사이므로 `PostureMetric+View.swift`에 위치해야 함.

### SwiftUI computed property의 body 내 재계산 주의

`var jointStatusMap` computed property가 `statusColor(for:)`, `segmentColor(from:to:)` 호출 시마다 재계산되는 문제. 해결: `static func buildJointStatusMap()`으로 변환하고 `body` 내에서 `let statusMap = ...`으로 한 번만 계산하여 함수 인자로 전달.

### 연결선 색상 — compactMap+max 패턴

두 관절의 status 중 더 나쁜 것을 선택할 때 4-case switch 대신 `[a, b].compactMap { $0 }.max()`로 간결하게 처리.

## Lessons Learned

1. 관절 overlay처럼 외부 데이터(metric 상태)에 의존하는 시각화는 status lookup을 render 시작 시 한 번만 빌드해야 함
2. `ForEach(Array(collection.enumerated()), id: \.offset)` 패턴은 static 데이터에 적합 — 동적 데이터면 stable identity 필요
3. xcstrings 문자열은 `String` interpolation 대신 조건부 리터럴로 분리해야 번역 가능
