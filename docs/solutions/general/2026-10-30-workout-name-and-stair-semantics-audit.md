---
tags: [workout-title, localization, healthkit, stair-climber, canonical-id, migration, data-integrity]
category: general
date: 2026-10-30
severity: important
related_files:
  - DUNE/Presentation/Shared/Extensions/WorkoutActivityType+DisplayName.swift
  - DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift
  - DUNE/Presentation/Shared/Models/ExerciseListItem.swift
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift
  - DUNE/Data/Services/ExerciseVariantMigration.swift
  - DUNE/Data/Resources/exercises.json
related_solutions:
  - docs/solutions/healthkit/2026-03-15-localized-title-custom-name-regression.md
  - docs/solutions/general/2026-03-29-exercise-variant-consolidation.md
---

# Solution: 운동명 캐시의 번역 우회와 계단 기구·실제 계단 혼동 수정

## Problem

같은 운동 목록에 Running/달리기와 Stair Climbing/계단 오르기가 혼재했다. 천국의 계단 기구와 실제 건물 계단의 표시도 명확히 구분되지 않았다.

### Root Cause

1. 연결된 로컬 기록의 이름을 `WorkoutTypeCorrectionStore`가 보충한 뒤 목록·상세·Summary가 캐시 원문을 즉시 반환해 일반 종목명 번역을 우회했다.
2. HK `stairClimbing`은 기구, HK `stairs`는 실제 계단이다. 매핑 자체는 올바르지만 기존 내부 이름 `stairStepper`와 문자열 번역이 혼동을 만들었다.
3. 수동 기록의 rawValue를 이름 부분 검색으로 추론해 `stairStepper` 같은 코드가 기구로 오분류될 수 있었다.
4. 이전 운동 변형 통합 마이그레이션은 조회 오류를 0건으로 취급하고 저장 오류를 무시한 채 완료 표시했으며, 템플릿 항목을 다시 만들 때 UUID를 새로 부여했다.

## Solution

- Foundation 기반 표시명 helper를 분리하고 정확한 일반 이름/rawValue만 번역한다. `preferredActivity`로 Strength/Dance의 동일한 옛 영어 이름을 구분한다. 커스텀 운동명의 부분 검색/일반 활동 fallback은 추가하지 않는다.
- 캐시 원문은 저장된 그대로 유지하고 세 표시 경로에 같은 helper를 적용한다. 실제 계단과 기구의 rawValue·typeName·HK44/HK68 연결은 유지하고 en/ko/ja 표시만 명확히 구분한다.
- 수동 기록의 정확한 rawValue를 이름 추론보다 우선하며, 알려진 `other` 코드도 일반 Workout 레이블로 표시한다.
- 운동 정의133개와 기존 ID/별칭/수치/메타데이터는 유지한다. running의 달리기 별칭을 추가하고 기구의 한글 이름을 천국의 계단으로 통일한다.
- 마이그레이션의 모든 조회를 성공시킨 뒤 변환한다. 0건 변경인 재시도에서도 저장 성공을 확인하고 기존 완료 키를 기록한다. 템플릿 항목 UUID를 보존한다. 이미 완료된 플래그를 초기화하거나 스키마를 변경하지 않는다.

82종 이름 대응표,133개 정의와1086개 이름/별칭의 충돌 검사, 이전 커밋, 정확한 테스트 결과와 새 캡처 범위는 [검토·실제 화면 기록](../../design/full-redesign-map/review/workout-name-audit-2026-10-30/README.md)을 따른다.

## Prevention

- 제목 캐시를 적용하는 모든 경로에서 generic title과 custom title을 함께 테스트한다.
- 표시명 정리 시 저장 ID·HK enum·영문 typeName을 이름 변경과 묶어 교체하지 않는다. 기구와 실제 이동의 의미는 공식 활동 분류에서 확인한다.
- 모든 rawValue의 수동 기록 표시를 검사한다. 부분 문자열 추론은 정확한 코드 조회 뒤에만 수행한다.
- 마이그레이션의 조회·저장 실패와 0건 재시도를 검사하고, 템플릿 변환 시 UUID와 운동 수치를 보존한다.

## Lessons Learned

표시 이름의 혼재가 저장 데이터 문제처럼 보일 수 있다. 이력을 다시 쓰기 전에 캐시·정확한 이름 매칭·표시 경로를 추적하고, 과거의 사용자 제목 보존 회귀와 canonical ID 계약을 함께 확인해야 한다.

최초 통과 캡처의 수동 행에서 `strength` 일반 코드가 보조 제목으로 반복되는 경로도 발견했다. `secondaryDisplayName`으로 정확한 일반 종목명/코드는 숨기고 Bench Press 같은 별도 사용자/개별 이름은 보존한다. 기존 단일 rawValue 테스트를82종의 보조 제목 검사와 사용자 이름 보존까지 확장해 정상 종료·통과했다. 이 변경 뒤 해당 수동 행과 기존 목록/상세의 UI만 다시 검사하며 앞선 캡처를 최신 수동 행 증거로 사용하지 않는다.
