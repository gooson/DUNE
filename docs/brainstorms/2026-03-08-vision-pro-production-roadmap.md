---
tags: [visionos, roadmap, production, ux-audit, data-pipeline]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: visionOS Production Readiness Roadmap

## Problem Statement

visionOS 앱은 Phase 1-3 + Phase 4 일부(Multi-Window Dashboard, Exercise Form Guide)가 구현되었으나,
**실제 데이터로 테스트되지 않았고**, Wellness/Life 탭은 placeholder 상태이다.
"실사용 가능한 앱"으로 발전시키기 위한 체계적 로드맵이 필요하다.

## Target Users

- Apple Vision Pro 소유자 중 건강/피트니스에 관심 있는 사용자
- 이미 iOS DUNE 앱을 사용 중인 사용자 (Watch 연동 포함)
- 공간 컴퓨팅으로 건강 데이터를 더 직관적으로 탐색하고 싶은 사용자

## Success Criteria

1. 모든 화면이 실제 HealthKit/CloudKit 데이터로 동작
2. placeholder 탭 없음 (모든 탭이 의미 있는 컨텐츠 제공)
3. visionOS HIG 준수 (UX 전문가 감사 통과)
4. Apple Vision Pro에서 crash 없이 전체 flow 사용 가능
5. Phase 4 잔여 (SharePlay, Voice Input) 포함

## Current State Analysis

### 완료된 기능

| Phase | 기능 | 상태 |
|-------|------|------|
| Phase 1 | 멀티 타겟, Spatial Widgets (3종), Chart3D (2종) | ✅ |
| Phase 2 | Volumetric (Heart Orb, Load Blocks, Body Heatmap) | ✅ |
| Phase 3 | Immersive Space (Atmosphere, Recovery, Sleep Journey) | ✅ |
| Phase 4-E1 | Multi-Window Dashboard (4개 윈도우) | ✅ |
| Phase 4-C5 | Exercise Form Guide foundation | ✅ |

### 미완성 영역

| 영역 | 문제 | 심각도 |
|------|------|--------|
| Train 탭 | 데모 피로도 데이터 (VisionMuscleMapDemoData) | P1 |
| Chart3D | generateSampleData() 고정 데이터 | P1 |
| Wellness 탭 | placeholder 메시지만 | P2 |
| Life 탭 | placeholder 메시지만 | P2 |
| ExerciseRecord | visionOS target에서 제외됨 | P1 |
| Dashboard 윈도우 | 실데이터 미검증 | P1 |

## UX 전문가 감사 결과

### Critical Issues

1. **Dashboard iOS 복사** — 7개 quick action + 6개 metric 밀집 그리드. 공간 컴퓨팅에 부적합
2. **Volumetric 2D/3D 혼재** — Picker/ScrollView가 RealityKit 씬과 공존 (ornament 분리 필요)
3. **Immersive control panel** — 2D 레이어링으로 고개 돌리면 사라짐
4. **BodyHeatmap DragGesture** — absolute 기반으로 시점 점프 (delta 기반으로 통일 필요)
5. **개발 설명 텍스트** — Train tab에 기술 설명이 production UI에 노출

### UX 핵심 제언

> visionOS의 가치 차별화:
> 1. **몰입형 회복 경험** — immersive 호흡 가이드 (✅ 올바른 방향)
> 2. **공간적 데이터 탐색** — 3D 차트에서 HRV/RHR/수면 상관관계 직관 파악 (❌ demo data)
> 3. **신체 인식** — 근육 heatmap 3D 확인 (❌ demo data)

### UX 개선 권장사항

| 카테고리 | 항목 | 우선순위 |
|----------|------|----------|
| 정보 구조 | Wellness/Life placeholder 숨기기 또는 의미 있는 UI 제공 | P1 |
| Dashboard | 핵심 4개 metric만 표시, 나머지는 상세 윈도우로 | P2 |
| Volumetric | 2D 컨트롤을 ornament로 분리 | P2 |
| Typography | 최소 폰트 .callout로 상향 (.caption은 공간에서 읽기 어려움) | P2 |
| Material | glass material depth 규칙 체계화 | P3 |
| Gesture | 공통 spatial gesture 프로토콜 (orbit/zoom/select) 통일 | P2 |
| Empty State | skeleton loading + onboarding CTA | P3 |
| Accessibility | 3D scene에 accessibilityLabel 추가 | P3 |

## Data Pipeline Gap Analysis

### 연결 상태

| 데이터 | iOS → CloudKit | visionOS 읽기 | 상태 |
|--------|----------------|---------------|------|
| Health Snapshot (HRV/RHR/Sleep) | MirroringSharedHealthDataService | CloudMirroredSharedHealthDataService | ✅ |
| Exercise Records | SwiftData + CloudKit | **미포함** (project.yml 제외) | ❌ |
| Muscle Fatigue | SpatialTrainingAnalyzer | VisionMuscleMapDemoData (하드코딩) | ❌ |
| Chart3D | — | generateSampleData() | ❌ |
| Dashboard Activity | WorkoutQuerying (HealthKit) | HealthKit 직접 or Mirror | ⚠️ 미검증 |

### 실데이터 연결 전략

**Option A: Exercise Mirror Record (권장)**
```
iOS ExerciseRecord → ExerciseRecordMirrorRecord (new @Model) → CloudKit → visionOS 읽기
```
- 장점: 세트별 상세 데이터 보존, 독립적 sync 주기
- 단점: 새 @Model 추가 + VersionedSchema 업데이트 필요

**Option B: SharedHealthSnapshot 확장**
```
iOS SharedHealthSnapshot에 exercise metadata 포함 → 기존 mirror로 전달
```
- 장점: 기존 파이프라인 재사용, 구현 비용 낮음
- 단점: snapshot 크기 증가, 세트별 상세 유실

**결정**: Phase 5A에서 Option B로 빠르게 시작 → 후속으로 Option A 확장

## Scope

### Phase 5A: 실데이터 연결 + Critical UX Fix (MVP)

**목표**: 모든 화면이 실제 데이터로 동작 + critical UX 수정

1. SharedHealthSnapshot에 exercise summary 포함 (muscle volume, last trained)
2. VisionTrainView 데모 데이터 → 실데이터 교체
3. Chart3D generateSampleData → HealthKit/Mirror 데이터 연결
4. Dashboard 윈도우 실데이터 검증 + empty state 개선
5. 개발 설명 텍스트 제거
6. BodyHeatmap DragGesture delta 기반 통일
7. Wellness 탭 기본 UI 구현 (Sleep + Body Composition 표시)
8. Life 탭 기본 UI 구현 (Habit 표시)

### Phase 5B: UX Polish + Spatial Native

**목표**: visionOS HIG 준수 + 공간 네이티브 경험

1. Dashboard 리팩토링 (핵심 metric 중심, 카드 크기 증가)
2. Volumetric ornament 분리 (2D/3D 분리)
3. Typography scale 상향
4. Material hierarchy 체계화
5. 공통 spatial gesture modifier 도입
6. Window placement strategy (defaultWindowPlacement)
7. Empty state 디자인 (skeleton + CTA)

### Phase 5C: Advanced Features (Phase 4 잔여)

**목표**: SharePlay, Voice Input 등 고급 기능

1. G1 SharePlay Shared Workout Space
2. F3 Voice-First Workout Entry
3. Spatial Audio ambient soundscape
4. Hand tracking 기반 호흡 감지

### Future (Phase 6+)

- Immersive control panel → RealityKit attachment entity
- Scene understanding 기반 Entity 배치
- Persona 기반 coaching avatar
- 근육 heatmap → 사용자 avatar 매핑

## Constraints

- visionOS 26.0+ 타겟 (Chart3D, Spatial Widgets 의존)
- HealthKit workout 쿼리가 visionOS에서 제한적 → CloudKit mirror 필수
- Apple Vision Pro 실기기 테스트 필요 (시뮬레이터 한계)
- Swift 6 strict concurrency

## Edge Cases

- CloudKit sync 지연 시 visionOS에 stale data 표시 → fetchedAt 타임스탬프 표시
- HealthKit 권한 미승인 시 → empty state + 설정 안내
- iOS 앱 미설치 상태에서 visionOS만 사용 → mirror 없음 → 안내 메시지
- 운동 기록 0건일 때 Train 탭 → meaningful empty state

## Open Questions

1. Exercise mirror를 snapshot 확장(Option B)으로 시작할지, 별도 record(Option A)로 시작할지?
   - **결정**: Option B 우선 (빠른 연결), 필요 시 Option A 확장
2. Wellness/Life 탭을 visionOS에서 어느 수준까지 구현할지?
   - **결정**: 기본 표시(read-only) 수준. 입력은 iOS에서.
3. 시뮬레이터에서 CloudKit mirror 테스트 방법?
   - SwiftData in-memory container + mock data injection

## Next Steps

- [ ] Phase 5A TODO 생성 (021-ready-p1-vision-data-pipeline.md)
- [ ] Phase 5B TODO 생성 (022-ready-p2-vision-ux-polish.md)
- [ ] Phase 5C TODO 생성 (Phase 4 잔여 업데이트)
- [ ] `/plan` 으로 Phase 5A 구현 계획 생성
