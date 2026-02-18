---
tags: [review-fix, task-cancellation, deprecated-api, distance-cap, computed-property-caching, training-volume]
category: general
date: 2026-02-19
severity: important
related_files:
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - Dailve/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift
  - Dailve/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift
  - Dailve/Domain/UseCases/TrainingVolumeAnalysisService.swift
  - Dailve/Data/HealthKit/WorkoutActivityType+HealthKit.swift
related_solutions:
  - performance/2026-02-19-numberformatter-static-caching.md
  - architecture/2026-02-19-dry-extraction-shared-components.md
  - performance/2026-02-16-review-triage-task-cancellation-and-caching.md
---

# Solution: Training Volume 6관점 리뷰 P1-P2 일괄 수정

## Problem

### Symptoms

6관점 리뷰에서 P1 4건, P2 5건 발견:
- P1-1: NumberFormatter 매 호출 생성 (차트 hot path)
- P1-2: ActivityViewModel computed property 매 렌더 재계산
- P1-3: 거리 값 500km 상한 미적용 (Correction #79)
- P1-4: Task.isCancelled 검사 없이 isLoading 리셋 (Correction #17)
- P2-1~3: 동일 로직 3~4곳 중복 (ChangeBadge, formatDuration, totalVolume)
- P2-4: Dead code (미사용 computed properties)
- P2-5: `.clipped()` 누락 (Correction #70)
- 추가: deprecated `HKWorkoutActivityType.dance` 경고

### Root Cause

기능 구현(+3,004줄) 중 성능/정리 단계 없이 기능 완성에 집중.
Correction Log에 이미 있는 패턴(#17, #70, #79)도 새 코드에서 재발.

## Solution

### Changes Made

| Category | File | Change |
|----------|------|--------|
| Performance | `Double+Formatting.swift` | FormatterCache static caching |
| Performance | `ActivityViewModel.swift` | Computed → `didSet` 캐싱 |
| Validation | `TrainingVolumeAnalysisService.swift` | `d < 500_000` 거리 상한 |
| Concurrency | `TrainingVolumeViewModel.swift` | `guard !Task.isCancelled` 추가 |
| Concurrency | `ExerciseTypeDetailViewModel.swift` | `guard !Task.isCancelled` 추가 |
| DRY | `ChangeBadge.swift` (NEW) | 3곳 중복 추출 |
| DRY | `TimeInterval+Formatting.swift` (NEW) | 4곳 중복 추출 |
| DRY | `ExerciseRecord+Volume.swift` (NEW) | 2곳 중복 추출 |
| Cleanup | `TrainingVolumeViewModel.swift` | Dead code 삭제 |
| Charts | `VolumeDonutChartView.swift` | `.clipped()` 추가 |
| Deprecated | `WorkoutActivityType+HealthKit.swift` | `.dance` → `.socialDance`/`.cardioDance` |

### Results

- **14 files changed**: +129, -168 (순 감소 39줄)
- **Build**: 성공
- **Tests**: 전체 통과
- **Deprecated warning**: 0

## Prevention

### Batch Fix Workflow

대규모 리뷰 수정 시 파일별 batch 적용 (Correction #27):
1. 모든 리뷰 결과를 파일별로 병합
2. 파일당 한 번에 모든 수정 적용
3. 새 파일 추가 시 xcodegen generate
4. 최종 1회 빌드 + 테스트

### Correction Log 재발 방지

Correction Log에 이미 있는 패턴이 새 코드에서 재발하는 문제:
- **원인**: 기능 구현 시 Correction Log를 참조하지 않음
- **대책**: `/work` 실행 시 관련 Correction 항목을 Implementation Checklist에 자동 포함
- 특히 자주 재발하는 항목: #17 (Task.isCancelled), #70 (.clipped()), #79 (거리 상한)

## Lessons Learned

- 기능 구현 후 `/review` 가 Correction Log 항목의 재발을 잡아줌 — Compound Loop의 핵심 가치
- 중복 코드는 빠른 개발의 자연스러운 부산물 — 리뷰 단계에서 추출하는 것이 가장 효율적
- deprecated API는 Xcode warning 0 정책으로 즉시 수정 (Correction #19)
- `async let` 병렬 fetch + `Task.isCancelled` guard 는 세트로 적용해야 함
