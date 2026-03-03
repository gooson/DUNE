---
tags: [theme, recommendation, watch, animation, design-system]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 새로운 테마 추가

## Problem Statement

현재 5개 테마(Desert/Ocean/Forest/Sakura/Arctic)가 존재하지만,
모든 사용자의 다양한 감수성을 더 폭넓게 만족시키기 위해 신규 테마 확장이 필요하다.
특히 "테마 종류(방향)"를 먼저 결정해야 이후 토큰/배경/애니메이션 구현이 안정적으로 진행된다.

## Target Users

- 전체 사용자

사용자 핵심 니즈:
- 취향 선택 폭 확대
- 기존 테마와 명확히 구분되는 감성
- iOS + watchOS에서 일관된 경험

## Success Criteria

- 테마 만족도 상승
- 테마 다양성에 대한 체감 개선

## Proposed Approach

### 1) 테마 종류 우선 결정

아래 후보 중 1개를 우선 선택해 MVP로 구현:

- **Noir Calm**: 차콜/실버 기반의 미니멀 프리미엄 테마
- **Solar Pop**: 선셋 오렌지/코랄 기반의 활기 있는 에너지 테마
- **Lavender Mist**: 라일락/안개톤 기반의 부드러운 몽환 테마
- **Neon Pulse**: 다크 배경 + 네온 포인트 기반의 하이콘트라스트 테마

### 2) 구현 원칙

- 기존 `AppTheme` + prefix 기반 resolver 구조 유지
- iOS/watchOS 동시 적용
- 배경 모션은 필수(저진폭/저속 기본)
- 토큰 단위 확장: accent/score/metric/tab/weather/card 전면 반영

### 3) 추천 우선순위 (실행 관점)

1. **Noir Calm** (추천): 기존 5개와 겹침이 가장 적고, 전체 사용자 대상 무난성/고급감 균형이 좋음
2. **Solar Pop**: 차별성은 크지만 장시간 사용 피로도 관리 필요
3. **Lavender Mist**: 감성 강점이 있으나 Sakura와 경계 설계 필요
4. **Neon Pulse**: 개성은 강하지만 호불호 리스크 큼

## Constraints

- 기술/시간/리소스 제약: 명시된 제한 없음
- 필수 조건:
- watchOS 동시 적용
- 애니메이션 필수
- 전체 화면/컴포넌트 적용

## Edge Cases

- 사용자 입력 기준으로 별도 제한 사항 없음
- 단, 구현 시 기본 가독성/성능 회귀는 검증 필요

## Scope

### MVP (Must-have)

- 테마 종류 1개 확정
- iOS + watchOS 전면 적용
- 애니메이션 포함
- 토큰/자산 전체 확장

### Nice-to-have (Future)

- 테마 강도 프리셋(Soft/Standard)
- 테마별 모션 강도 옵션

## Open Questions

- 최종 테마 종류를 무엇으로 확정할지
- 선택 테마의 애니메이션 모티프(파형/노이즈/리본)를 어떤 방향으로 갈지

## Next Steps

- [ ] 선택한 테마명으로 `/plan` 생성 (예: `/plan noir calm theme`)
