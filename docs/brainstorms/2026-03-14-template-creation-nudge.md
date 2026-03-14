---
tags: [template, recommendation, nudge, ux, onboarding]
date: 2026-03-14
category: brainstorm
status: draft
---

# Brainstorm: 템플릿 생성 넛지

## Problem Statement

사용자가 같은 운동 조합을 반복적으로 수행하지만, 이를 템플릿으로 저장하지 않고 매번 수동으로 운동을 선택한다.

현재 `WorkoutTemplateRecommendationService`가 42일간 3회+ 반복 시퀀스를 감지하여 Activity 탭의 "Suggested Routines" 스트립에 표시하지만:
- 탭하면 즉시 운동 시작만 가능 (템플릿 저장 경로 없음)
- 대시보드에는 노출되지 않음 (회복 기반 `WorkoutRecommendationCard`만 존재)
- 운동 시작/완료 시점의 넛지가 없음

**핵심 간극**: 패턴은 감지하지만 "저장하시겠어요?"라고 제안하지 않는다.

## Target Users

- 주 3-5회 운동하는 사용자
- 2주 이상 비슷한 루틴을 반복하는 사용자
- 아직 템플릿 기능을 사용하지 않는 사용자 (핵심 타겟)

## Success Criteria

- 템플릿 0개인 사용자 중 넛지 노출 후 템플릿 생성율
- 넛지 → 템플릿 저장 전환율 (dismiss 비율)
- 반복 루틴의 운동 시작 시간 단축 (탐색→선택 시간)

## 기존 인프라

| 컴포넌트 | 역할 | 재사용 가능 |
|---------|------|-----------|
| `WorkoutTemplateRecommendationService` | 반복 시퀀스 감지 | ✅ 핵심 엔진 |
| `WorkoutTemplateRecommendation` | 감지 결과 모델 | ✅ 그대로 사용 |
| `TemplateExerciseResolver` | 추천→운동 정의 변환 | ✅ 템플릿 생성에도 사용 |
| `CreateTemplateView` | 템플릿 생성 UI | ✅ pre-fill 대상 |
| `WorkoutTemplate` (@Model) | 저장 모델 | ✅ 최종 저장 대상 |
| `SuggestedWorkoutSection` | Activity 추천 스트립 | ⚠️ CTA 추가 필요 |
| `WorkoutRecommendationCard` | 대시보드 카드 | ❌ 다른 데이터 (회복 기반) |

## Proposed Approach

### 넛지 포인트 2곳

#### 1. 대시보드 상시 카드

대시보드에 **"Your Routine"** 카드로 감지된 반복 패턴을 표시.

- 조건: `templateRecommendations.isEmpty == false` && 해당 패턴의 기존 템플릿이 없을 때
- 내용: "벤치프레스 → 인클라인 → 플라이를 3주 연속 하고 있어요"
- CTA 2개: "템플릿으로 저장" / "이 루틴 시작"
- dismiss 후 같은 패턴은 7일간 재노출 금지

#### 2. 운동 시작 시 (ExerciseView / QuickStart)

운동 선택 화면 상단에 **"지난번처럼"** 섹션.

- 현재 `SuggestedWorkoutCard`가 회복 기반 추천을 표시하는 위치에 인접
- 가장 최근 수행한 반복 패턴 1개만 표시 (과다 노출 방지)
- "이 루틴 시작" + "템플릿으로 저장" CTA

### 템플릿 저장 플로우

넛지에서 "템플릿으로 저장" 탭 시:
1. `TemplateExerciseResolver`로 추천 → `[ExerciseDefinition]` 변환
2. `CreateTemplateView`를 sheet로 표시 (운동 목록 pre-fill)
3. 사용자가 이름/순서 편집 후 저장
4. 넛지 dismiss (해당 패턴)

### 중복 방지 로직

- 기존 `WorkoutTemplate`의 운동 구성과 추천 시퀀스를 비교
- 80%+ 운동이 겹치면 이미 저장된 것으로 판단 → 넛지 미노출
- 비교: `Set<ExerciseDefinition.id>` 교집합 / 합집합 비율

## Constraints

- `WorkoutTemplateRecommendation`은 Domain 레이어 (`SwiftData` import 불가) → 중복 비교 로직은 Presentation 또는 별도 UseCase에서 수행
- 대시보드는 이미 카드가 많음 → 조건부 노출 + 우선순위 관리 필요
- 넛지 피로도 관리: dismiss 기록은 `UserDefaults` 또는 `@AppStorage`

## Edge Cases

- 운동 이력 0건 (신규 유저): 넛지 미노출 (최소 3회 반복 조건)
- 모든 패턴에 이미 템플릿이 있는 경우: 넛지 미노출
- 사용자가 넛지를 계속 dismiss: 점진적 간격 증가 (7일 → 14일 → 30일)
- 하루에 여러 패턴 감지: 최고 score 1개만 대시보드에 표시

## Scope

### MVP (Must-have)
- 대시보드 넛지 카드 1개 (최고 score 패턴)
- "템플릿으로 저장" → `CreateTemplateView` pre-fill
- dismiss 기록 (`UserDefaults`)
- 기존 템플릿과의 중복 검사

### Nice-to-have (Future)
- 운동 시작 시 "지난번처럼" 섹션
- 운동 완료 직후 "이 루틴 저장?" 넛지
- dismiss 간격 점진적 증가
- Watch에서도 넛지 표시
- 넛지 → AI 템플릿 생성기 연결 ("이 루틴을 AI가 최적화해볼까요?")

## Open Questions

1. 대시보드 카드 위치: 기존 `WorkoutRecommendationCard` 위? 아래? 대체?
2. 넛지 카드 디자인: 기존 카드 스타일 통일 vs 눈에 띄는 별도 디자인?
3. "이미 템플릿 있음" 판단 임계값: 80% 겹침이 적절한가?

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (MVP 범위)
