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

## Phase 2 Items

- [ ] **단위 전환 (kg/lb)**: 사용자 설정에 단위 환경설정 추가
  - 설정: Settings 탭에 "Weight Unit" 토글
  - 입력/표시 모두 선택 단위로 변환
  - 저장은 항상 kg (내부 표준 단위)

- [ ] **Progressive Overload 차트**: 운동별 중량/볼륨 추이 그래프
  - ExerciseRecord 히스토리에서 주간/월간 트렌드 계산
  - Swift Charts로 시각화
  - 운동 상세 화면에서 접근

- [ ] **운동 루틴/템플릿**: 자주 하는 운동 조합 저장
  - WorkoutTemplate 모델 (운동 목록 + 기본 세트/렙/무게)
  - "Start from Template" 기능
  - 템플릿 CRUD UI

- [ ] **세트 복사 (이전 세트 -> 현재)**: 빠른 입력
  - "Repeat Last Set" 버튼 추가
  - 현재 세션의 마지막 완료 세트 값으로 새 세트 생성

- [ ] **운동 설명 & 이미지/GIF**: 올바른 자세 가이드
  - 운동 라이브러리 JSON에 description, imageURL 필드 추가
  - ExercisePickerView에서 상세 보기
  - 번들 내 정적 이미지 또는 SF Symbol 확장

- [ ] **근육 그룹 시각화 (인체 맵)**: 볼륨 분포 시각화
  - 전면/후면 인체 SVG에 근육 그룹별 색상 매핑
  - 주간 볼륨 기반 intensity 표시
  - Activity 탭 또는 전용 "Muscles" 뷰

- [ ] **Apple Watch 연동**: 실시간 세트 기록
  - WatchConnectivity로 세션 데이터 동기화
  - Watch 앱에서 세트 완료/무게 입력
  - 심박수 실시간 표시

- [ ] **AI 기반 운동 추천 (Fitbod-style)**
  - 피로도/회복 모델 (근육 그룹별 마지막 운동 + 볼륨)
  - 추천 알고리즘: 회복된 근육 우선, 주간 밸런스 고려
  - Activity 탭 상단에 "Suggested Workout" 카드

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
