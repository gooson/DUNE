---
tags: [ui, exercise, muscle-map, recovery-map]
date: 2026-02-26
category: brainstorm
status: draft
---

# Brainstorm: Muscle Map Recovery-Style Redesign

## Problem Statement
기존 `Muscle Map` 화면이 단순 라운드 사각형 오버레이 기반이라 시각 품질이 낮고, `Recovery Map`과 스타일 일관성이 깨진다.

## Target Users
- 운동 기록 사용자
- `Exercise` 탭에서 주간 부위별 볼륨을 직관적으로 확인하려는 사용자

## Success Criteria
- `Muscle Map`이 `Recovery Map`과 동일한 SVG 기반 인체 실루엣 스타일로 표시된다.
- 전/후면을 한 화면에서 함께 보여줘 탐색 전환 비용이 줄어든다.
- 탭 시 근육 상세(주간 sets)가 기존처럼 유지된다.

## Proposed Approach
- `MuscleMapView` 렌더링을 `MuscleMapData.frontMuscles/backMuscles`(legacy Rect)에서
  `MuscleMapData.svgFrontParts/svgBackParts` 기반으로 교체.
- `Recovery Map`과 동일한 front/back outline + part shape 렌더 패턴을 사용.
- 색상은 주간 볼륨 비율(`muscleVolume / maxVolume`)로 단계형 강조.

## Constraints
- 데이터 모델(`weeklyMuscleVolume`)은 그대로 유지해야 한다.
- 화면 의미(볼륨 맵)와 `Recovery Map` 의미(회복도 맵)는 구분되어야 한다.
- 기존 선택 인터랙션(근육 탭 -> 상세 카드)은 유지해야 한다.

## Edge Cases
- 기록이 없는 경우: 전체 부위를 low-emphasis 색으로 렌더하고 안내 문구 노출.
- 특정 부위만 과도하게 큰 볼륨: 상대 비율 기반 색상으로 나머지 부위가 너무 희미해지지 않도록 하한 색 유지.
- front/back 모두에 존재하는 근육(예: shoulders, forearms): 어느 면을 탭해도 동일 근육 선택 상태로 연결.

## Scope
### MVP (Must-have)
- `MuscleMapView`를 `Recovery Map` 스타일 SVG 렌더링으로 교체
- 전/후면 동시 노출
- 기존 범례/상세 카드 유지

### Nice-to-have (Future)
- 볼륨 맵 전용 범례 문구 개선(sets threshold 기반)
- 선택 근육 자동 스크롤/하이라이트 강화
- iPad 레이아웃 전용 사이즈 튜닝

## Open Questions
- 범례를 `None/Low/Medium/High` 대신 한국어 또는 set 구간 기준으로 바꿀지?
- `ExerciseDetailSheet`의 소형 근육맵(`ExerciseMuscleMapView`)도 동일 SVG 스타일로 통일할지?

## Next Steps
- [ ] 사용자 확인 후 범례 언어/수치 구간 최종 확정
- [ ] 필요 시 `ExerciseMuscleMapView`까지 동일 스타일로 확장
- [ ] `/plan muscle-map-recovery-style-redesign` 로 후속 개선 계획 수립
