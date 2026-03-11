---
tags: [ai, apple-intelligence, foundation-models, workout-template, natural-language, beginner-ux]
date: 2026-03-12
category: brainstorm
status: draft
---

# Brainstorm: AI 운동 빌더 자연어 성공률 개선

## Problem Statement

현재 AI 운동 빌더는 "운동명을 정확히 찾은 뒤 템플릿을 조립한다"는 계약에 너무 강하게 묶여 있다. 이 구조는 운동명을 모르는 초보자에게 불리하다.

실제 사용자는 "어깨 운동 만들어줘", "집에서 20분 하체", "허리 부담 적은 등 운동", "덤벨만으로 상체 루틴"처럼 **부위 / 시간 / 장비 / 목적 중심의 자연어**로 요청한다. 하지만 현재 플로우는 이 요청을 바로 exercise catalog 검색 질의로 연결하는 경향이 강하고, 검색은 exercise name / localizedName / aliases substring match 위주라서 generic Korean prompt를 많이 놓친다.

결과적으로:

- 초보자형 자연어 요청 대부분이 실패한다.
- 실패하더라도 이유가 구체적으로 드러나지 않는다.
- 입력 예시는 자연어를 권장하지만 실제 지원 범위는 더 좁다.
- 사용자는 "AI가 못 알아듣는다"라고 느끼고 기능 신뢰를 잃는다.

핵심 문제는 LLM 품질 자체보다도, **자연어 의도 해석 단계 없이 카탈로그 exact resolution으로 너무 빨리 내려가는 구조**에 있다.

## Target Users

- 운동명을 정확히 모르는 초보자
- 부위/시간/장비 중심으로 루틴을 요청하는 사용자
- 템플릿을 빠르게 만들고 싶은 반복 운동 사용자
- Apple Intelligence 지원 기기에서 온디바이스 AI 기능을 기대하는 사용자

## Success Criteria

1. 다음과 같은 한국어 자연어 요청이 높은 확률로 템플릿 생성에 성공한다.
   - "어깨 운동 만들어줘"
   - "집에서 덤벨로 20분 상체 루틴"
   - "하체 위주로 짧게"
   - "러닝 전에 할 가벼운 코어 운동"
2. 실패 시 "왜 실패했는지"와 "어떻게 다시 말하면 되는지"를 구체적으로 안내한다.
3. 온디바이스만 사용한다. 외부 API, 서버 검색, 클라우드 추론 없이 동작한다.
4. 지원 불가 input type은 계속 막되, 사용자가 이해할 수 있는 사유를 노출한다.
5. 개인 최근 운동 맥락을 활용하되, 맥락이 없더라도 기본 템플릿 생성이 가능하다.

## Root Cause Summary

현재 실패율이 높은 원인은 아래 조합으로 보인다.

1. **의도 해석 부재**
   - "어깨", "상체", "집에서", "짧게" 같은 요구를 구조화된 제약으로 먼저 파싱하지 않는다.
2. **검색 계약이 너무 좁음**
   - 검색이 exercise name / localizedName / aliases substring match 중심이라 generic request에 약하다.
3. **도구 호출 프롬프트가 정확명 검색을 과도하게 유도**
   - 모델이 broad request를 broad query planner로 바꾸기보다 바로 exact exercise lookup으로 가기 쉽다.
4. **실패 UX가 뭉뚱그려져 있음**
   - unsupported / ambiguous / no-match / low-context failure가 모두 비슷한 메시지로 보인다.

## Proposed Approach

### 1. 자연어 요청을 먼저 "운동 설계 입력"으로 해석

운동명을 찾기 전에 요청을 먼저 아래 구조로 해석한다.

- targetMuscles: 어깨, 가슴, 등, 하체, 코어, 상체, 전신
- duration: 10분, 20분, 30분 등
- equipment: 맨몸, 덤벨, 바벨, 머신, 케이블, 홈짐, 헬스장
- goal: 근비대, 가볍게, 회복, 워밍업, 러닝 전, 초보자용
- exclusions: 허리 부담 적게, 무릎 부담 적게, 점프 없이
- setting: 집에서, 헬스장에서
- intensity: 가볍게, 보통, 빡세게

LLM이 바로 운동명을 뽑는 대신, 먼저 **의도-제약 추출기** 역할을 하도록 바꾼다.

### 2. 검색을 "운동명 검색"에서 "후보 생성"으로 확장

카탈로그 검색을 다음 단계로 확장한다.

- exact exercise name match
- localized name / aliases match
- muscle group 기반 후보 생성
- equipment 기반 필터
- category 기반 필터
- Korean generic phrase를 catalog-friendly query로 변환
  - 예: "어깨 운동" -> "숄더 프레스", "레터럴 레이즈", "리버스 플라이"
  - 예: "등 운동" -> "랫 풀다운", "로우", "풀업"

즉, search tool은 단일 free-text lookup이 아니라 **query planner + candidate resolver**가 되어야 한다.

### 3. 템플릿 생성 파이프라인을 2단계로 분리

권장 파이프라인:

1. Request Interpretation
   - 자연어를 구조화된 제약으로 변환
2. Candidate Resolution
   - 제약을 만족하는 template-capable exercise 후보 찾기
3. Template Assembly
   - 중복 제거, duration 정렬, muscle balance 반영, supported input type만 선택
4. Explanation / Fallback
   - 일부 제약을 만족하지 못하면 무엇을 완화했는지 설명

### 4. 실패를 한 종류로 보지 않고 분류

실패는 최소 아래로 분류한다.

- unsupportedDevice
  - Apple Intelligence unavailable
- unsupportedRequest
  - 현재 저장 스키마로 표현할 수 없는 요청
  - 예: rounds-based HIIT only, mobility-only template
- ambiguousRequest
  - 요청이 너무 짧거나 범위가 넓어 여러 해석이 가능한 경우
- noCatalogMatch
  - 조건을 만족하는 template-capable 운동을 찾지 못한 경우
- partialConstraintDrop
  - 일부 제약은 반영하지 못했지만 안전한 기본 템플릿은 생성 가능한 경우

### 5. 실패 UX를 "이유 + 다음 예시" 형태로 개선

현재 generic failure 대신 다음 구조를 사용한다.

- 실패 이유 한 줄
- 어떤 조건이 문제였는지 한 줄
- 다시 시도할 수 있는 예시 2-3개

예시:

- "아직 이 요청은 템플릿으로 만들기 어려워요. 점프 중심 HIIT나 mobility-only 루틴은 현재 템플릿 입력 형식과 맞지 않습니다."
- "이렇게 바꿔보세요: `덤벨로 20분 하체 루틴`, `초보자용 어깨 운동 4개`, `러닝 전 코어 템플릿`"

### 6. 초보자 친화 기본값을 명시

초보자 대상이면 생성 기본값도 초보자 중심이어야 한다.

- 운동 수: 3-5개 우선
- 장비 미지정 시 맨몸/덤벨 우선
- duration 미지정 시 20-30분 기본
- 강도 미지정 시 중간 강도
- 부위만 말하면 대표 compound + 쉬운 accessory 조합 우선

## UX Direction

### Input Guidance

- placeholder를 실제 지원하는 자연어 예시로 갱신
- prompt field 하단에 quick chips 제공
  - 어깨 20분
  - 집에서 맨몸
  - 덤벨 상체
  - 러닝 전 코어

### Result Guidance

- 생성 성공 시 "어떤 가정을 사용했는지" 짧게 노출 가능
  - 예: "장비가 지정되지 않아 덤벨/맨몸 기준으로 구성했어요."

### Failure Guidance

- unsupported reason + retry examples
- 필요 시 "운동 직접 추가" CTA 유지

## Constraints

### Technical

- 온디바이스 Apple Intelligence만 사용
- 현재 템플릿 저장 계약은 유지해야 함
- 지원 input type은 계속 allowlist 기반으로 관리해야 함
- unsupported type을 무리하게 template-capable로 넓히면 저장/실행 경로와 충돌 가능
- 응답 지연이 길어지지 않도록 prompt와 tool 결과 길이를 관리해야 함

### Product

- 초보자가 이해할 수 있는 언어여야 함
- 운동명 정확성보다 "완성 가능한 안전한 템플릿"이 우선
- 실패는 줄이되, 억지 생성보다 설명 가능한 실패가 낫다

## Edge Cases

1. "좋은 운동 만들어줘"처럼 너무 추상적임
   - 기본 초보자 full-body template 제안 또는 clarification-style fallback
2. "점프 없이 무릎 부담 적은 하체"처럼 제약이 많음
   - 일부 제약만 반영 가능할 때 무엇을 반영했고 무엇을 완화했는지 설명
3. mobility / HIIT only 요청
   - 현재 template schema 불가면 명확히 설명하고 strength/cardio template 예시 제시
4. 장비가 전혀 없음
   - bodyweight 우선으로 degrade
5. 부위가 여러 개 섞임
   - 상체/하체/전신 분류 후 대표 조합 선택
6. 최근 운동 맥락상 특정 부위가 과로 상태
   - 가능한 경우 다른 부위 우선 추천
7. 한국어 generic noun 사용
   - "어깨", "등", "가슴", "하체", "맨몸", "집에서", "초보자용" 등을 first-class signal로 지원

## Scope

### MVP (Must-have)

- 한국어 자연어 요청을 구조화 제약으로 해석하는 단계 추가
- 부위 / 시간 / 장비 / 목적 / 난이도 / 제외 조건 일부 지원
- generic Korean request에 대한 candidate expansion 추가
- failure reason 분류 및 사용자 메시지 분리
- retry example 문구 제공
- acceptance test set 정의
  - 초보자 자연어 프롬프트 중심
- prompt field 예시 문구와 helper copy를 실제 지원 범위에 맞게 수정

### Nice-to-have (Future)

- 일본어/영어 natural language parity 강화
- 개인 과거 성공 템플릿 기반 reranking
- prewarm / response streaming으로 체감 속도 개선
- "이전 요청 다시 생성" 또는 "비슷하게 다시 만들기"
- 생성 결과 설명 카드
- prompt quality telemetry와 on-device evaluation harness

## Acceptance Prompt Set

최소 아래 요청들은 회귀 테스트/수동 검증 세트로 관리해야 한다.

- "어깨 운동 만들어줘"
- "30분짜리 어깨 운동 만들어줘"
- "집에서 맨몸으로 상체 루틴"
- "덤벨만으로 20분 하체"
- "초보자용 가슴 운동"
- "러닝 전에 할 코어 운동"
- "허리 부담 적은 등 운동"
- "운동 쉬었다가 다시 시작하는 사람용 전신 루틴"

## Open Questions

1. unsupported request에서 완전 실패보다 "가장 가까운 안전한 strength/cardio template"로 자동 변환할지 여부
2. "초보자용"을 sets/reps/intensity 어디까지 반영할지
3. 장비 미지정 시 bodyweight 우선인지, dumbbell + bodyweight 혼합 우선인지
4. 한국어 generic muscle phrase 사전을 rule로 둘지, LLM extraction에만 맡길지
5. partial success일 때 어떤 제약이 drop됐는지 UI에서 어디까지 노출할지

## Proposed Next Step

다음 단계에서는 `/plan`으로 아래 구현 축을 기준으로 계획을 세우는 것이 적절하다.

1. Request interpretation schema 정의
2. catalog candidate expansion 설계
3. failure taxonomy + localized copy 정의
4. acceptance tests 및 regression prompts 추가

## Next Steps

- [ ] `/plan AI 운동 빌더 자연어 성공률 개선` 으로 구현 계획 생성
