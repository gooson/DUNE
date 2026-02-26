---
tags: [activity-tab, recovery-map, muscle-map, volume, ux]
date: 2026-02-27
category: brainstorm
status: draft
---

# Brainstorm: Activity 탭 Recovery Map + Muscle Map 통합

## Problem Statement

현재 Activity 탭에 근육 시각화가 2곳에 분리되어 있음:
1. **Recovery Map** (`MuscleRecoveryMapView`) — SVG body diagram으로 13개 근육군 피로도/회복 표시
2. **Muscle Map** (`MuscleMapView`) — progress bar 형태로 주간 볼륨 상위 6개 근육 표시

사용자가 "이 근육을 얼마나 훈련했는지"와 "회복이 얼마나 됐는지"를 한 곳에서 파악할 수 없음.

## Target Users

- 주 3-5회 웨이트 트레이닝 사용자
- 근육별 훈련 밸런스와 회복 상태를 시각적으로 확인하고 싶은 사용자

## Success Criteria

1. 하나의 body diagram에서 회복 상태와 훈련 볼륨을 모두 확인 가능
2. 기존 `MuscleMapView` (progress bar)를 제거하고 통합 뷰로 대체
3. 모드 전환이 직관적이고 매끄러움 (스와이프 기반)
4. 기존 Recovery Map의 탭→상세 팝오버 기능 유지

## Proposed Approach

### 통합 UI 구조

```
┌─────────────────────────────────────────┐
│  Muscle Map                    ⓘ        │  ← 헤더 (제목 + info 버튼)
│  ○ ○                                    │  ← 페이지 인디케이터 (2 dots)
├─────────────────────────────────────────┤
│                                         │
│    [Front Body]     [Back Body]         │  ← SVG body diagram
│     (colored)        (colored)          │     스와이프로 모드 전환
│                                         │
├─────────────────────────────────────────┤
│  ● Recovered  ● Light  ● Moderate ...   │  ← 현재 모드에 맞는 Legend
│  OR                                     │
│  ● 0 sets  ● 1-5  ● 6-10  ● 11+ ...   │
├─────────────────────────────────────────┤
│  3/13 groups ready  |  Summary text     │  ← 요약 텍스트
└─────────────────────────────────────────┘
```

### 모드 전환 방식: 스와이프 (TabView)

- `TabView` + `.tabViewStyle(.page)` 사용
- Page 1: **Recovery Mode** — 현재 Recovery Map과 동일한 피로도 기반 채색
- Page 2: **Volume Mode** — 주간 세트 수 기준 절대 볼륨 강도 채색
- 페이지 인디케이터(dots)로 현재 모드 표시
- 스와이프 시 `.transition(.opacity)` + body diagram 색상만 crossfade

### Volume Mode 채색 기준 (절대 볼륨 강도)

주간 세트 수 기준으로 근육 채색:

| 세트 수 | 강도 | 색상 |
|---------|------|------|
| 0 | 미훈련 | 회색 (DS.Color.surfaceTertiary) |
| 1-5 | 경량 | 연한 warm 색 |
| 6-10 | 적정 | 중간 warm 색 |
| 11-15 | 고강도 | 진한 warm 색 |
| 16+ | 과다 | 가장 진한 warm 색 |

### 기존 MuscleMapView 제거

통합 완료 후 `MuscleMapView` (progress bar 형태)를 삭제하고 Activity 탭에서의 참조를 통합 뷰로 교체.

## Constraints

### 기술적 제약
- 같은 `MuscleBodyShape` SVG 엔진 재사용 (성능 검증 완료)
- `MuscleMapData`의 front/back SVG 파트 공유
- `TabView(.page)` 내에서 SVG body diagram이 2회 렌더 — 성능 확인 필요
- Correction #82: `path(in:)` 내 무거운 연산 금지 (이미 pre-parsed paths 사용 중)

### UX 제약
- iPad에서 front/back이 나란히 표시되므로 스와이프 영역이 넓음
- 스와이프 방향이 수평 스크롤과 충돌하지 않도록 주의
- Recovery 모드의 탭→상세 팝오버와 스와이프 제스처 충돌 가능

### 아키텍처 제약
- `ActivityViewModel`이 이미 `fatigueStates`를 계산 중 — 볼륨 데이터도 이미 포함됨 (`weeklyVolume`)
- 새로운 데이터 fetch 불필요 (기존 `MuscleFatigueState.weeklyVolume` 활용)

## Edge Cases

1. **데이터 없음 (첫 사용자)**: 모든 근육 회색 + "운동을 기록하면 여기에 표시됩니다" placeholder
2. **한쪽 모드만 데이터 있음**: Recovery=전부 회복, Volume=0 — 각 모드별 독립 empty state
3. **극단적 볼륨**: 한 근육만 30+ 세트 — 색상 스케일의 상한 클램핑 필요
4. **iPad multitasking**: `sizeClass` 변경 시 TabView page index 유지 확인

## Scope

### MVP (Must-have)
- [x] 하나의 통합 컴포넌트 (`IntegratedMuscleMapView` 또는 유사)
- [x] 스와이프로 Recovery ↔ Volume 모드 전환
- [x] 페이지 인디케이터
- [x] Volume 모드: 절대 볼륨 강도 기반 채색
- [x] 모드별 Legend 전환
- [x] 모드별 요약 텍스트 전환
- [x] 기존 Recovery Map 탭→상세 팝오버 유지
- [x] 기존 `MuscleMapView` (progress bar) 제거

### Nice-to-have (Future)
- 스와이프 시 색상 crossfade 애니메이션
- Volume 모드에서도 탭→상세 (해당 근육의 볼륨 breakdown)
- 3번째 모드: "밸런스" (좌우, 상하체, push/pull 비율)
- 주간 → 월간 기간 전환

## Open Questions

1. Volume 모드에서 근육 탭 시 어떤 정보를 보여줄 것인가? (Recovery 모드처럼 상세 팝오버?)
2. 페이지 인디케이터 외에 모드 이름 라벨("Recovery" / "Volume")도 표시할 것인가?
3. 통합 뷰의 높이가 현재 Recovery Map보다 커지는가? (Legend + 요약 텍스트 추가분)

## Next Steps

- [ ] `/plan recovery-muscle-map-integration` 으로 구현 계획 생성
- [ ] 기존 `MuscleRecoveryMapView` 코드를 베이스로 통합 뷰 설계
- [ ] Volume 색상 팔레트를 DS 토큰으로 정의
