---
tags: [codex, tokens, model-routing, testing]
date: 2026-09-26
category: plan
status: approved
---

# Codex 실행 비용 절감

사용자가 승인한 모델 분담, 로그 요약, 중복 검증 재사용, 최소 컨텍스트 위임을 적용한다. `.claude` 원본과 필수 품질 게이트를 보존한다.

## Affected Files

| 파일 | 변경 |
|------|------|
| `AGENTS.md`, `.codex/agent-map.md`, `.codex/skill-compat.md` | 모델 라우팅과 공통 실행 정책 연결 |
| `.codex/agent-memory/README.md`, `.codex/token-efficiency.md` | 필요한 컨텍스트만 읽기, 테스트 실행과 검증 재사용 계약 |
| `scripts/test-{unit,ui,watch-ui}.sh`, 공통 로그 요약 helper | 전체 로그 보관, 제한된 요약, 종료 상태 보존 |
| `scripts/codex-check.py`, `scripts/tests/` | 명시적 검증 증거 저장/조회와 회귀 테스트 |
| `.gitignore`, `docs/solutions/architecture/` | 로컬 증거 제외, 운영/측정 방법 문서화 |

## Implementation Steps

1. Sol/Luna/Astra 모델과 추론 강도, 실제 spawn 인자, 상향 조건을 정의한다.
2. 기존 테스트 실행기를 유지하면서 요약을 공통화한다. test scope나 실패 코드를 변경하지 않는다.
3. 동일 입력의 성공한 검증만 재사용할 수 있는 명시적 receipt를 추가한다. 코드/환경/명령 변경, 실패, 로그 소실은 재사용 불가다.
4. `/work`와 `/run`의 중복 실행을 동일 증거 참조로 대체하되 phase와 관점은 유지한다. smoke는 full gate를 대체하지 않는다.
5. fixture 기반 스크립트 테스트, shell syntax, parity, 독립 검토를 수행하고 결과를 문서화한다.

## Verification / Risks

- Xcode 앱 코드는 변경하지 않는다. 스크립트는 임시 git repo와 fake process로 성공/실패/입력 변경을 재현한다.
- ignored 입력과 외부 simulator 상태는 자동 fingerprint만으로 증명할 수 없다. 재사용 전 명시적 환경 확인을 요구하며 불명확하면 재실행한다.
- 문서의 모델은 전역 설정이 아니다. 실행 시 실제 지원 모델을 확인하고 명시적으로 전달한다.
- 절감률은 가정하지 않는다. 같은 작업의 입력/출력 토큰, 재시도, 검증 결과를 기록해 비교한다.
