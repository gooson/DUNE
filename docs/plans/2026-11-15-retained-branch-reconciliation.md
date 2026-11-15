---
topic: retained-branch-reconciliation
date: 2026-11-15
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-10-31-auto-merged-worktree-cleanup.md
---

# Implementation Plan: 남은 작업 브랜치 확인과 통합

## Context

상세 화면과 테마의 최종 PR을 머지한 뒤에도 중간 통합 브랜치가 남았다.
사용자는 머지 완료 브랜치를 먼저 삭제하고, 남은 변경을 모두 확인해 필요한
내용을 머지하도록 요청했다. 이 작업은 기존 ac85 폴더를 재사용한다.

## Requirements

- GitHub merged PR, 정확한 head SHA, main 포함 증거가 있는 브랜치부터 삭제한다.
- main에 없는 이력과 미커밋 변경을 삭제하거나 누락으로 단정하지 않는다.
- 중간 작업을 최종 화면별 PR과 대조하고 빠진 기능과 폐기된 실험을 구분한다.
- 다른 채팅이 사용 중인 폴더와 primary의 기존 수정은 보호한다.
- 실제 남은 수정은 검증·리뷰 후 GitHub PR로 통합한다.

## Approach

브랜치별 merge-base 이후 변경 파일과 최종 PR, 현재 main을 대조한다.
기능이 최종본에 포함된 경우 그 근거와 충돌 해결 판단을 기록한다.
옛 테스트 초안이나 비교용 UI를 현재 검증된 코드 위에 덮어쓰지 않는다.
필요한 누락 변경만 적용하고, 통합 이력의 최종 tree도 검증한다.

| 대안 | 판단 |
|---|---|
| 옛 브랜치를 그대로 일괄 머지 | 실패한 중간 테스트·옛 화면을 복원할 위험이 있어 제외 |
| 원격에 있으므로 일괄 삭제 | 미완료 변경의 판단을 생략하므로 제외 |
| 변경 단위 대조 후 명시적 통합 | 선택; 기능 보존과 후속 정리를 함께 검증 |

## Affected Files

| 경로 | 변경 |
|---|---|
| docs/plans/2026-11-15-retained-branch-reconciliation.md | 계획과 검증 계약 |
| docs/reviews/2026-11-15-retained-branches.md | 브랜치별 판단과 PR 근거 |
| scripts/test-unit.sh, scripts/lib/, scripts/tests/ | Watch 미커밋 사전 검증의 필요성 확인 후 선택 적용 |

## Implementation Steps

1. 완료된 로컬·원격 ref를 expected SHA와 merged PR로 확인하고 삭제한다.
2. 남은 상세 화면 중간 브랜치 13개와 T06 비교 기준 브랜치를 독립 대조한다.
3. Watch preflight 미커밋 6개 파일을 현재 runner와 대조하고 필요한 부분을 통합한다.
4. 실제 변경에 필요한 계약·통합 검사와 최종 diff 리뷰를 수행한다.
5. GitHub PR을 생성·통상 머지하고 확인된 이전 ref와 소유 임시 리소스를 정리한다.

## Edge Cases

| 경우 | 처리 |
|---|---|
| 최종 PR이 다른 이름과 커밋으로 작성됨 | 기능·파일·PR 증거로 확인; ancestry만으로 누락 판정하지 않음 |
| 최신 main과 충돌하는 옛 UI·테스트 | 최종 검증본 우선, 근거를 리뷰 문서에 기록 |
| 미커밋 또는 다른 채팅의 폴더 | 원본 보존; 필요한 수정만 현재 브랜치에 복사 |
| 정리 도중 ref 변경 | expected SHA 검증 실패 시 삭제 중단 |

## Testing Strategy

앱 화면·리소스·Swift 코드가 변경되지 않으면 앱 빌드·UI·캡처는 생략한다.
Watch runner 변경은 preflight fixture, runner 순서·실패 차단 fixture,
기존 unit runner·readiness 계약 검사, shell 구문과 dry-run argv로 검증한다.
실제 기기 선택을 확인할 때는 읽기 전용 simctl 조회를 사용한다.
새 앱 변경이 발견되면 해당 동작·플랫폼·selector와 시간 예산을 별도로 확정한다.
각 검사는 동일 원인 최대 1회 조건부 재시도와 소유 프로세스 deadline을 따른다.

## Risks

가장 큰 위험은 옛 중간본이 최신 기능을 되돌리거나, 실험 코드를 누락 기능으로
오인하는 것이다. 브랜치별 독립 대조와 최종 tree 검증으로 방지한다.
