---
tags: [localization, i18n, rules, agents, mandatory]
category: general
date: 2026-03-04
severity: important
related_files:
  - AGENTS.md
  - .claude/rules/localization.md
  - docs/plans/2026-03-04-multilingual-mandatory-rule.md
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-completion-audit.md
---

# Solution: Localization 규칙 Always-On 필수 승격

## Problem

`localization.md` 규칙은 존재했지만 `AGENTS.md`의 Always-On `Mandatory rules` 목록에서 빠져 있었다.
이로 인해 세션 시작 시 다국어 규칙이 기본 로딩 집합에서 누락될 수 있고, 리뷰/구현 단계에서 localization leak 회귀 위험이 남아 있었다.

### Symptoms

- `AGENTS.md` Mandatory rules에 `localization.md` 부재
- 다국어 문자열 변경 요청이 들어와도 Trigger Rules에서 localization 규칙 강제가 명시되지 않음

### Root Cause

규칙 자산(`.claude/rules/localization.md`)은 준비되어 있었지만, 실행 진입점인 `AGENTS.md`의 Always-On/Trigger 섹션과 연결이 약했다.

## Solution

`AGENTS.md`를 수정해 localization 규칙을 필수 적용 경로에 명시적으로 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AGENTS.md` | Mandatory rules에 `/Users/shanks/work/Health/.claude/rules/localization.md` 추가 | 세션 시작 시 localization 규칙 Always-On 보장 |
| `AGENTS.md` | Trigger Rules에 `다국어/i18n/localization/번역 문자열 변경` 시 localization 규칙 참조 강제 문구 추가 | 요청 기반 실행에서도 누락 방지 |
| `docs/plans/2026-03-04-multilingual-mandatory-rule.md` | 구현 계획 문서 추가 | 변경 의도/검증 기준 기록 |

### Key Code

```md
### Mandatory rules
- /Users/shanks/work/Health/.claude/rules/localization.md

## Trigger Rules (Parity)
- 다국어/i18n/localization/번역 문자열 변경 요청은 `.claude/rules/localization.md`를 반드시 참조합니다.
```

## Prevention

Always-On 규칙과 Trigger 규칙을 동시에 관리하여, 규칙 파일 존재 여부와 실제 실행 강제를 분리하지 않는다.

### Checklist Addition

- [ ] `.claude/rules/`에 신규 규칙을 추가하면 `AGENTS.md` Mandatory rules 반영 여부를 함께 점검한다.
- [ ] 문자열/i18n 관련 트리거 문구가 `AGENTS.md`에 명시되어 있는지 확인한다.

### Rule Addition (if applicable)

신규 규칙 파일 추가는 없고, 기존 `.claude/rules/localization.md`를 Mandatory rules로 승격했다.

## Lessons Learned

규칙 문서 자체의 품질만으로는 충분하지 않고, `AGENTS.md`의 Always-On + Trigger 연결이 있어야 실제 작업 루프(`/run`, `/work`, `/review`)에서 일관되게 적용된다.
