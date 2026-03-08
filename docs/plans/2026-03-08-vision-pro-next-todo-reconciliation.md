---
tags: [visionos, todo, backlog, roadmap, reconciliation]
date: 2026-03-08
category: plan
status: approved
---

# Plan: Vision Pro TODO 정합성 복구 + 다음 작업 확정

## Summary

`todos/021`은 실제 저장소에 구현과 solution 문서가 이미 반영돼 있지만 상태가 닫히지 않았고, `todos/022`는 일부 하위 범위가 main에 반영됐음에도 다음 실행 대상으로 여전히 문맥이 부족하다.
이번 배치는 Vision Pro backlog를 현재 shipped 상태와 맞추고, 다음 작업이 `todos/022`라는 점을 명확하게 드러내는 문서 정리에 집중한다.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `docs/plans/2026-03-08-vision-pro-next-todo-reconciliation.md` | 생성 | TODO 정합성 복구 계획 기록 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | 수정 | umbrella TODO에 5A 완료와 5B 진행 상태 반영 |
| `todos/021-done-p1-vision-real-data-pipeline.md` | 수정/rename | 실데이터 파이프라인 TODO를 shipped 상태로 정리 |
| `todos/022-in-progress-p2-vision-ux-polish.md` | 수정/rename | UX polish TODO의 진행 상태와 남은 범위를 명시 |
| `todos/023-ready-p2-vision-phase4-remaining.md` | 수정 | 5B 완료 후 착수하는 후속 TODO임을 명시 |

## Implementation Steps

### Step 1: shipped 증빙 확인

- `docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md`
- `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`
- 관련 git history를 확인해 `021/022`가 이미 main에 반영되었는지 검증한다.

### Step 2: TODO 021 완료 상태 반영 + TODO 022 진행 상태 정리

- `021`은 `ready` 파일명을 `done`으로 rename하고 완료 근거를 적는다.
- `022`는 `ready` 파일명을 `in-progress`로 rename하고, 이미 반영된 범위와 남은 closure 항목을 적는다.

### Step 3: umbrella/next TODO 정리

- `020` 메모에 Phase 5A 완료와 Phase 5B 진행 상태를 남긴다.
- `023`에 5B 완료 이후 착수하는 후속 TODO라는 사실을 남긴다.

## Test Strategy

- `scripts/hooks/validate-todo.sh`로 TODO 파일명 규칙을 검증한다.
- `rg`로 Vision Pro TODO 상태가 `done/in-progress/ready` 흐름으로 정리됐는지 확인한다.
- docs-only 변경이므로 app build/test는 생략하고 사유를 기록한다.

## Risks

| 리스크 | 대응 |
|--------|------|
| shipped 근거 없이 TODO를 닫아 backlog 신뢰도를 해칠 수 있음 | solution 문서 + git history를 먼저 확인한 뒤에만 상태 변경 |
| umbrella TODO와 phase TODO가 중복돼 다음 작업이 다시 모호해질 수 있음 | `020`에 분기 사실을 기록하고 `022`를 현재 실행 대상으로 명시 |
| status만 바꾸고 파일명을 그대로 두어 규칙이 깨질 수 있음 | rename과 frontmatter 변경을 같은 배치에서 수행 |
