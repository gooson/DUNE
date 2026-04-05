---
name: retrospective
description: "세션 회고. 최근 작업을 분석하고, 잘된 점/개선점을 정리하며, CLAUDE.md에 교정사항을 추가합니다."
---

# Retrospective: 세션 회고

최근 작업을 회고하고 학습 내용을 시스템에 반영합니다.

## Process

### Step 1: 최근 작업 분석

```bash
git log --oneline -20
```

다음을 확인합니다:
- 최근 변경사항과 커밋 메시지
- 완료된 TODO 항목
- 생성된 solution 문서
- 발생했던 이슈와 해결 방법

### Step 2: 회고 프레임워크

**Keep (잘된 점)**
- 효과적이었던 패턴이나 접근 방법
- 재사용할 수 있는 성공 사례

**Improve (개선할 점)**
- 실수했거나 비효율적이었던 부분
- 더 나은 방법이 있었던 경우
- 반복된 문제

**Learn (학습한 점)**
- 새로 발견한 패턴이나 기법
- 주의해야 할 사항
- 프로젝트에 대한 새로운 이해

### Step 3: 시스템 업데이트

회고 결과를 시스템에 반영합니다:

**3.1 docs/corrections-active.md 업데이트**

개선할 점에서 반복 가능한 실수가 있다면 `docs/corrections-active.md`에 교정사항을 추가합니다 (CLAUDE.md 본문이 아닌 active 파일에 기록):

```markdown
### #{번호} YYYY-MM-DD: {교정 내용}
```

**3.2 Rules 업데이트 제안** (필요시)

새로운 규칙이 필요하면 .claude/rules/ 에 추가를 제안합니다.
사용자의 승인을 받은 후 추가합니다.

**3.3 Solutions 문서화 제안** (필요시)

문서화되지 않은 해결책이 있다면 `/compound` 실행을 권장합니다.

**3.4 Domain Skills 업데이트** (필요시)

프로젝트 컨벤션이 발견되었다면 해당 skill 파일 업데이트를 제안합니다.

### Step 4: 회고 요약

회고 결과를 사용자에게 보고합니다:

```
━━━━━ Retrospective Summary ━━━━━

## Keep
- {잘된 점}

## Improve
- {개선할 점}

## Learn
- {학습한 점}

## System Updates
- CLAUDE.md Correction Log: {추가된 항목 수}건
- Rules: {제안된 규칙 수}건
- Solutions: {문서화 필요 항목 수}건

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
