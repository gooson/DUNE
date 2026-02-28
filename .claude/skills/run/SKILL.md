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

## Phase 6: Ship (배포)

1. 최종 커밋 정리
2. `pr-reviewer` 에이전트로 최종 PR 리뷰 실행:
   - git diff 기반 변경사항 분석
   - `.claude/rules/` 코딩 룰 준수 검증
   - HealthKit/SwiftData 안전성 확인
   - 크래시 위험 코드 검출
3. PR 생성:
   ```
   gh pr create --title "{title}" --body "{body}"
   ```
4. PR 링크를 사용자에게 전달

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
- **Ship 실패**: PR 생성 실패 시 수동 명령어 제공
