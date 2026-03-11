---
topic: watch SwiftData migration duplicate checksums
date: 2026-03-12
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-12-swiftdata-duplicate-version-checksums.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
related_brainstorms: []
---

# Implementation Plan: Watch SwiftData Migration Duplicate Checksums

## Context

watch simulator에서 `ModelContainer` 초기화 시 `Duplicate version checksums across stages detected.` 예외로 앱이 부팅 직후 종료된다.
이 오류는 store 복구 이전 단계에서 발생하므로, 현재 `AppMigrationPlan` 안의 버전 스키마 중 최소 한 쌍이 동일 checksum을 만들고 있다는 뜻이다.

## Requirements

### Functional

- watch app이 `AppMigrationPlan`으로 `ModelContainer`를 정상 생성해야 한다.
- 모든 declared schema version은 staged migration에서 고유 checksum을 가져야 한다.
- 기존 배포 스키마 checksum을 깨지 않으면서 최신 live model로 진화해야 한다.

### Non-functional

- 기존 SwiftData + CloudKit 규칙을 유지한다.
- 수정 범위는 migration schema와 회귀 테스트에 한정한다.
- 회귀를 자동 검출할 수 있는 테스트를 남긴다.

## Approach

`AppSchemaV9` 이후의 snapshot/live model 경계를 다시 점검하고, 실제 feature delta가 없는 버전은 snapshot을 복구하거나 live model 참조를 제거해 각 stage가 서로 다른 schema 구조를 가지게 만든다.
동시에 `AppMigrationPlanTests`를 강화해 in-memory `ModelContainer` 생성뿐 아니라 문제 구간의 snapshot 계약을 명시적으로 검증한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| watch app에서 migration plan 없이 in-memory fallback 강제 | 빠른 우회 | 실제 데이터 store와 배포 스키마를 숨김, 근본 원인 미해결 | 기각 |
| 중복 가능성이 있는 버전을 통째로 제거 | 구조 단순화 | 기존 배포 사용자 store와 version chain 호환 위험 | 기각 |
| snapshot/live 경계를 복구하고 테스트를 추가 | 배포 checksum 보존, 근본 원인 해결, 회귀 방지 | 어떤 버전 쌍이 문제인지 정확히 찾아야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | modify | duplicate checksum을 만드는 schema 경계를 복구 |
| `DUNETests/AppMigrationPlanTests.swift` | modify | migration checksum 회귀 검출 테스트 보강 |
| `docs/solutions/architecture/2026-03-12-watch-swiftdata-migration-duplicate-checksums.md` | add or update | 해결 후 원인과 예방책 문서화 |

## Implementation Steps

### Step 1: 중복 checksum 구간 특정

- **Files**: `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift`, `DUNETests/AppMigrationPlanTests.swift`
- **Changes**: V9~V14 중심으로 snapshot/live model 참조를 비교하고, 필요하면 V7~V11까지 확장 조사한다.
- **Verification**: `xcodebuild test ... -only-testing:DUNETests/AppMigrationPlanTests`

### Step 2: schema 경계 복구

- **Files**: `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift`
- **Changes**: 문제 버전에서 live `@Model` 참조를 snapshot으로 되돌리거나 feature delta에 맞게 버전 역할을 재정렬한다.
- **Verification**: in-memory `ModelContainer` 생성 테스트 통과, watch app launch crash 미재현

### Step 3: 회귀 테스트 강화

- **Files**: `DUNETests/AppMigrationPlanTests.swift`
- **Changes**: duplicate checksum을 유발했던 snapshot 계약을 직접 검증하는 테스트 추가
- **Verification**: targeted unit tests 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 과거 버전이 live model을 계속 참조해 checksum drift가 누적된 경우 | 문제 구간만이 아니라 이전 version도 snapshot 고정 필요 여부 확인 |
| watch simulator와 iOS 테스트 환경이 다르게 보이는 경우 | shared migration/models inclusion이 동일한지 `project.yml`로 검증 |
| detached HEAD라 ship을 진행할 수 없는 경우 | 코드 수정과 검증까지만 완료하고 ship blocker로 보고 |

## Testing Strategy

- Unit tests: `AppMigrationPlanTests` targeted run으로 migration plan 유효성 검증
- Integration tests: `scripts/build-ios.sh` 실행으로 iOS/watch 공유 빌드 확인
- Manual verification: watch simulator launch에서 `ModelContainer` 초기화 crash 미재현 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 잘못된 snapshot 복구로 기존 store migration이 깨짐 | medium | high | 기존 solution 문서와 version 역할을 대조하고 lightweight path 유지 |
| 테스트가 iOS 경로만 커버하고 watch launch regression을 놓침 | medium | medium | build 후 watch 실행 경로 또는 watch smoke를 추가 검토 |
| detached HEAD 때문에 자동 ship 불가 | high | low | Phase 6에서 blocker로 명시 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: duplicate checksum 패턴과 유사한 과거 해결책은 충분하지만, 실제 충돌 버전 쌍은 테스트/코드 확인으로 확정해야 한다.
