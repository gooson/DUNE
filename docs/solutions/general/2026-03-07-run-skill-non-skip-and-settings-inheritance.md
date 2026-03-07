---
tags: [run-skill, workflow, permissions, settings-local, pipeline-contract]
category: general
date: 2026-03-07
severity: important
related_files:
  - .claude/skills/run/SKILL.md
  - .claude/settings.local.json
  - .claude/settings.json
  - CLAUDE.md
related_solutions:
  - docs/solutions/general/2026-03-04-run-ship-completion-hardening.md
  - docs/solutions/architecture/2026-02-16-agent-pipeline-integration.md
---

# Solution: Run Skill Non-Skip Contract And Settings Inheritance

## Problem

`/run`이 "전체 자동 파이프라인"을 표방하지만 실제 실행에서는 하위 단계 산출물을 생략할 여지가 있었고, 권한 설정도 `.claude/settings.local.json`의 빈 override 때문에 기본 허용 목록을 상속하지 못할 수 있었다.

### Symptoms

- `/run`이 `/plan`, `/work`, `/review`, `/compound`, `/ship`를 모두 명시적으로 수행하지 않고 요약형으로 끝날 수 있음
- phase 완료 기준이 느슨해 계획서, 리뷰 요약, 문서화 없이 다음 단계로 넘어갈 수 있음
- 권한 문제를 고치기 위해 local allowlist를 직접 복제하면 이후 `settings.json`과 drift 위험이 생김
- 실패/생략 경로에서도 `/run` 최종 응답이 모든 산출물 경로를 강제해 계약 충돌이 발생할 수 있음

### Root Cause

두 가지 계약이 불명확했다.

1. `/run`은 상위 파이프라인이지만 각 하위 skill의 필수 절차와 종료 산출물을 강제하는 실행 계약이 없었다.
2. `.claude/settings.local.json`의 빈 `permissions` 객체가 기본 설정을 덮어쓸 수 있는데, 이를 "전체 승인"을 위해 별도 복제본으로 채우면 장기적으로 `settings.json`과 동기화가 깨진다.

## Solution

`/run`에 non-skip contract와 phase별 completion gate를 추가해 실제 절차 생략을 막고, `settings.local.json`은 `{}` 로 되돌려 기본 `settings.json`을 그대로 상속하도록 정리했다. 또한 `/run` 최종 출력 계약을 산출물 강제가 아니라 `artifact or explicit reason` 방식으로 바꿔 실패/생략 경로와 충돌하지 않게 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.claude/skills/run/SKILL.md` | `Non-Skip Contract`와 `Phase 0: Initialization` 추가 | `/run`이 하위 skill 본문을 직접 읽고 시작하도록 강제 |
| `.claude/skills/run/SKILL.md` | Plan/Work/Review/Resolve/Compound/Ship에 완료 게이트 추가 | 각 단계의 산출물과 검증 없이 다음 단계로 넘어가지 않도록 보장 |
| `.claude/skills/run/SKILL.md` | `Final Output Contract`를 상태 기반(`completed/skipped/failed`)으로 변경 | 실패/생략 phase에서도 허위 산출물 없이 종료 가능 |
| `.claude/settings.local.json` | local override를 `{}`로 축소 | 기본 `settings.json`의 permissions/hooks를 그대로 상속해 drift 제거 |
| `CLAUDE.md` | 프로세스 correction 2건 추가 | 동일한 workflow/config 실수 재발 방지 |

### Key Code

```md
## Non-Skip Contract
1. `/plan`, `/work`, `/review`, `/compound`, `/ship`의 `SKILL.md`를 직접 읽는다.
2. 각 Phase는 완료 증빙이 있어야만 종료한다.

## Final Output Contract
1. 각 Phase의 상태: completed | skipped | failed
2. Plan/Review/Compound/Ship는 산출물 경로 또는 명시적 사유를 반드시 포함한다.
```

```json
{}
```

## Prevention

자동화 스킬을 수정할 때는 "문구상 자동"이 아니라 "실행 계약상 자동"인지 확인해야 한다. 상위 skill이 하위 skill을 호출하면 반드시 시작 조건, 완료 조건, 스킵 조건, 실패 시 출력 계약까지 같이 검토한다. 로컬 설정 파일은 기본 설정을 보정할 최소 diff만 가져야 하며, 전체 allowlist/denylist 복제는 금지한다.

### Checklist Addition

- [ ] 상위 skill이 하위 skill의 `SKILL.md`를 실제 절차 기준으로 강제하는가
- [ ] 각 phase에 `완료 증빙`, `스킵 근거`, `실패 보고`가 모두 정의되어 있는가
- [ ] 최종 출력 계약이 성공 경로뿐 아니라 skipped/failed 경로와도 모순되지 않는가
- [ ] `.claude/settings.local.json`이 기본 설정 복제본이 아니라 최소 override만 담고 있는가

### Rule Addition (if applicable)

신규 rules 파일은 추가하지 않았다. 이 이슈는 프로젝트 전용 프로세스 교정으로 충분하므로 `CLAUDE.md` Correction Log에 기록했다.

## Lessons Learned

- 자동화 파이프라인은 "하위 절차를 읽는다"는 선언만으로 충분하지 않고, phase별 진입/완료 게이트가 있어야 실제 생략을 막을 수 있다.
- 설정 override는 빈 값도 동작을 바꾼다. 기본 설정을 덮는 파일은 복제보다 상속이 안전하다.
- 출력 계약은 성공 산출물만 요구하면 안 되고, skipped/failed 상태의 정당한 종료 형식도 같이 정의해야 한다.
