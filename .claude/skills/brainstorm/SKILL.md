---
name: brainstorm
description: "아이디어나 요구사항이 모호할 때 구조화된 질문을 통해 명확화합니다. 사용자가 '뭘 만들지 고민 중', '어떻게 접근할지 모르겠어', '이거 어떻게 하면 좋을까', '기능 아이디어 정리' 등 방향이 불확실한 요청을 할 때 이 스킬을 사용합니다."
---

# Brainstorm: 요구사항 명확화

$ARGUMENTS 에 대해 구조화된 brainstorm을 수행합니다.

## Process

### Step 0: 기존 문서 확인

$ARGUMENTS 관련 기존 brainstorm이 있는지 확인합니다:
- `docs/brainstorms/` 에서 Glob으로 관련 문서 검색
- 존재하면 사용자에게 "기존 brainstorm을 업데이트할지, 새로 시작할지" 확인
- 업데이트 시 기존 문서를 읽고 Open Questions 중심으로 추가 탐색

### Step 1: 초기 분석

$ARGUMENTS를 분석하여 다음을 파악합니다:
- 핵심 목표가 무엇인지
- 누가 사용할 것인지
- 어떤 제약 조건이 있는지

### Step 2: 반복적 질문 (한 번에 2-3개씩)

5개 프레임워크를 한 번에 던지지 않고, 핵심부터 단계적으로 질문합니다.

**1차 질문 (핵심 — 반드시 먼저)**:
- 이 기능이 해결하려는 핵심 문제는 무엇인가요?
- MVP에 꼭 필요한 것은 무엇이고, 나중에 추가할 수 있는 것은?

**2차 질문 (1차 응답 기반으로 필요한 것만 선택)**:

다음 중 1차 응답에서 불명확한 영역만 추가 질문합니다:

- **Users**: 주요 사용자가 누구이고 가장 중요하게 여기는 것은?
- **Constraints**: 기술적/시간적 제약이 있나요?
- **Edge Cases**: 데이터가 없거나 불완전할 때 어떻게 해야 하나요?
- **Success Criteria**: 성공을 어떻게 측정할 수 있나요?

1차 응답이 이미 충분히 구체적이면 2차 질문 없이 Step 3으로 진행합니다.

### Step 3: 문서 생성

사용자 응답을 기반으로 brainstorm 문서를 생성합니다.

**출력 경로**: `docs/brainstorms/YYYY-MM-DD-{topic-slug}.md`

**문서 구조**:

```markdown
---
tags: []
date: YYYY-MM-DD
category: brainstorm
status: draft
---

# Brainstorm: {Topic}

## Problem Statement
[핵심 문제 정의]

## Target Users
[사용자 정의 및 니즈]

## Success Criteria
[성공 측정 기준]

## Proposed Approach
[초기 접근 방법]

## Constraints
[기술적, 시간적, 리소스 제약]

## Edge Cases
[고려해야 할 엣지 케이스]

## Scope
### MVP (Must-have)
- ...
### Nice-to-have (Future)
- ...

## Open Questions
[아직 답이 필요한 질문]

## Next Steps
- [ ] /plan 으로 구현 계획 생성
```

### Step 4: 다음 단계 안내

brainstorm 완료 후 사용자에게 안내합니다:
- `/plan {topic}` 으로 구현 계획을 생성할 수 있습니다
- brainstorm 문서 경로를 알려줍니다
