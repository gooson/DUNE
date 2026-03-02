---
tags: [workout, intensity, effort-rating, apple-fitness, training-load, auto-suggest, ux-redesign]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: 운동 강도 입력 전면 재설계 (Apple Fitness 참고)

## Problem Statement

현재 DUNE의 운동 강도 시스템은 **RPE(1-10 이모지 버튼)**와 **autoIntensityRaw(0.0-1.0 자동 계산)**가 분리되어 있다.

**현재 문제점:**
1. RPE와 자동 강도가 별개 개념으로 표시 — 사용자에게 혼란
2. RPE 입력 시 기본값이 비어있음 — 매번 처음부터 선택해야 함
3. 이모지 1-10 버튼 UI가 작고 밀집 — Apple Fitness의 슬라이더 대비 불편
4. 자동 강도 배지가 정보 전달만 하고 사용자가 조정 불가
5. 강도 추이 통계가 없음 — 장기적 트레이닝 부하 파악 불가

**Apple Fitness 참고 모델:**
- 운동 완료 시 1-10 Effort Rating 표시 (유산소: 자동 추정, 근력: 수동 입력)
- Digital Crown/슬라이더로 직관적 조정
- Effort × Duration = Training Load로 장기 추이 관리
- 7일 vs 28일 Training Load 비교 차트

## Target Users

- **주 사용자**: 주 3-5회 운동하는 중급자 — 자동 추천값 기반으로 빠르게 확인/조정
- **초보자**: 히스토리 부족 시 수동 입력으로 시작, 데이터 쌓이면 자동 추천 활성화
- **고급자**: 자동 추천값과 체감 강도를 비교하며 오버트레이닝 방지

## Success Criteria

1. 운동 완료 시 **히스토리 기반 Effort 추천값**이 기본 선택되어 표시됨
2. 사용자가 슬라이더로 1-10 범위 내에서 직관적으로 조정 가능
3. Effort 추이 차트에서 주간/월간 강도 트렌드 확인 가능
4. 기존 autoIntensityRaw(0.0-1.0)를 Effort(1-10)로 통합 변환

## Proposed Approach

### 1. 통합 Effort 모델

**현재** (분리):
```
ExerciseRecord.rpe: Int?         // 수동 입력 (1-10)
ExerciseRecord.autoIntensityRaw: Double?  // 자동 계산 (0.0-1.0)
```

**재설계** (통합):
```
ExerciseRecord.effort: Int?           // 최종 Effort (1-10) — 자동 추천 or 사용자 조정
ExerciseRecord.effortSourceRaw: String // auto | manual | adjusted
ExerciseRecord.autoIntensityRaw: Double?  // 유지 (내부 계산용)
```

- `effortSource.auto`: 자동 추천값을 사용자가 변경하지 않고 확인만 함
- `effortSource.manual`: 자동 추천 불가 (히스토리 부족) → 사용자가 직접 입력
- `effortSource.adjusted`: 자동 추천값을 사용자가 조정함

### 2. 자동 Effort 추천 로직

기존 `WorkoutIntensityService.calculateIntensity()` 결과를 1-10 스케일로 변환:

```
autoEffort = round(autoIntensityRaw × 9) + 1  // 0.0-1.0 → 1-10
```

추가 히스토리 기반 보정:
- 같은 운동의 최근 5회 사용자 Effort 평균과 자동 계산값 비교
- 사용자가 지속적으로 자동값보다 높게/낮게 입력하면 보정 계수 적용
- `calibrationFactor = avg(userEffort) / avg(autoEffort)` (최근 5회)

### 3. 완료 화면 UX 재설계

**Apple Fitness 스타일 Effort 입력:**

```
┌─────────────────────────────────────┐
│           ✓ Workout Complete!        │
│         Bench Press · 5 sets         │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │         How did it feel?         │ │
│  │                                  │ │
│  │     ┌─────────────────────┐     │ │
│  │     │    🔥 7 / 10        │     │ │
│  │     │       Hard          │     │ │
│  │     └─────────────────────┘     │ │
│  │                                  │ │
│  │  1 ───────●─────────────── 10   │ │
│  │  Easy    Moderate    All Out     │ │
│  │                                  │ │
│  │  📊 Last time: 6  Avg: 5.8      │ │
│  └─────────────────────────────────┘ │
│                                      │
│  [       Share Workout       ]       │
│  [          Done             ]       │
└─────────────────────────────────────┘
```

**핵심 요소:**
- 큰 숫자 + 레벨명 표시 (중앙)
- 연속 슬라이더 (1-10, 정수 단위 스냅)
- 카테고리 레이블 (Easy 1-3, Moderate 4-6, Hard 7-8, All Out 9-10)
- 히스토리 컨텍스트 (지난번 값, 평균값)
- 자동 추천값이 기본 선택됨 (조정 가능)
- 레벨별 색상 그라데이션 (초록 → 노랑 → 주황 → 빨강)

### 4. Effort 카테고리 (Apple Fitness 스타일)

| Effort | 카테고리 | 한국어 | 색상 |
|--------|----------|--------|------|
| 1-3 | Easy | 쉬움 | DS.Color.positive (green) |
| 4-6 | Moderate | 보통 | DS.Color.caution (yellow) |
| 7-8 | Hard | 힘듦 | .orange |
| 9-10 | All Out | 전력 | DS.Color.negative (red) |

### 5. 강도 통계 뷰

**Training Load 차트 (Apple Fitness 참고):**
- Effort × Duration 기반 Training Load 점수
- 최근 7일 Training Load vs 28일 평균 비교
- 상태 분류: Well Below / Below / Steady / Above / Well Above

**Effort 추이 차트:**
- 운동별 Effort 변화 라인 차트 (30일/90일)
- 전체 운동 Effort 분포 파이/바 차트

## Architecture

### 변경 파일

| 레이어 | 파일 | 변경 |
|--------|------|------|
| Domain | `ExerciseRecord.swift` | `effort: Int?`, `effortSourceRaw: String` 필드 추가 |
| Domain | `WorkoutIntensity.swift` | `EffortCategory` enum 추가, 4단계 분류 |
| Domain | `WorkoutIntensityService.swift` | `suggestEffort()` 메서드 추가 |
| Domain | 신규 `TrainingLoadService.swift` | Training Load 계산 |
| Presentation | `WorkoutCompletionSheet.swift` | 전면 재설계 (슬라이더 UX) |
| Presentation | 신규 `EffortSliderView.swift` | 1-10 슬라이더 컴포넌트 |
| Presentation | `RPEInputView.swift` | 삭제 또는 EffortSliderView로 교체 |
| Presentation | `IntensityBadgeView.swift` | Effort 기반으로 리팩토링 |
| Presentation | 신규 `TrainingLoadView.swift` | Training Load 통계 차트 |
| Presentation | `ExerciseHistoryView.swift` | Effort 추이 차트 추가 |
| Tests | 신규 `TrainingLoadServiceTests.swift` | Training Load 테스트 |
| Tests | `WorkoutIntensityServiceTests.swift` | suggestEffort 테스트 추가 |

### 데이터 흐름

```
운동 완료 → createValidatedRecord()
  ↓
autoIntensityRaw 계산 (기존 로직 유지)
  ↓
suggestEffort() 호출
  ├─ autoIntensityRaw → 1-10 변환
  ├─ 히스토리 calibration 보정
  └─ suggestedEffort: Int 반환
  ↓
WorkoutCompletionSheet 표시
  ├─ 슬라이더 기본값 = suggestedEffort
  ├─ 히스토리 컨텍스트 표시
  └─ 사용자 조정 허용
  ↓
최종 effort 저장 → record.effort
  ↓
Training Load 갱신
```

## Constraints

### 기술적 제약
- SwiftData 스키마 변경: `effort`, `effortSourceRaw` 필드 추가 → VersionedSchema 동기화 필수
- 기존 `rpe` 필드와의 마이그레이션: 기존 rpe 값 → effort로 이관 (또는 병행 유지)
- autoIntensityRaw는 내부 계산용으로 유지 (삭제하지 않음)
- Domain 레이어에서 SwiftUI import 금지

### UX 제약
- 슬라이더 정수 스냅 필요 (연속값이 아닌 1-10 이산값)
- 히스토리 부족 시 (세션 < 2) 추천값 없이 빈 슬라이더 표시
- 완료 시트에서 Effort 입력은 선택사항 (스킵 가능)

## Edge Cases

1. **히스토리 0 (첫 운동)**: 자동 추천 없이 빈 슬라이더 → 사용자 직접 선택 또는 스킵
2. **자동 추천과 체감 큰 괴리**: calibration이 5회 누적되면 보정 시작
3. **매우 짧은 운동 (1세트)**: autoIntensityRaw 계산은 가능, Training Load는 Duration 가중으로 낮게
4. **기존 rpe 데이터 마이그레이션**: rpe가 있는 기록은 effort = rpe로 이관
5. **28일 미만 데이터**: Training Load "데이터 수집 중" 표시
6. **다른 운동 타입 혼재**: Training Load는 운동 타입 무관, 전체 합산

## Scope

### MVP (Must-have)
- [ ] `effort: Int?` + `effortSourceRaw` 필드 추가
- [ ] `EffortCategory` enum (4단계: Easy/Moderate/Hard/All Out)
- [ ] `suggestEffort()` — autoIntensityRaw → 1-10 변환 + 히스토리 calibration
- [ ] `EffortSliderView` — Apple Fitness 스타일 1-10 슬라이더 컴포넌트
- [ ] `WorkoutCompletionSheet` 전면 재설계 (슬라이더 + 히스토리 컨텍스트)
- [ ] `IntensityBadgeView` Effort 기반 리팩토링
- [ ] `TrainingLoadService` — Effort × Duration 기반 Training Load 계산
- [ ] `TrainingLoadView` — 7일 vs 28일 비교 차트
- [ ] 히스토리 뷰에 Effort 추이 표시
- [ ] 유닛 테스트 (suggestEffort, TrainingLoad, 경계값)

### Nice-to-have (Future)
- [ ] Watch에서 Digital Crown 기반 Effort 입력
- [ ] Effort 기반 운동 추천 ("오늘은 Easy day 추천")
- [ ] HealthKit effortScore 동기화
- [ ] Effort reminder 알림 (운동 완료 후 미입력 시)
- [ ] 주간 Training Load 목표 설정
- [ ] 과거 기록 Effort 소급 편집

## Open Questions

1. 기존 `rpe` 필드를 삭제할 것인가, `effort`와 병행 유지할 것인가? → **effort로 통합, rpe는 마이그레이션 후 deprecated 처리** 권장
2. Training Load 차트를 어느 탭에 배치할 것인가? → Activity 탭 또는 Today 탭
3. 슬라이더를 0.5 단위로 허용할 것인가? (Apple은 정수만) → **정수만** 권장

## References

- [Apple Watch Training Load](https://support.apple.com/guide/watch/track-your-training-load-apde4c07a6cf/watchos)
- [Apple Training Load & Vitals Review](https://www.dcrainmaker.com/2024/07/apples-training-load-vitals-watchos11.html)
- [How to Use Apple Watch Training Load](https://www.iphonelife.com/content/apple-watch-training-load)
- [watchOS 11 Health & Fitness Features](https://www.apple.com/newsroom/2024/06/watchos-11-brings-powerful-health-and-fitness-insights/)

## Next Steps

- [ ] `/plan workout-intensity-redesign` 으로 구현 계획 생성
