---
tags: [swiftdata, migration, dead-code, schema, cleanup]
date: 2026-03-29
category: architecture
status: implemented
severity: minor
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/App/DUNEApp.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNETests/AppMigrationPlanTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
  - docs/solutions/architecture/2026-03-14-swiftdata-134504-recovery.md
---

# Solution: Migration Dead Code Cleanup

## Problem

`AppMigrationPlan`이 `SchemaMigrationPlan`을 채택하고 V1~V16 VersionedSchema enum 17개와 16개의 MigrationStage를 유지했지만, `DUNEApp.makeModelContainer()`에서 `migrationPlan:` 파라미터를 전달하지 않아 전부 dead code였다.

추가로 15개 스키마가 live type hash drift를 가지고 있어 plan을 재활성화할 수도 없는 상태였다.

## Solution

1. **V1~V16 enum 전체 삭제** — snapshot @Model types 포함 (~600줄)
2. **`SchemaMigrationPlan` 채택 제거** — `schemas`, `stages`, 16개 migration stage 삭제
3. **`AppMigrationPlan` → `AppSchema`로 rename** — migration plan이 아닌 schema 정의 역할에 맞는 이름
4. **`makeFreshModelContainer()` 제거** — `makeModelContainer()`와 동일 구현이었으므로 통합
5. **테스트 업데이트** — 삭제된 V11~V16 참조를 현재 스키마 기반 테스트로 교체

## Prevention

- 새 스키마 버전 추가 시 `AppSchema.currentSchema`만 갱신하면 됨
- `AppSchemaV17.models` 배열에 새 @Model 추가
- 별도의 VersionedSchema나 MigrationStage 선언 불필요
- 향후 non-lightweight migration이 필요하면 그때 plan을 새로 구성

## Lessons Learned

- SwiftData의 자동 lightweight migration은 additive 변경(새 모델, 새 optional/default 필드)에 충분
- `SchemaMigrationPlan`은 field rename/delete/type change 같은 non-lightweight 변경에만 필요
- live type을 VersionedSchema.models에 참조하면 필드 추가 시마다 hash가 drift하여 plan이 깨짐
