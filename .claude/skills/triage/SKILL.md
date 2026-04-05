---
name: triage
description: "리뷰 결과를 하나씩 제시하여 승인/스킵/수정을 결정합니다. /review 후에 사용합니다."
---

# Triage: 리뷰 결과 분류

가장 최근의 /review 결과를 기반으로 발견사항을 하나씩 처리합니다.

## Process

### Step 1: 리뷰 결과 확인

가장 최근 /review 실행 결과를 참조합니다.

**결과 조회 순서**:
1. 현재 대화 내 /review 실행 결과가 있으면 사용
2. `/tmp/review-findings-{sanitized-branch}.json` 파일이 있으면 로드
   - `{sanitized-branch}` = `git branch --show-current` 의 `/`를 `-`로 치환한 값
   - 예: `feature/hrv-chart` → `review-findings-feature-hrv-chart.json`
3. 둘 다 없으면 `/review` 먼저 실행을 권장합니다

### Step 2: 발견사항별 처리

P1부터 시작하여 각 발견사항을 하나씩 사용자에게 제시합니다.

각 발견사항에 대해 다음 형식으로 표시:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[P{N}] {Category}: {Title}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: {path}:{line}
Issue: {description}
Suggestion: {solution}

Actions:
  [A] Approve - TODO로 생성하여 나중에 처리
  [S] Skip - 이번에는 무시
  [C] Customize - 내용을 수정하여 적용
  [F] Fix Now - 즉시 수정
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

사용자의 선택을 기다린 후 다음 발견사항으로 진행합니다.

### Step 3: Action 실행

각 선택에 따라:

**[A] Approve**:
- todos/ 에 TODO 파일을 생성합니다
- 파일명: `NNN-ready-pN-{slug}.md`
- .claude/rules/todo-conventions.md 의 형식을 따릅니다

**[S] Skip**:
- 해당 발견사항을 건너뜁니다
- 사유를 기록할지 사용자에게 묻습니다

**[C] Customize**:
- 사용자의 수정 내용을 반영하여 TODO를 생성합니다

**[F] Fix Now**:
- 즉시 해당 이슈를 수정합니다
- 수정 후 검증합니다

### Step 4: 요약

모든 발견사항 처리 후 결과를 요약합니다:

```
━━━━━ Triage Summary ━━━━━
Approved:   N건 (TODO 생성됨)
Skipped:    N건
Fixed:      N건
Customized: N건
━━━━━━━━━━━━━━━━━━━━━━━━━━

TODO files created:
- todos/NNN-ready-pN-{slug}.md
- ...
```

## 다음 단계 안내

- TODO 항목들은 `/work` 로 처리할 수 있습니다
- `/compound` 로 이번 리뷰에서 배운 내용을 문서화할 수 있습니다
