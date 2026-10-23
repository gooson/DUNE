---
tags: [cardio, stair-climber, machine-level, swiftdata, watchos]
category: architecture
date: 2026-10-24
severity: minor
related_files:
  - DUNE/Domain/Models/CardioSecondaryUnit.swift
  - DUNE/Data/Persistence/Models/ExerciseRecord.swift
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioSessionViewModel.swift
  - DUNEWatch/Managers/WorkoutManager.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-non-distance-cardio-machine-level-model.md
---

# Solution: 머신 유산소 레벨 변화 기록

## Problem

천국의 계단(`stair-climber`) 운동 중 레벨을 바꿀 수 있었지만 완료 기록에는 시간 가중 평균과 최고 레벨만 남았다. 운동 중 언제 어떤 레벨로 바꿨는지 다시 확인할 수 없었다.

### Root Cause

iPhone `CardioSessionViewModel`과 Watch `WorkoutManager`는 레벨별 경과 시간을 계산에만 사용하고 변경 이벤트를 보관하지 않았다. `ExerciseRecord`에도 이벤트 저장 필드가 없었다.

## Solution

`CardioMachineLevelChange`에 일시정지를 제외한 운동 경과 초와 새 레벨을 기록한다. 같은 레벨 입력은 이벤트로 추가하지 않는다. iPhone·Watch 모두 변경 시 이벤트를 추가하고, Watch는 복구 상태에도 목록을 저장한다.

Watch 복구 상태에는 누적 일시정지 시간과 현재 일시정지 시작 시각도 함께 저장한다. 레벨 이벤트는 별도 JSON Lines 파일에 한 줄씩 추가해 64KB 복구 스냅샷 제한과 반복적인 전체 목록 인코딩을 피한다. 복구된 HealthKit 세션 상태와 맞춘 뒤 다음 변경 이벤트의 활성 경과 시간을 계산한다. 목록 행은 경과 시간과 레벨을 함께 읽도록 접근성 레이블을 제공하고, 큰 글씨에서는 세로로 배치한다.

`ExerciseRecord`에는 optional JSON `Data`로 목록을 보관한다. 기존 V18 `ExerciseRecord`와 `WorkoutSet` 모양을 고정한 뒤 V19 스키마의 optional 필드로 이전한다. 새 기록은 완료 요약과 iPhone 운동 기록 상세에서 시간순으로 표시한다. 기존 기록에는 목록이 없으므로 변화 섹션을 숨긴다.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `CardioSecondaryUnit.swift` | 변경 이벤트와 입력 범위 정의 | 두 플랫폼이 같은 시간·레벨 형식을 사용 |
| `CardioSessionViewModel.swift`, `WorkoutManager.swift` | 초기/중간 레벨 변경 이벤트 수집 | 운동 중 선택을 순서대로 보존 |
| `ExerciseRecord.swift`, `AppSchemaVersions.swift` | optional 이벤트 저장과 V18 스냅샷·V19 스키마 | 기존 저장 기록 이전 |
| iPhone·Watch 완료 요약, iPhone 기록 상세 | 레벨 변화 목록 표시 | 저장 전후 기록 확인 |

## Prevention

운동 중 변경 가능한 수치가 요약 통계에 반영된다면, 원래 선택 순서도 필요한지 저장 계약을 검토한다. 일시정지는 이벤트 시간에서 제외하고 같은 값의 반복 입력은 중복 기록하지 않는다. SwiftData 모델 필드 추가 전 배포된 최신 스키마를 고정하고 이전 테스트를 작성한다.

## Lessons Learned

평균과 최대값만으로는 인터벌 운동의 강도 흐름을 복원할 수 없다. 활성 경과 시간에 붙인 변경 이벤트가 플랫폼 간 저장과 표시의 단순한 공통 형식이다.
