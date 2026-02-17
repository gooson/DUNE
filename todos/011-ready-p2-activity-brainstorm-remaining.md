---
source: brainstorm/activity-tab-redesign
priority: p2
status: ready
created: 2026-02-17
updated: 2026-02-17
---

# Activity Tab Brainstorm - Remaining Items Checklist

`docs/brainstorms/2026-02-17-activity-tab-redesign.md` 기반 미구현 항목 체크리스트.

## MVP Gaps (Phase 1 잔여) ✅ All Done

- [x] **커스텀 운동 생성**: CustomExercise SwiftData 모델 + CreateCustomExerciseView + ExercisePickerView 통합
- [x] **운동 중 앱 종료 시 draft 저장**: WorkoutSessionDraft (UserDefaults) + scenePhase 감시 + ExerciseView 복원 배너
- [x] **운동 검색 UX 개선**: 근육 그룹별 필터 + 장비별 필터 + 결과 수 표시 + Clear Filters

## Phase 2 Items ✅ All Done

- [x] **단위 전환 (kg/lb)**: WeightUnit enum + @AppStorage + 모든 UI 반영 (c391336)
- [x] **Progressive Overload 차트**: ExerciseHistoryView + 4 metrics + trend line (ca548a3)
- [x] **운동 루틴/템플릿**: WorkoutTemplate SwiftData + CRUD + start-from-template (e6d5e1b)
- [x] **세트 복사 (이전 세트 → 현재)**: repeatLastCompletedSet() + UI button (b10d73f)
- [x] **운동 설명 & 이미지/GIF**: ExerciseDescriptions + ExerciseDetailSheet + FlowLayout (39a1071)
- [x] **근육 그룹 시각화 (인체 맵)**: MuscleMapView + front/back body + weekly volume (81bd8cf)
- [x] **AI 기반 운동 추천**: WorkoutRecommendationService + SuggestedWorkoutCard (146e804)
- [x] **Apple Watch 연동 (iOS 인프라)**: WatchSessionManager + DTOs (b58da45)

## Phase 3 Items

- [ ] **소셜 기능**: 운동 공유/비교
- [ ] **1RM 추정 (Epley/Brzycki 공식)**: 최대 중량 추정
- [ ] **볼륨 분석**: 근육별 주간 세트 수 대시보드
- [ ] **슈퍼세트/서킷 지원**: 복합 운동 세션
- [ ] **커스텀 운동 카테고리**: 사용자 정의 카테고리 생성

## Open Questions (브레인스토밍에서 미해결)

- [ ] 운동 라이브러리 데이터 소스: 번들 JSON vs API vs 커뮤니티 기여?
- [ ] kg/lb 단위 설정 UI 위치: Settings 탭 vs 운동 화면 내 인라인?
- [ ] 기존 HealthKit 운동 데이터와 새 ExerciseRecord의 중복 처리 전략?
