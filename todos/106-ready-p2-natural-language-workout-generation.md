---
source: brainstorm/apple-on-device-ml-sdk-research
priority: p2
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# 자연어 운동 생성 (Foundation Models)

## 설명

사용자가 "오늘 어깨 운동 30분짜리 만들어줘" 같은 자연어 요청으로 운동 루틴을 자동 생성합니다.

## 구현 범위

- `@Generable` 구조체로 운동 템플릿 스키마 정의 (`AIWorkoutTemplate`, `AIExerciseSlot`)
- Tool Calling으로 exercises.json 검색 연동
- 피로도/기록 데이터를 컨텍스트로 제공하여 개인화
- 생성된 템플릿을 기존 `WorkoutTemplate`으로 변환

## 참고

- `docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md` Section 7.3
- 기존: `DUNE/Domain/UseCases/WorkoutRecommendationService.swift`
- exercises.json 이름 매칭 → Tool Calling `searchExercise` 도구로 해결
