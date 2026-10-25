---
topic: session-efficiency-and-locked-ui
date: 2026-10-25
tags: [codex, skills, tokens, session-audit, ui-testing, screen-lock]
category: plan
status: completed-for-requested-scope
confidence: medium
related_solutions:
  - ../solutions/architecture/2026-09-26-codex-token-efficiency.md
---

# 최근 3주 실행 근거에 따른 스킬 개선 계획

## Context

사용자가 최근 3주 세션 전체의 실제 토큰 소비, 반복 중단, 화면 잠금 중 UI 테스트 문제를 조사하고 개선하도록 요청했다. 기존 재시도·검증 재사용 규칙이 있으므로 비슷한 지침을 추가하는 대신 실제 사용량과 실행 증거를 먼저 확인한다.

분석 기간은 2026-10-04 17:55부터 2026-10-25 17:55 직전까지(KST), 정확히 21일이다. 이번 감사 자체의 비용은 제외한다. 로컬 Codex 활성·보관·압축 rollout과 Claude projects 기록을 대상으로 하며, 동기화되지 않은 원격 기록은 포함했다고 주장하지 않는다.

## Requirements

- 요청별 usage를 집계한다. 누적 카운터, 복제된 response, Claude content block의 반복 usage를 중복 합산하지 않는다.
- 입력·캐시 읽기·캐시 쓰기·출력과 출력에 포함되는 reasoning을 구분한다. 토큰을 결제액이나 계정 한도 사용률로 환산하지 않는다.
- 실제 중단 이벤트, 테스트 실패, 환경 장애, assistant의 미완료 보고, 정상 compaction을 분리한다.
- `.claude/**`와 현재 진행 중인 앱·디자인 변경은 보존한다. Codex adapter와 실행 도구에만 개선을 적용한다.
- 화면 잠금, 디스플레이 수면, 시스템 수면, Simulator guest 상태, macOS GUI 자동화 권한을 분리한다. 잠금을 자동으로 해제하지 않는다.

## Approach

전체 로그를 프로그램으로 집계하고 상위 비용 세션과 실패 후보는 원문으로 확인한다. 최신 공식 문서는 현지 Xcode 도구 및 실행 기록과 교차 확인한다. 검색 키워드 출현 횟수를 장애 횟수로 보고하지 않는다. 이미지 직렬화 bytes도 텍스트 토큰으로 환산하지 않는다.

| 대안 | 판단 |
|------|------|
| 전 세션 본문을 모델에 그대로 로드 | 비용과 개인정보 노출이 커서 제외 |
| 최종 누적 사용량만 더하기 | 기간 경계·fork·모델 변경을 잘못 계산하므로 제외 |
| 모든 UI 실패를 Mac 잠금으로 간주 | macOS 앱 XCTest와 Simulator XCTest의 실행 조건이 달라 제외 |
| 재현 가능한 집계 + 실패 근거 + 최소 adapter 수정 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/audit-agent-sessions.py` | 추가 | 로컬 세션 usage 및 중단 집계 |
| `scripts/tests/test_audit_agent_sessions.py` | 추가 | 중복·기간 경계·혼합 포맷 계약 검증 |
| `scripts/lib/ui-host-state.py` | 추가 | 제한 시간 내 읽기 전용 호스트 진단 |
| `scripts/test-ui.sh`, `scripts/test-watch-ui.sh` | 수정 | 기존 실행 의미를 유지하고 `.host.json` 기록 |
| `scripts/tests/test_ui_host_state.py` | 추가 | 잠금 진단의 불명확/실패 상태 검증 |
| `.codex/skill-compat.md`, `.codex/token-efficiency.md` | 수정 | 대기 비용·세션 감사·잠금 진단 진입점 |
| `.codex/ui-execution.md` | 추가 | 필요할 때만 읽는 UI 환경 장애 분류 절차 |
| `docs/reviews/2026-10-25-session-efficiency-audit.md` | 추가 | 수치·근거·우선순위·남은 검증 |

## Implementation Steps

1. **집계와 근거 확인**: 전체 로컬 파일을 이벤트 시각으로 필터링하고 중복을 제거한다. provider·model·project·세션별 사용량과 원문 위치를 로컬 ignored JSON에 보존한다.
2. **중단 분류**: 명시적 interruption과 테스트 실행 지연을 구분하고, 고비용 세션의 반복 대기·지침 읽기·UI 검증 범위를 확인한다.
3. **호스트 진단 구현**: 시작 시 현재 사용자 콘솔/Aqua 관련 상태와 잠금 진단을 기록한다. 확인할 수 없는 값은 `unknown`, 진단 실패는 테스트를 막지 않는다.
4. **스킬 실행 개선**: 기존 절차를 중복하지 않으며 실패 경로별 재개 조건, 단계별 증거 재사용, 장시간 대기 시 모델 호출 절감을 명시한다.
5. **검증과 결과**: 변경한 Python 계약, 셸 구문, parity, diff 검사를 수행한다. 앱 화면을 바꾸지 않으므로 앱 전체 회귀나 디자인맵 재캡처를 추가하지 않는다.

## Edge Cases

| Case | Handling |
|------|----------|
| 기간 전에 시작한 장기 세션 | 이벤트 시각으로 포함, legacy는 기간 전 baseline 유지 |
| 같은 요청의 반복/복제 기록 | response/message ID로 제거 |
| 모델 변경 | usage 시점의 모델로 귀속 |
| 토큰 필드/기록 누락 | unknown coverage를 별도로 명시 |
| 손상되거나 읽을 수 없는 로그 | coverage에 기록하며 완전한 감사라고 주장하지 않음 |
| `ioreg` 필드 누락·다른 사용자·불일치 | `unknown`; 실행 가능성 추정 금지 |
| 다른 runner가 simulator lock 점유 | 해당 실험은 보류하고 기존 실행을 방해하지 않음 |
| macOS 잠금 상태에서 CLI 성공 | 해당 명령 성공만 증명, XCTest/시각 검증 성공으로 확대 금지 |

## Testing Strategy

실제 로그를 다시 실행하지 않는 합성 fixture로 집계 정확성을 검증한다. UI 실행기 변경은 진단 sidecar만 추가하므로 계약 테스트와 구문 검사로 확인한다. 잠금/해제 상태의 동일 XCTest 비교 실험은 별도 환경 증거가 필요하며, 다른 실행기가 점유 중이면 수행하지 않는다.

## Risks

주요 위험은 누락된 로그를 완전한 이력으로 오해하거나 캐시 토큰·이미지 bytes·키워드 출현을 비용/실패로 오해하는 것이다. 보고서에서 관측 수치와 추정, 미검증을 구분한다. 이번 변경의 실제 절감률은 이후 동급 작업으로 측정하며 사전에 단정하지 않는다.

## Execution Result

집계·호스트 진단·Codex adapter 개선을 구현했다. 집계 11개, 진단 5개, 기존 runner 계약 5개가 통과했고 shell 구문·parity·diff 검사를 확인했다. 전수 집계는 전체 합계와 usage 시점의 Health 귀속 합계가 일치했다.

후속 사용자 요청에 따라 별도 전용 기기와 worktree 잠금 범위로 검증했다. Mac 잠금 상태에서 iPhone·Watch XCTest가 각 1개 통과했고 새 PNG 6장을 확보했다. 실험에서 발견한 registry/deadline의 잠금 FD 전달 버그도 수정했다. 잠금 해제 비교군과 개선 후 실사용 절감률은 별도 항목이다. 후속 검증·우선순위는 [감사 보고서](../reviews/2026-10-25-session-efficiency-audit.md), 재사용할 교훈은 [해결책](../solutions/testing/2026-10-25-session-audit-and-ui-host-context.md)에 기록했다.


## 최종 범위 확정

2026-10-25 사용자가 “지금은 잠금 상태 결과로 마무리”를 선택했다. iPhone·Watch의 잠금 상태 targeted XCTest 각 1개 통과와 새 PNG 6장, 실행기 수정 검증을 이번 완료 범위로 확정한다. 잠금 해제 A/B는 사용자 선택으로 보류하며 추가 실행하지 않는다. 향후 실사용 토큰 절감률은 아직 측정하지 않았고 이번 결과에 포함하지 않는다.
