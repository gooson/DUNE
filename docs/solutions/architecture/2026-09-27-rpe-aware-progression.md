---
tags: [rpe, progression, planned-reps, watchos, swiftdata, effort, recovery]
category: architecture
date: 2026-09-27
severity: important
related_files:
  - DUNE/Domain/UseCases/WorkoutProgressionService.swift
  - DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift
  - DUNE/Presentation/Shared/Extensions/ExerciseRecord+Intensity.swift
  - DUNEWatch/Managers/WorkoutManager.swift
related_solutions:
  - architecture/2026-03-12-set-rpe-integration.md
  - architecture/2026-09-19-watch-summary-persistence-parity.md
---

# Solution: 목표·RPE·중량 추천·최종 운동강도 연결

## Problem

### Symptoms

- 실제 반복 횟수(reps)를 목표로 다시 사용해 목표 미달도 달성으로 판정할 수 있었다.
- iPhone/Watch 중량 추천 규칙이 분리돼 있고 사용자 RPE 확인 여부를 반영하지 않았다.
- 세트 평균 RPE와 운동 전체 effort가 자동 강도 계산 이후 반영되어 저장된 값들이 어긋날 수 있었다.
- Watch에서 확정한 RPE가 다음 세트 완료 전 종료 시 복원 스냅샷에서 사라질 수 있었다.

### Root Cause

계획과 실적, 사용자 입력과 추정값, 세트 RPE와 세션 effort가 별도 데이터 계약으로 구분되지 않았다. 기존 Watch 근력 저장 경로에는 자동 강도 계산 연결도 없었다.

## Solution

`reps`는 실제 반복 횟수이고 RPE는 주관적 운동 자각도다. 세트 RPE(앱 척도 6~10), 세션 effort(1~10), 자동 강도(0~1)는 서로 다른 값으로 유지한다.

흐름은 `목표·실적·확정 RPE → 공통 중량 추천`과 `세트 RPE 평균 → 사용자 세션 effort 우선 → 자동 강도 계산 → 저장`으로 연결했다.

### Changes Made

| 영역 | 변경 | 이유 |
|------|------|------|
| 공통 Domain 정책 | 다음 세트 유지/감량, 다음 운동 증량을 분리 | 같은 운동 도중 반복 자동 증량 방지 |
| SwiftData / DTO / draft | plannedReps, plannedSetCount, RPE/effort 출처 보존 | 계획 미달, 부분 완료, legacy 기록 구분 |
| iPhone 입력 | 목표와 실제 횟수 분리, 추천 명시 적용, 오래된 추천 차단 | 사용자 수정 보존 |
| 세션 effort | 직접 선택을 평균보다 우선, 추천값 명시 확정 | 추천을 입력으로 오인하지 않음 |
| 자동 강도 | 최종 effort 이후 재계산, 자기 기록과 미래 기록을 이력에서 제외 | 저장 값 일관성 |
| Watch | 동일 추천 규칙, RPE 확정 즉시 recovery 저장, 최종 강도 계산 | 기기 간 기능·데이터 일치 |
| 마이그레이션 | V17 관계 모델 동결, V18 optional 필드 추가 | 기존 기록 유지와 재오픈 검증 |

같은 세션에서는 목표 미달 또는 사용자 RPE 9 이상일 때 최대 10% 감량 후보를 제공하며 직접 적용해야 한다. 다음 운동의 증량은 계획 전체 완료, 작업 세트 목표 달성, 사용자 확인 RPE 8 이하일 때만 가능하다. failure/drop 세트, 누락된 목표·출처·계획 수는 증량 자격이 없다. 장비 단위 반올림 이후에도 10% 및 500kg 상한을 지킨다. 이는 보수적인 제품 규칙이며 개인화된 임상 처방 기준은 아니다.

### Key Code

```swift
record.applySetBasedRPE()
record.refreshAutoIntensity(exerciseType: exercise.inputType, history: records)
// After explicit session effort selection:
record.applyUserEffort(effort)
record.refreshAutoIntensity(exerciseType: exercise.inputType, history: records)
```

Watch에서도 동일한 `refreshAutoIntensity`를 사용한다. CloudKit보다 WatchConnectivity 전달이 먼저 도착하는 경우 iPhone 수신 경로에서 같은 정책으로 계산한다. 기기별 보유 이력이 다르면 계산 결과는 다를 수 있다. 동기화된 장비 증가폭이 없는 오프라인 Watch 템플릿은 장비 기반 fallback을 사용한다.

## Validation

- iOS 전체 단위 테스트: Swift Testing 2,268개 + XCTest 9개 통과.
- 최종 Watch 단위 테스트: 142개 통과. 확정 직후 recovery 스냅샷, 최종 effort·이력·저장 후 강도 보존 포함.
- 관련 iOS UI: 목표 달성 시 무단 증량 없음, 목표 미달 시 목표 보존·명시 감량, 세션 effort 명시 확정 3개 통과.
- 관련 Watch UI: 첫 세트 RPE 입력·확정, 마지막 세트 확정 후 종료 선택 복귀, 명시 감량 3개 통과.
- V17 store → 현재 schema → 새 metadata 저장 → 재오픈 통과.
- 최종 기본 브랜치 통합 빌드 통과.
- 전체 UI 회귀는 사용자의 명시적 지시에 따라 중단하고 관련 테스트로 검증 범위를 제한했다. 전체 UI 통과를 주장하지 않는다.
- 리뷰 P2 3건(선택 상태, Watch recovery, Watch 자동 강도)을 수정하고 재검토에서 잔여 P1/P2/P3 0건을 확인했다.

실행 로그는 `/tmp/rpe-progression-evidence/`에 보관했다(로컬 임시 증거, 영구 저장소 아님).

## Prevention

- 목표와 실제 수행값은 별도 필드로 저장하고 실제 입력으로 목표를 갱신하지 않는다.
- 추천 계산에는 사용자 확인 여부를 포함한다. 추정 RPE는 증량의 근거로 쓰지 않는다.
- 최종 사용자 effort 변경 시 자동 강도를 다시 계산하고 현재 기록의 ID를 이력에서 제외한다.
- Watch에서 의미 있는 입력을 확정하면 다음 세트까지 기다리지 않고 recovery를 저장한다.
- 상위 SwiftUI 컨테이너의 접근성 ID가 자식 버튼 ID를 덮어쓰지 않도록 `.accessibilityElement(children: .contain)`을 적용하고 실제 UI 계층으로 검증한다.
- Watch 시스템 권한 팝업은 영어·한국어·일본어 버튼을 처리한다.

### Checklist Addition

- [ ] 부분 완료·legacy·추정 RPE 기록이 증량되지 않는가?
- [ ] 추천값을 사용자 선택으로 저장하려면 명시적 동작이 필요한가?
- [ ] UI 표시뿐 아니라 draft, recovery, 전송, 재오픈에서도 metadata가 유지되는가?

기존 규칙으로 충분하므로 `.claude` 및 활성 교정사항은 수정하지 않았다. 관련 열린 TODO는 검색에서 발견되지 않았다.

## Lessons Learned

추천 알고리즘보다 입력의 의미와 저장 순서를 먼저 정해야 한다. 정적 UI 검토만으로는 Watch 접근성 식별자 덮어쓰기나 다국어 권한 팝업을 발견하기 어려워, 실제 관련 UI 흐름을 검증해야 한다.

## 확인 가이드

| 화면 | 확인 방법 |
|------|-----------|
| iPhone 운동 입력 | 목표 8회·60kg에서 실제 6회 완료 → 다음 세트의 목표 8회와 60kg 유지 → 추천 적용 시 55kg |
| 운동 완료 | 추천 effort가 미선택으로 표시됨 → 이 강도 사용 → 선택됨 표시 → 완료 |
| Watch 휴식 | 첫 세트 완료 → RPE 기록 → 확정 → RPE 표시, 다음 세트 감량은 직접 적용 |
| Watch 마지막 세트 | RPE 확정 → 종료 선택으로 복귀 → 운동 마치기 |
| 내부 저장 | 목표·출처·계획 수 보존 및 최종 effort에 따른 자동 강도 재계산 |
