---
tags: [activity, recommendation, personalization, equipment, ux]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 추천 운동 개선 (현실성 + UI 명확화)

## Problem Statement

현재 추천 운동이 사용자 현실과 맞지 않아 실제 시작으로 이어지지 않는다.

- 사용 불가능한 운동(기구 없음)이 추천된다.
- 관심 없는 운동이 반복 추천된다.
- Activity 탭 추천 카드에서 "펼침/비펼침" 동작 차이가 직관적이지 않다.

## Target Users

- 헬스장 이용자
- 홈트 이용자

공통 니즈:
- 지금 환경에서 바로 가능한 운동 추천
- 원치 않는 운동을 즉시 제외할 수 있는 제어권
- 추천 카드에서 다음 액션을 바로 이해하고 실행 가능한 UI

## Success Criteria

- 추천 목록이 현재 환경(헬스장/홈트)과 보유 기구에 맞게 필터링된다.
- 사용자가 "관심 없음" 처리한 운동은 재추천되지 않는다.
- 추천 카드에서 "바로 시작"과 "대안 보기"가 명확히 구분된다.

## Proposed Approach

1. 추천 필터 모델 도입
- 사용자 컨텍스트: Gym / Home
- 컨텍스트별 보유 기구 목록
- 관심 없음 운동 ID 목록

2. 추천 로직 필터 반영
- 추천 후보/대안 생성 시 `보유 기구 + 관심 없음` 필터 적용
- 필터 후 후보 부족 시 허용 범위 내 fallback 추천 제공

3. Activity 추천 카드 UI 개선
- 카드 상단에 Gym/Home 컨텍스트와 Equipment 편집 진입 제공
- 행 액션을 `Start` / `Alternatives` / `Not interested`로 명시 분리
- 펼침 영역은 "대안 운동" 섹션으로 표현하여 차이를 시각적으로 고정

## Constraints

- 기존 ActivityViewModel의 파생 상태 갱신 흐름(`refreshSuggestionFromRecords`) 유지
- SwiftData 스키마 변경 없이 UserDefaults 기반 설정 저장
- 기존 추천 서비스의 피로도 중심 알고리즘은 유지하고 필터만 추가

## Edge Cases

- 보유 기구 선택이 과도하게 좁아 추천이 비는 경우
- 관심 없음 운동이 누적되어 후보가 매우 줄어드는 경우
- Gym/Home 전환 직후 추천 카드가 즉시 갱신되어야 하는 경우

## Scope

### MVP (Must-have)
- Gym/Home 컨텍스트 선택
- 컨텍스트별 보유 기구 편집
- 관심 없음 운동 제외
- 추천 카드 액션 명확화 (바로 시작, 대안 보기, 관심 없음)

### Nice-to-have (Future)
- 부위/카테고리 선호도 가중치
- "관심 없음"의 기간 만료(예: 30일)
- 컨텍스트 자동 추론(위치/시간 기반)

## Open Questions

- Gym 컨텍스트 기본 기구 범위를 전체 허용으로 둘지, 최소 세트로 둘지
- 추천 비어 있음 상태에서의 UX 문구/행동 유도 방식

## Next Steps

- [ ] `/plan recommended-workout-improvement` 로 구현 계획 확정
