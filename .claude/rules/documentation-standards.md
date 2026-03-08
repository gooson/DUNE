# Documentation Standards

## Language

- 문서: 한국어 (기술 용어는 영어 유지)
- 코드 주석: 영어
- 파일명: 영어, kebab-case

## Date Format

- YYYY-MM-DD (ISO 8601)

## YAML Frontmatter

모든 docs/ 내 문서는 YAML frontmatter를 포함합니다:

```yaml
---
tags: []
date: YYYY-MM-DD
category: brainstorm | plan | solution | persona
status: draft | reviewed | approved | implemented
---
```

## Solution Documents

- `docs/solutions/{category}/` 하위에 저장
- 검색 가능한 tags 필수
- Problem / Solution / Prevention 구조 필수
- 카테고리: security, performance, architecture, testing, general
- solution 문서는 **최종 merged implementation** 기준으로 유지합니다. 중간 실험안(`SpatialTapGesture`, 임시 fallback 등)을 남겼다가 실제 코드와 어긋나게 두지 않습니다.
- interaction contract가 바뀌면 관련 solution 문서를 **같은 변경에서 함께 갱신**합니다.

## Plan Documents

- `docs/plans/` 에 저장
- 파일명: `YYYY-MM-DD-{topic-slug}.md`
- Affected Files 테이블 필수
- Implementation Steps 순서 필수

## Brainstorm Documents

- `docs/brainstorms/` 에 저장
- 파일명: `YYYY-MM-DD-{topic-slug}.md`
- Problem Statement + Scope (MVP / Future) 구조
