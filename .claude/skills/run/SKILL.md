---
name: run
description: "전체 파이프라인 자동 실행. Plan -> Work -> Review -> Resolve -> Compound -> Ship. 승인 없이 끝까지 자동 진행합니다."
---

# Run: Full Pipeline Execution (Auto)

$ARGUMENTS 에 대해 전체 Compound Engineering 파이프라인을 **승인 없이** 자동 실행합니다.

## Pipeline Overview

```
Phase 1: Plan ──> Phase 2: Work ──> Phase 3: Review ──> Phase 4: Resolve ──> Phase 5: Compound ──> Phase 6: Ship
     │                 │                  │                   │                    │                    │
  [자동 진행]      [빌드 통과]       [결과 생성]         [전체 자동 수정]       [문서화]            [PR 생성]
```

모든 Phase는 승인 없이 자동 진행됩니다. 오류 발생 시에만 사용자에게 보고합니다.

## Phase 1: Plan (계획)

/plan 과 동일한 프로세스를 따릅니다:
1. 코드베이스 리서치
2. docs/solutions/ 검색
3. 구현 계획 생성
4. docs/plans/ 에 저장

자동 진행합니다.

## Phase 2: Work (구현)

/work 의 4단계를 따릅니다:
1. Setup: 브랜치 생성, 환경 준비
2. Implement: 계획에 따라 구현 + 유닛 테스트 작성
3. Quality Check: 빌드, 테스트, 전문 에이전트 검증 (/work Phase 3 참조)
4. Commit: 변경사항 커밋

빌드 + 테스트 통과 후 자동 진행합니다.

## Phase 3: Review (리뷰)

/review 의 6개 관점을 모두 실행합니다:
1. Security Sentinel
2. Performance Oracle
3. Architecture Strategist
4. Data Integrity Guardian
5. Code Simplicity Reviewer
6. Agent-Native Reviewer

결과를 P1/P2/P3로 정리합니다.

## Phase 3.5: Quality Agents (품질 에이전트)

6관점 리뷰와 별도로, 변경 내용에 따라 전문 에이전트를 실행합니다:

| 조건 | 에이전트 | 목적 |
|------|---------|------|
| UI/View 코드 변경 | `swift-ui-expert` | 레이아웃, Auto Layout, SwiftUI 구현 검증 |
| UI/View 코드 변경 | `apple-ux-expert` | HIG 준수, UX 흐름, 애니메이션 품질 |
| 대량 데이터 처리 구현 | `perf-optimizer` | 스크롤 성능, 메모리, 파싱 최적화 |
| 주요 기능 완성 | `app-quality-gate` | 코드 정확성 + 테스트 + HIG + 아키텍처 종합 심사 |

에이전트 실행은 가능한 한 병렬로 수행합니다.

## Phase 4: Resolve (해결)

리뷰 + 에이전트 결과를 통합 처리합니다:
- **P1 (Critical)**: 즉시 자동 수정
- **P2 (Important)**: 자동 수정
- **P3 (Minor)**: 자동 수정

모든 우선순위를 자동 수정합니다. 수정 후 Phase 3 (Review)를 다시 실행하여 P1이 0건인지 확인합니다.

**자동 게이트**: P1이 모두 해결되어야 다음 단계로 진행합니다. 2회 시도 후에도 P1이 남으면 사용자에게 보고합니다.

## Phase 5: Compound (문서화)

/compound 프로세스를 따릅니다:
- 해결책을 docs/solutions/ 에 문서화
- CLAUDE.md Correction Log 업데이트 (필요시)
- 새 규칙 추가 제안 (필요시)

## Phase 5.5: Pre-Ship Finalization (Ship 진입 게이트)

`/run`이 `ship`에서 멈추지 않도록, Phase 6 진입 전에 아래를 강제합니다:

1. **Clean Worktree 보장**: `git status --short`가 비어 있지 않으면 자동 정리
   - 변경사항이 코드/테스트/문서면 자동 커밋: `chore(run): finalize pipeline outputs`
   - 커밋이 불가하면 `git stash push -u -m "run-pre-ship-{timestamp}"`
   - 커밋과 stash 모두 실패하면 Phase 6으로 넘어가지 않고 사용자에게 실패 원인 보고
2. **브랜치 가드**: 현재 브랜치가 `main`이면 즉시 feature 브랜치 생성 후 진행
3. **Remote/권한 확인**:
   - upstream이 없으면 `git push -u origin {branch}` 실행
   - `gh auth status` 실패 시 인증 이슈를 먼저 해결하고 재시도
4. **Diff 존재 확인**: `main...HEAD` diff가 0이면 ship 생략하고 사용자에게 종료 보고

## Phase 6: Ship (배포)

1. `pr-reviewer` 에이전트로 최종 PR 리뷰 실행:
   - git diff 기반 변경사항 분석
   - `.claude/rules/` 코딩 룰 준수 검증
   - HealthKit/SwiftData 안전성 확인
   - 크래시 위험 코드 검출
2. `/ship` 스킬을 **비대화형(non-interactive) 모드**로 실행:
   - 사용자 선택 질문 없이 자동 정책으로 진행
   - 기존 PR이 있으면 재사용, 없으면 생성
   - merge 성공 후 main 동기화 + 로컬 브랜치 정리 + xcodegen 후처리 수행
3. PR 링크 및 최종 merge 결과를 사용자에게 전달

## Pipeline Control

각 Phase 완료 시 진행 상황을 보고합니다:

```
━━━ Phase {N}: {Name} Complete ━━━
{summary}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

승인 없이 자동 진행합니다. 사용자가 중단하면 즉시 멈춥니다.

## Error Recovery

각 Phase에서 오류 발생 시:
1. **오류 내용과 영향 범위를 사용자에게 즉시 보고**
2. **자동 복구 시도**: 빌드 실패 → 에러 수정 후 재시도 (최대 2회)
3. **복구 불가 시**: 이전 Phase 상태로 롤백하고 사용자에게 선택지 제시
   - 수동 수정 후 현재 Phase 재실행
   - 이전 Phase로 돌아가 계획 수정
   - 파이프라인 중단

Phase별 실패 처리:
- **Plan 실패**: 코드베이스 분석 재시도 또는 사용자에게 추가 컨텍스트 요청
- **Work 실패**: `git stash`로 변경 보존, 에러 수정 후 재시도
- **Review 실패**: 개별 리뷰어 실패는 나머지 결과로 진행, 전체 실패 시 재실행
- **Resolve 실패**: 수정 건별로 커밋하여 부분 진행 보존
- **Ship 실패**:
  - PR 생성 실패 시 `/ship`이 PR 제목/본문/수동 명령어를 복사용 포맷으로 출력 → 사용자가 수동 생성 가능
  - merge 대기(checks pending)는 재시도 후 실패 로그를 첨부해 보고
