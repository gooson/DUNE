---
tags: [swiftui, toolbar, badge, clipping, notification]
date: 2026-03-15
category: plan
status: draft
---

# Plan: 알림 뱃지 잘림 수정

## Problem

Today 탭 우상단 알림 벨 아이콘의 빨간 뱃지(unread count) 상단이 잘리는 현상.
2026-03-04에 같은 문제가 보고되어 `offset(x:8, y:-8)` → `overlay(alignment: .topTrailing)` + `offset(x: 6)`으로 수정했으나, 뱃지가 22×22 프레임의 정확한 상단 경계에 위치하여 여전히 잘림.

## Root Cause

1. `.overlay(alignment: .topTrailing)`는 뱃지의 top edge를 프레임의 y=0에 정렬
2. 툴바 아이템은 프레임 경계에서 콘텐츠를 클리핑
3. `offset(x: 6)`는 뱃지를 우측 경계 밖으로 6pt 밀어냄 → 우측도 잘릴 가능성

## Solution

`overlay` + `offset` 대신 `ZStack(alignment: .topTrailing)`으로 전환.
벨 아이콘에 `.padding([.top, .trailing], 6)`을 적용하여 뱃지가 자연스럽게 ZStack 내부에 배치되도록 함.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `notificationBellIcon` 구현 변경 |

## Implementation Steps

### Step 1: notificationBellIcon 구조 변경
- `Image + overlay` → `ZStack(alignment: .topTrailing)` 전환
- 벨 아이콘에 `.padding([.top, .trailing], 6)` 추가 (뱃지 공간 확보)
- `offset(x: 6)` 제거 (ZStack이 자연 배치)

## Test Strategy

- 빌드 검증: `scripts/build-ios.sh`
- 기존 DashboardViewModelTests 통과 확인

## Risks / Edge Cases

- 툴바 아이콘 간격이 약간 변할 수 있음 (padding으로 인해)
- unread count 없을 때는 빈 ZStack → 벨 아이콘만 표시 (기존과 동일)
- "99+" 긴 텍스트 → padding이 충분한지 확인 필요
