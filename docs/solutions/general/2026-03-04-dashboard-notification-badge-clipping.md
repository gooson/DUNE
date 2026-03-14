---
tags: [swiftui, toolbar, notification, badge, clipping, dashboard, zstack]
category: general
date: 2026-03-15
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
related_solutions: []
---

# Solution: Today 툴바 알림 뱃지 잘림 (v2)

## Problem

### Symptoms

- Today 탭 우상단 알림 벨 아이콘의 unread 뱃지(빨간 캡슐) 상단이 잘려 보임
- unread count가 있을 때만 재현

### Root Cause (v1 fix 실패)

v1에서 `offset(x:8, y:-8)` → `overlay(alignment: .topTrailing)` + `offset(x: 6)`으로 변경했으나,
`overlay`는 부모 프레임 경계 밖으로 나간 콘텐츠를 렌더링하되, **툴바 아이템 컨테이너가 해당 경계에서 클리핑**하여
뱃지 상단이 여전히 잘렸다.

핵심 원인: `overlay` 콘텐츠는 부모 레이아웃 경계를 확장하지 않음 → 툴바가 22×22 프레임 기준으로 클리핑.

## Solution (v2)

`overlay` + `offset` 대신 `ZStack(alignment: .topTrailing)`으로 전환.
ZStack은 모든 자식 뷰의 유니온으로 레이아웃 경계를 확장하므로 뱃지가 경계 내부에 자연스럽게 위치.

### Key Code

```swift
private var notificationBellIcon: some View {
    ZStack(alignment: .topTrailing) {
        Image(systemName: "bell")
            .frame(width: 22, height: 22)
            .padding([.top, .trailing], 4)

        if unreadNotificationCount > 0 {
            Text(unreadBadgeLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.red, in: Capsule())
                .accessibilityLabel("...")
        }
    }
}
```

### Why ZStack works

| 구조 | 레이아웃 경계 | 클리핑 |
|------|-------------|--------|
| `overlay` + `offset` | 부모(22×22)만 — offset은 레이아웃에 영향 없음 | 툴바가 22×22 기준으로 클리핑 |
| `ZStack` | 모든 자식의 유니온 (벨+패딩+뱃지) | 뱃지가 경계 내부 → 클리핑 없음 |

### 주의사항

- `.frame(width: 22, height: 22)`를 벨 아이콘에 유지해야 툴바 간격이 일관적
- `.padding([.top, .trailing], 4)`는 뱃지가 위치할 공간 확보 + 벨과 뱃지의 시각적 분리
- 뱃지 없을 때도 padding으로 인해 26×26 크기 (4pt 증가) — 허용 범위

## Prevention

- 툴바 아이템에서 `overlay` + `offset`으로 경계 밖 콘텐츠를 배치하지 않는다
- 뱃지/라벨 오버레이가 필요하면 `ZStack`으로 레이아웃 경계를 자연 확장한다
- 벨 아이콘의 `.frame()` 제거 금지 — 툴바 간격 일관성 유지
