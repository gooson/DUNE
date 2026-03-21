# Codex Agent Memory

이 디렉토리는 Codex가 `.claude/agent-memory/**` 를 읽은 뒤 추가로 남기는 **shadow memory** 저장소다.

## Principles

- `.claude/agent-memory/**` 는 source memory 이며 직접 수정하지 않는다.
- Codex가 새 learnings를 저장해야 할 때만 `.codex/agent-memory/**` 를 사용한다.
- review 단계에서는 memory를 자동으로 쓰지 않는다.
- 검증되지 않은 추측, 일회성 로그, 환경 의존적 노이즈는 기록하지 않는다.

## Naming

- agent별 파일명 사용:
  - `perf-optimizer.md`
  - `ui-test-expert.md`
  - 필요 시 `reviewer-architecture.md`
- 공통 원칙은 이 README에만 남기고, agent별 learnings는 개별 파일로 분리한다.

## Read Order

1. `.claude/agent-memory/<agent>/MEMORY.md`
2. 관련 solution / correction 문서
3. `.codex/agent-memory/<agent>.md` (존재할 때)

## Write Policy

- 다음 조건을 모두 만족할 때만 기록한다:
  - 같은 유형의 판단에 재사용 가치가 있음
  - 코드/빌드/리뷰 결과로 검증됨
  - 프로젝트 전반에 적용 가능한 패턴임

## Non-Goals

- Claude 전용 repo 밖 persistent memory 경로를 그대로 모사하지 않는다.
- 세션 중간 scratch notes를 장기 memory로 승격하지 않는다.
