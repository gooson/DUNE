---
topic: notification-badge-clipping
date: 2026-03-04
status: implemented
confidence: high
related_solutions: []
related_brainstorms: []
---

# Implementation Plan: Notification Badge Clipping in Dashboard Toolbar

## Context

Today 탭 상단 툴바의 알림 버튼 뱃지(red capsule)가 상단에서 잘리는 시각적 결함이 발생한다.
원인은 `DashboardView.notificationBellIcon`에서 뱃지를 `offset(x: 8, y: -8)`로 크게 위로 이동시켜, 툴바 아이템 렌더링 경계를 벗어나는 것이다.

## Requirements

### Functional

- Today 탭 알림 버튼의 unread 뱃지가 잘리지 않고 완전하게 표시되어야 한다.
- unread count > 99일 때 `99+` 라벨 표시를 유지해야 한다.
- 기존 NotificationHub 이동 동작을 유지해야 한다.

### Non-functional

- 변경 범위를 `DashboardView`와 관련 UI 테스트에 국한한다.
- 기존 접근성 식별자/레이블 정책을 유지한다.

## Approach

뱃지 배치를 음수 Y offset 중심에서, 툴바 아이템 내부 프레임을 확보한 `overlay(alignment: .topTrailing)` 방식으로 전환한다.
벨 아이콘 컨테이너에 고정 프레임을 부여해 뱃지가 부모 경계 내에서 안정적으로 렌더링되도록 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| offset 값만 완화 (예: y -8 → -4) | 변경 최소 | 디바이스/다이내믹 타입별 재발 가능 | ❌ |
| `.clipped(false)` 유사 우회 | 구현 난이도 낮음 | SwiftUI toolbar 경계 clipping 자체를 근본 해결 못함 | ❌ |
| overlay + 고정 프레임 | 레이아웃 의도 명확, 재발 위험 낮음 | 코드 소폭 구조 변경 | ✅ |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | 알림 뱃지 배치 방식 변경 (offset 의존 제거) |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 알림 버튼 접근성 ID 상수 추가 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | modify | 알림 버튼 존재 스모크 테스트 추가 |

## Implementation Steps

### Step 1: Dashboard toolbar badge layout fix

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`
- **Changes**:
  - `notificationBellIcon`를 overlay 기반으로 재구성
  - 툴바 아이템 내부에서 뱃지 렌더링 여유를 주는 고정 프레임 적용
- **Verification**:
  - unread count가 1 이상일 때 뱃지가 완전한 캡슐 형태로 표시되는지 확인

### Step 2: UI smoke coverage update

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNEUITests/Smoke/DashboardSmokeTests.swift`
- **Changes**:
  - 알림 버튼 AXID 상수 추가
  - Dashboard smoke에 알림 버튼 존재 테스트 추가
- **Verification**:
  - 테스트가 알림 버튼을 식별자로 탐지 가능해야 함

## Edge Cases

| Case | Handling |
|------|----------|
| unread count = 0 | 뱃지 미표시 유지 |
| unread count = 1자리/2자리/3자리(99+) | 캡슐 배경 내 텍스트 가독성 유지 |
| iPhone/iPad 툴바 렌더링 차이 | 고정 프레임 + overlay로 경계 내 렌더링 |

## Testing Strategy

- Unit tests: 해당 없음 (순수 View 레이아웃 변경)
- Integration tests: 기존 Dashboard 스모크 + 알림 버튼 존재 테스트 추가
- Manual verification: Today 탭 진입 후 unread 뱃지 시각 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 툴바 hit area/탭 영역 변경 | Low | Medium | 기존 NavigationLink 구조 유지, icon frame 최소 확대 |
| 뱃지 위치 미세 어긋남 | Medium | Low | iPhone 기준 시각 확인 후 offset 최소 조정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 문제 원인이 단일 View 함수(`notificationBellIcon`)로 명확하고, overlay 전환은 SwiftUI toolbar clipping 대응에 안정적인 패턴이다.
