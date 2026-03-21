---
name: brainstorm
description: "아이디어나 요구사항이 모호할 때 구조화된 질문을 통해 명확화합니다. 사용자가 '뭘 만들지 고민 중', '어떻게 접근할지 모르겠어', '이거 어떻게 하면 좋을까', '기능 아이디어 정리' 등 방향이 불확실한 요청을 할 때 이 스킬을 사용합니다."
---

# Brainstorm: 요구사항 명확화

$ARGUMENTS 에 대해 구조화된 brainstorm을 수행합니다.

## Process

### Step 1: 초기 분석

$ARGUMENTS를 분석하여 다음을 파악합니다:
- 핵심 목표가 무엇인지
- 누가 사용할 것인지
- 어떤 제약 조건이 있는지

### Step 2: 구조화된 질문 (반드시 사용자에게 질문)

다음 프레임워크로 사용자에게 질문합니다:

**Purpose (목적)**
- 이 기능이 해결하려는 핵심 문제는 무엇인가요?
- 성공을 어떻게 측정할 수 있나요?

**Users (사용자)**
- 주요 사용자는 누구인가요?
- 사용자가 가장 중요하게 여기는 것은 무엇인가요?

**Constraints (제약)**
- 기술적 제약이 있나요? (기존 시스템, 성능 요구 등)
- 시간/리소스 제약은?

**Edge Cases (엣지 케이스)**
- 실패하면 어떻게 되나요?
- 동시에 많은 사용자가 사용하면?
- 데이터가 없거나 불완전하면?

**Scope (범위)**
- MVP에 꼭 필요한 것은?
- 나중에 추가할 수 있는 것은?

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
