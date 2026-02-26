---
tags: [exercise, watch, quickstart, ux, canonical]
date: 2026-02-26
category: brainstorm
status: aligned
---

# Brainstorm: 운동 종류 정리 및 Quick Start 개선

## Problem Statement
- 운동 라이브러리에서 같은 본운동의 변형(예: 템포, 일시정지, 지구력 세트)이 별도 항목으로 많이 노출되어 선택 부담이 큼.
- Quick Start 진입 시 운동별 최신 수행값(무게, 횟수)이 충분히 재사용되지 않아 입력 마찰이 큼.
- Watch Quick Start에서 운동 종류가 많을 때 주요 운동 접근성이 낮고 탐색 비용이 큼.

## Target Users
- iPhone/Watch에서 루틴 없이 빠르게 단일 운동을 시작하는 사용자.
- 운동명보다 "최근에 한 운동 / 자주 하는 운동" 중심으로 빠르게 진입하고 싶은 사용자.
- 템포/일시정지 등 특수 프로토콜을 "별도 운동"이 아니라 "수행 방식"으로 인식하는 사용자.

## Success Criteria
- Watch Quick Start 첫 화면에서 사용자가 3탭 이내로 주요 운동을 시작할 수 있음.
- 동일 본운동 계열에서 최근 기록(무게/횟수) 재사용률 증가.
- 운동 선택 화면에서 중복/유사 운동 체감 개수 감소.
- 기존 기록 집계(PR, 빈도, 볼륨)의 연속성 유지.

## Proposed Approach
1. 운동명 통합 계층(논리적 Canonical ID) 도입
- 현재 `exercises.json`의 개별 정의 ID는 유지(하위 호환)하고, 별도 매핑 테이블로 `canonicalExerciseID`를 부여.
- 예: `pec-deck`, `pec-deck-tempo`, `pec-deck-paused`, `pec-deck-endurance` -> `canonicalExerciseID = pec-deck`.
- 통합 규칙은 "동일 prefix 이름군은 모두 통합"으로 정의.
- 화면 노출/추천/검색 기본은 canonical 단위로 우선 제공.

2. Quick Start 최신값 기억(Watch + iPhone) 공통화
- 키: `exerciseDefinitionID` 우선, 없으면 `canonicalExerciseID` fallback.
- 값: 최근 완료 세트 기준 `lastWeightKg`, `lastReps`, `updatedAt`.
- Watch는 iPhone에서 계산한 프리셋(defaultWeight/defaultReps)을 `exerciseLibrary` 동기화 payload에 포함해 표시/프리필.

3. Watch Quick Start 정보구조 개선
- 섹션 구조: `Popular`(개인화) + `Recent` + `All`.
- Popular 노출 개수는 상단 `10`개.
- 기본 화면에서는 Popular/Recent 중심 노출, 전체 리스트는 `+` 또는 "All Exercises" 진입점에서 확장.
- Popular는 전역 고정 목록이 아닌 개인 최근 빈도 기반 개인화로 시작.

4. iPhone 정보구조 동기화
- Watch와 동일한 IA를 iPhone에도 적용.
- 기본 화면은 대표 운동(개인화 Popular + Recent) 중심, 전체는 확장 진입점에서 제공.

## Constraints
- 현재 Watch Quick Start는 `WatchConnectivity`로 iPhone에서 내려준 `WatchExerciseInfo`를 사용.
- `WatchExerciseInfo` DTO는 iOS/Watch에 중복 정의되어 있어 필드 추가 시 양쪽 동시 수정 필요.
- iPhone 단일 운동 세션은 이미 이전 세트 프리필 로직이 존재하므로 Quick Start와의 정합성 규칙이 필요.
- 기존 분석 화면(Activity/PR/Volume)은 `exerciseDefinitionID`/`exerciseName` 기반 집계가 많아 단계적 전환이 필요.

## Edge Cases
- canonical 운동은 같지만 변형별 부하가 큰 차이(예: paused vs regular)인 경우 최신값 공유가 오히려 부정확할 수 있음.
- 사용자 커스텀 운동(`custom-*`)은 canonical 매핑 부재 가능.
- Watch 오프라인/동기화 지연 시 최신값이 오래된 상태일 수 있음.
- 단위 전환(kg/lb) 시 저장 단위 일관성(내부 kg) 유지 필요.
- prefix 통합 규칙이 과도하면 서로 다른 운동이 잘못 묶일 수 있으므로 예외 사전 필요.

## Scope
### Phase 1 (이번 배포)
- Watch/iPhone Quick Start IA 개선:
- `Popular(10, 개인화) + Recent` 우선 노출
- 전체 운동은 `+` 확장 진입점에서만 노출
- 기존 기록 집계(PR/볼륨)는 `exerciseDefinitionID` 기반 유지

### Phase 2 (후속 배포)
- prefix 기반 canonical 통합 적용
- 최신값 기억 정책 적용 (`exerciseDefinitionID` 우선 + canonical fallback)
- 조회/추천 영역에 canonical 반영 (PR/볼륨 집계는 기존 유지)

## Decision Log
- 통합 범위: prefix 동일 이름군은 모두 통합
- 최신값 기억 키: `exerciseDefinitionID` 우선, `canonicalExerciseID` fallback
- Watch Popular 개수: 10
- Popular 전략: 초기부터 개인화
- Watch IA: 기본 `Popular + Recent`, 전체는 `+` 진입
- iPhone IA: Watch와 동일 구조 적용
- 과거 기록 집계: `exerciseDefinitionID` 유지, 조회/추천만 canonical 적용
- 일정: 2단계 진행 (이번 배포는 접근성 중심)

## Remaining Questions (Implementation)
- prefix 파싱 규칙의 경계값 정의 (예: 접두 문자열이 우연히 같은 다른 운동군)
- 잘못 통합되는 케이스를 막기 위한 예외 화이트리스트 포맷

## Next Steps
- [x] 결정사항 확정
- [ ] `/plan 운동 종류 통합 + Quick Start 개선` 으로 구현 계획 생성
