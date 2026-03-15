---
tags: [3d-model, muscle-map, navigation, train-tab, ux]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: 3D Body Map 버튼 — Train 탭 Recovery Map 진입점 개선

## Problem Statement

3D Body Map(`MuscleMap3DView`)은 근육 회복/볼륨 상태를 시각적으로 보여주는 핵심 기능이지만,
현재 진입 경로가 **3-4단계** 깊이에 있어 발견성(discoverability)이 낮다.

**현재 경로**: Train 탭 → Recovery Map 섹션 → "View Details" → MuscleMapDetailView → 근육 탭 → MuscleMap3DView

## Target Users

- 운동 후 근육 회복 상태를 빠르게 확인하려는 사용자
- 3D 시각화를 선호하는 사용자

## Success Criteria

- Train 탭에서 **1탭**으로 3D Body Map 진입 가능
- 기존 Recovery Map 섹션의 레이아웃 일관성 유지
- 버튼이 시각적으로 눈에 띄되 기존 UI를 압도하지 않음

## Proposed Approach

### 위치

Train 탭(`ActivityView.swift`)의 Recovery Map 섹션에 compact 아이콘 버튼 추가.
기존 "View Details" NavigationLink 옆에 배치.

### 버튼 스타일

- SF Symbol 아이콘만 사용하는 compact 버튼
- 후보 아이콘: `figure.stand`, `cube`, `view.3d`, `figure.arms.open`
- GlassCard / 섹션 헤더의 기존 디자인 언어와 조화

### 진입 모드

- Recovery 모드 (기본값)로 3D 뷰 진입
- MuscleMap3DView에서 모드 전환 가능 (기존 기능 유지)

### 네비게이션

- `NavigationLink(value: ActivityDetailDestination.muscleMap3D)` 추가
- 또는 기존 `.muscleMap`과 별도로 직접 3D 뷰로 이동하는 destination 추가

## Constraints

- `NavigationStack`은 `ContentView`에서만 소유 (navigation-ownership 규칙)
- `ActivityDetailDestination` enum에 새 case 추가 필요
- MuscleMap3DView는 RealityKit 의존 — USDZ 로드 시간 고려

## Edge Cases

- USDZ 로드 실패 시 fallback (이미 MuscleMap3DScene에서 처리됨)
- 근육 데이터가 없는 경우 (첫 사용 등) — 빈 상태에서도 3D 뷰 진입 가능해야 함

## Scope

### MVP (Must-have)

- Train 탭 Recovery Map 섹션에 3D 아이콘 버튼 추가
- 버튼 탭 → MuscleMap3DView 직접 네비게이션 (Recovery 모드)
- `ActivityDetailDestination`에 `.muscleMap3D` case 추가

### Nice-to-have (Future)

- Today 탭 Hero Card에서도 3D 진입점 추가
- 3D 미니 프리뷰 (SceneKit 썸네일) 카드
- 마지막 사용 모드 기억 (AppStorage)

## Open Questions

- 아이콘 선택: `cube`, `figure.stand`, `view.3d` 중 어떤 것이 가장 직관적인가?
- 섹션 헤더 trailing에 배치 vs "View Details" 옆 inline 배치?

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
