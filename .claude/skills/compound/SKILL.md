---
name: compound
description: "완료된 작업에서 학습한 내용을 검색 가능한 문서로 저장합니다. 버그 수정, 기능 구현, 아키텍처 변경 등 문제를 해결한 직후에 사용하여 해결책을 docs/solutions/에 축적합니다. '해결책 정리해줘', '이거 문서화해줘', '배운 거 기록해줘' 요청 시에도 사용합니다."
---

# Compound: 해결책 문서화

$ARGUMENTS 에 대해 해결한 문제와 해결책을 문서화합니다.

## Process

### Step 1: 변경사항 분석

최근 변경사항을 분석합니다:
- `git log --oneline -10` 으로 최근 커밋 확인
- `git diff HEAD~{N}` 으로 관련 커밋 범위의 변경 내용 확인
- 어떤 문제를 해결했는지 파악

### Step 2: 카테고리 분류

해결된 문제를 다음 카테고리 중 하나로 분류합니다:
- **security**: 보안 관련 문제
- **performance**: 성능 관련 문제
- **architecture**: 구조/설계 관련 문제
- **testing**: 테스트 관련 문제
- **general**: 기타

### Step 3: 해결책 문서 생성

`.claude/skills/compound/templates/solution-template.md` 형식을 따릅니다.

**출력 경로**: `docs/solutions/{category}/YYYY-MM-DD-{topic-slug}.md`

문서에 반드시 포함할 내용:
- **Problem**: 구체적인 문제 설명 (증상 + 근본 원인)
- **Solution**: 해결 방법 (변경 파일 + 핵심 코드)
- **Prevention**: 향후 같은 문제를 방지하는 방법
- **Lessons Learned**: 이 경험에서 배운 점

### Step 4: YAML Frontmatter 최적화

tags를 검색에 유용하게 작성합니다:
- 기술 키워드 (예: "react", "sql", "auth")
- 문제 유형 (예: "n-plus-one", "race-condition", "xss")
- 관련 도메인 (예: "user-management", "payment", "api")

### Step 5: 관련 문서 업데이트

필요시 다음을 업데이트합니다:
- **CLAUDE.md Correction Log**: 반복 가능한 실수가 있다면 교정사항 추가
- **관련 TODO**: 해당 TODO의 상태를 `done`으로 업데이트
- **.claude/rules/**: 새 규칙이 필요하면 추가 제안

### Step 6: 검증

- [ ] YAML frontmatter의 tags가 검색에 유용한가?
- [ ] Problem 설명이 미래에 같은 문제를 겪을 때 찾을 수 있게 작성되었는가?
- [ ] Solution이 재현 가능하게 작성되었는가?
- [ ] Prevention이 구체적인가?

## Progress Markers

각 Step **시작 시** 아래 형식으로 시작 표시를 출력합니다:

```
━━━ Compound Step {N}: {Name} Start ━━━
```

각 Step **완료 시** 완료 표시를 출력합니다:

```
━━━ Compound Step {N}: {Name} Complete ━━━
```

시작 표시는 실제 작업 수행 **직전에** 반드시 출력합니다. 이를 통해 사용자가 추후 로그에서 각 Step의 시작점을 식별할 수 있습니다.

## 완료 후 안내

- 문서 저장 경로를 알려줍니다
- CLAUDE.md에 추가된 교정사항이 있으면 알려줍니다
- 관련 규칙 추가가 필요하면 제안합니다
