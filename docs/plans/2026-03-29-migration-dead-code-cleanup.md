---
tags: [swiftdata, migration, cleanup, dead-code]
date: 2026-03-29
category: plan
status: draft
---

# Plan: Migration Dead Code Cleanup

## Problem

마이그레이션 리뷰에서 발견된 P2/P3 항목:

1. **P2-F2**: `AppMigrationPlan`이 `SchemaMigrationPlan`을 채택하고 `schemas`/`stages`를 유지하지만, `DUNEApp.makeModelContainer()`에서 `migrationPlan:` 파라미터를 전달하지 않아 완전한 dead code
2. **P2-F3**: V2~V16의 snapshot model drift로 migration plan 재활성화 불가 — dead code를 유지할 이유 없음
3. **P3-F5**: `DUNEApp.makeFreshModelContainer()`와 `makeModelContainer()`가 동일 구현

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `SchemaMigrationPlan` 제거, `schemas`/`stages` 제거, V1-V16 enum 제거 |
| `DUNE/App/DUNEApp.swift` | `makeFreshModelContainer()` 제거, 호출부를 `makeModelContainer()`로 통합 |

## Implementation Steps

### Step 1: AppSchemaVersions.swift 정리

- `AppSchemaV1` ~ `AppSchemaV16` enum 전체 제거
- `AppMigrationPlan`에서 `SchemaMigrationPlan` 채택 제거
- `schemas`, `stages`, 개별 migration stage (`migrateV1toV2` 등) 제거
- `currentSchema`만 유지 (V17.models 참조)
- `AppSchemaV17`은 유지 (현재 스키마 정의)

### Step 2: DUNEApp.swift 중복 제거

- `makeFreshModelContainer()` 삭제
- `recoverModelContainer()` 내 `makeFreshModelContainer()` 호출을 `makeModelContainer()`로 변경

### Step 3: 빌드 검증

- `scripts/build-ios.sh` 실행

## Risks

- V1-V16 enum 삭제 시 외부 참조 없는지 확인 필요 (Grep으로 검증)
- HealthSnapshotMirrorContainerFactory: visionOS에서 사용 중 → 변경 없음

## Test Strategy

- 빌드 성공 확인
- 기존 유닛 테스트 통과 확인 (migration 관련 테스트 없음)
- UI 변경 없음
