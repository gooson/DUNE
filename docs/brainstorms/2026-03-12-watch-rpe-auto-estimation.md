---
tags: [watch, rpe, ux, auto-estimation, set-input, strength]
date: 2026-03-12
category: brainstorm
status: draft
---

# Brainstorm: Watch 세트별 RPE 자동 추정 + 휴식 화면 표시

## Problem Statement

Watch SetInputSheet에서 Weight/Reps/RPE가 단일 ScrollView에 세로로 쌓여 있어:
- **RPE 영역이 무게 조절 UI에 가려져 보이지 않음**
- **접힌 상태에서는 RPE가 뭔지 알 수 없음** (펼쳐야 기능 인지)
- ScrollView + Digital Crown + 슬라이더 제스처 충돌

## Target Users

웨이트 트레이닝 사용자 중 세트별 강도를 기록하고 싶지만, 매번 수동 입력은 부담인 사용자.

## Success Criteria

1. 세트 완료 후 RPE 입력 마찰 최소화 (대부분 세트에서 0-tap)
2. 자동 추정값이 합리적 (사용자가 수정 빈도 < 30%)
3. 세트별 RPE가 ExerciseSet에 저장되어 히스토리에서 확인 가능
4. SetInputSheet에서 RPE 섹션 제거 → 스크롤 문제 해결

## 경쟁 앱 조사 결과

| 앱 | RPE 단위 | Watch UX | Skip 방식 |
|---|---|---|---|
| Strong | 세트별 | 인라인 스크롤 (동일 문제) | 비워둠 |
| Hevy | 세트별 | 인라인, 입력 시 자동 완료 | 비워둠 |
| Fitbod | 운동별 (RiR) | Watch 미지원 → iPhone 유도 | Skip 가능 |
| Apple Workout | 워크아웃 전체 | 종료 후 Digital Crown | 설정에서 비활성화 |

**인사이트**: 어떤 앱도 자동 RPE 추정을 하지 않음. 차별화 포인트.

## Proposed Approach

### 1. 자동 RPE 추정 엔진

`WorkoutIntensityService`에 이미 있는 데이터를 활용하여 세트별 RPE를 추정.

**입력 신호 (구현 비용 순):**

| 신호 | 가용 여부 | 추정 기여도 | 로직 |
|------|----------|------------|------|
| 무게 / 1RM 비율 | O (OneRMEstimationService) | 높음 | 60% 1RM → RPE 6, 85% → RPE 8, 95% → RPE 9.5 |
| Reps 감소 패턴 | O (이전 세트 reps 비교) | 높음 | 같은 무게에서 reps 줄면 RPE 상승 |
| 휴식시간 | O (restDuration 저장 중) | 중간 | 긴 휴식 → 이전 세트 고강도 추정 |
| 세트 순서 (피로 누적) | O (setNumber) | 낮음 | 후반 세트일수록 기본 RPE 상승 |
| 심박수 | △ (HKLiveWorkoutBuilder 수집 중이나 세트 단위 분리 어려움) | 높음 (미래) | MVP 이후 고려 |
| 바벨 속도 (가속도계) | X (CMMotionManager 미사용) | 매우 높음 (미래) | 구현 비용 높아 MVP 제외 |

**1RM 기반 RPE 매핑 (Epley/Brzycki 역산):**

```
%1RM → RPE 근사
100%  → 10.0
95%   → 9.5
90%   → 9.0
85%   → 8.5
80%   → 8.0
75%   → 7.5
70%   → 7.0
65%   → 6.5
60%   → 6.0
<60%  → 추정 안 함 (웜업 가능성)
```

**Reps 감소 보정:**
- Set 1: 80kg × 10 → RPE 7.5 (1RM 기반)
- Set 2: 80kg × 8 → RPE 8.0 (같은 무게, -2 reps → +0.5 보정)
- Set 3: 80kg × 6 → RPE 8.5 (같은 무게, -4 reps → +1.0 보정)

### 2. Watch UX: 휴식 화면에 RPE 오버레이

```
┌─────────────────────────┐
│     REST  2:30           │  ← 휴식 타이머
│                          │
│   ┌──────────────────┐   │
│   │  RPE 8.0 · Hard  │   │  ← 자동 추정값 (작게)
│   │  Tap to adjust   │   │
│   └──────────────────┘   │
│                          │
│   Next: Set 3 of 5       │
│   80kg × 10              │
└─────────────────────────┘
```

**탭하면 수정 모드:**
```
┌─────────────────────────┐
│     RPE Adjustment       │
│                          │
│        8.0               │  ← Digital Crown으로 조절
│       Hard               │
│    2 reps left           │
│                          │
│  [Done]                  │
└─────────────────────────┘
```

**핵심 동작:**
- 세트 완료 → 휴식 화면 전환 → 추정 RPE 작게 표시
- 무시하면 추정값 자동 저장
- 탭하면 Digital Crown으로 6.0-10.0 조절
- Done 또는 일정 시간 후 자동 닫힘

### 3. SetInputSheet 변경

**Watch:**
- RPE 섹션 (WatchSetRPEPickerView) 완전 제거
- Weight + Reps만 남음 → 스크롤 불필요

**iOS:**
- 기존 인라인 RPE 유지 (화면 충분)
- 자동 추정값을 기본값으로 prefill (수정 가능)

### 4. 데이터 저장

- `ExerciseSet.rpe: Double?` — 기존 필드 그대로 활용
- 자동 추정이든 수동 수정이든 같은 필드에 저장
- `ExerciseSet.isRPEAutoEstimated: Bool` 추가 고려 (히스토리에서 구분 표시)
- 세션 종료 시 `applySetBasedRPE()` 로직 유지 (세트 RPE → 세션 effort 자동 계산)

### 5. 히스토리 표시

운동 상세 기록에서 세트별 RPE 확인 가능:
```
Set 1  80kg × 10  RPE 7.5
Set 2  80kg × 8   RPE 8.0  (수동 수정)
Set 3  80kg × 6   RPE 8.5
```

## Constraints

- 1RM 히스토리가 없는 첫 운동 → RPE 추정 skip (표시 안 함)
- bodyweight 운동 → 1RM 개념 없음, reps 감소 패턴만 사용 가능 (정확도 낮음)
- 가속도계(bar velocity) 미사용 → 추정 정확도 한계
- Watch 휴식 화면 레이아웃 공간 제약

## Edge Cases

- **웜업 세트**: 60% 1RM 미만이면 RPE 추정 skip
- **무게 0 (bodyweight)**: 1RM 비율 불가 → reps 감소 + 세트 순서만 사용, 정확도 낮으면 skip
- **1RM 데이터 부족**: 해당 운동 히스토리 2세션 미만이면 skip
- **드롭세트**: 무게 감소가 의도적 → 이전 세트 대비 무게 감소 시 별도 로직 (1RM% 기준 유지)
- **세트 타입별**: warmup → skip, working/failure/drop → 추정 대상
- **휴식 화면 없이 바로 다음 세트**: RPE 자동 저장 (마지막 추정값 or nil)

## Scope

### MVP (Must-have)
- Watch SetInputSheet에서 RPE 섹션 제거
- 1RM% 기반 세트별 RPE 자동 추정 엔진
- Watch 휴식 화면에 추정 RPE 표시 (탭 → 수정)
- 추정 불가 시 표시 안 함 (silent skip)
- ExerciseSet에 RPE 저장 (기존 필드)
- iOS 인라인 RPE에 자동 추정값 prefill
- 세션 effort 자동 계산 유지 (applySetBasedRPE)

### Nice-to-have (Future)
- `isRPEAutoEstimated` 플래그로 히스토리에서 자동/수동 구분
- Reps 감소 패턴 보정
- 휴식시간 기반 보정
- 심박수 기반 보정 (세트 단위 HR 분리)
- 바벨 속도 추정 (CoreMotion 가속도계)
- 사용자 보정 학습 (자동 추정 vs 수동 수정 차이를 학습하여 개인화)
- bodyweight 운동 RPE 추정 개선

## Open Questions

1. `isRPEAutoEstimated` 플래그를 MVP에 포함할지 — 스키마 변경 비용 vs 나중에 추가 시 migration 비용
2. 휴식 화면에서 RPE 자동 닫힘 타이밍 — 수정 모드 진입 후 몇 초?
3. iOS prefill 시 기존 사용자의 수동 입력 습관과 충돌 가능성

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] 1RM → RPE 매핑 테이블 검증 (운동과학 문헌 기반)
- [ ] Watch 휴식 화면 현재 구조 확인 (RPE 오버레이 배치 공간)
