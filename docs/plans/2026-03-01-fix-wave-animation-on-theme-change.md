---
tags: [wave, animation, theme, swiftui, bug-fix]
date: 2026-03-01
category: plan
status: implemented
---

# Fix: Wave Animation Freezes on Theme Change

## Problem

테마 변경 시 웨이브 배경 애니메이션이 멈추는 버그.

## Root Cause

`TabWaveBackground`의 `switch theme`이 뷰 트리를 재구성할 때, 새 뷰의 `.onAppear` 내 `withAnimation(.repeatForever)` 호출이 부모 환경 변경 트랜잭션과 충돌하여 애니메이션이 시작되지 않거나 즉시 종료됨.

**발생 체인:**
1. `\.appTheme` environment 변경
2. `TabWaveBackground` switch branch 전환
3. 기존 Desert/Ocean 뷰 제거, 새 뷰 삽입
4. 새 `WaveOverlayView`/`OceanWaveOverlayView`의 `.onAppear` 실행
5. `withAnimation(.repeatForever)` 가 부모 트랜잭션에 병합 → 애니메이션 소실

## Solution

`.onAppear` 내 `withAnimation` 호출을 `DispatchQueue.main.async`로 래핑하여 부모 트랜잭션과 격리.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | `WaveOverlayView.onAppear` async 래핑 |
| `DUNE/Presentation/Shared/Components/OceanWaveShape.swift` | `OceanWaveOverlayView.onAppear` async 래핑 |

## Verification

- 빌드 성공
- Desert → Ocean 테마 전환 시 웨이브 애니메이션 지속
- Ocean → Desert 테마 전환 시 웨이브 애니메이션 지속
