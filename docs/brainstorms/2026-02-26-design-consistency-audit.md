---
tags: [design-system, consistency, color, watch, ds-tokens, accessibility]
date: 2026-02-26
category: brainstorm
status: draft
---

# Brainstorm: 디자인 일관성 전체 감사 및 재통합

## Problem Statement

앱 전체(iOS + watchOS)에서 디자인 시스템의 적용 수준이 불균일함.
- iOS detail view: 92% 준수 (매직넘버 5-6개)
- watchOS: 0% 준수 (DS 토큰 없음, 30개 하드코딩 컬러)
- 카테고리 컬러: 유사색 충돌 2건, 다크 모드 누락 6건+
- AccentColor 우회: `.accentColor` 직접 참조 11건
- Score 그라데이션: Condition ≠ Wellness 불일치 4건

## Target Users

- 1차: 앱 사용자 (시각적 일관성 → 신뢰도)
- 2차: 개발자 (DS 토큰 사용 → 유지보수성)

## Success Criteria

1. iOS 전체 뷰: DS 토큰 준수율 100% (매직넘버 0개)
2. watchOS 전체 뷰: DS 토큰 기반 컬러 시스템 적용
3. `.accentColor` 직접 참조 0건 → `DS.Color.warmGlow` 또는 `Color("AccentColor")` 경유
4. 카테고리 컬러: 인접색 충돌 0건, 다크 모드 variant 100% 커버
5. Score 그라데이션: Condition/Wellness 통합 또는 의도적 분리 문서화

---

## 현재 상태 분석

### A. iOS Detail Views (15+ 뷰)

| 영역 | 준수율 | 발견 사항 |
|------|--------|----------|
| DS.Spacing | 98% | 5개 매직넘버 (2, 4, 6pt) |
| DS.Color | 100% | 모두 토큰 사용 |
| Card 컴포넌트 | 98% | Hero/Standard/Inline 적절히 사용 |
| Material 배경 | 100% | thin/ultraThin 일관 |
| Typography | 100% | DS.Typography 토큰 사용 |
| Responsive | 95% | iPad/iPhone 분기 구현 |

**매직넘버 위반 목록:**

| 파일 | 라인 | 현재 | 수정 |
|------|------|------|------|
| ConditionScoreDetailView | 273 | `.padding(.horizontal, 6)` | `DS.Spacing.sm` (8) 또는 새 토큰 |
| ConditionScoreDetailView | 265 | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| ExerciseMixDetailView | 101 | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| ExerciseTypeDetailView | 219 | `spacing: 4` | `DS.Spacing.xs` |
| ExerciseSessionDetailView | 113 | `.opacity(0.08)` | DS.Opacity 토큰 필요 |
| InjuryHistoryView | 304 | `.opacity(0.12)` | DS.Opacity 토큰 필요 |

### B. watchOS Views (10 뷰)

| 뷰 | 하드코딩 컬러 수 | DS 토큰 | 상태 |
|----|-----------------|---------|------|
| MetricsView | 9 | 없음 | ❌ |
| ControlsView | 3 | 없음 | ❌ |
| RestTimerView | 5 | 없음 | ❌ |
| SessionSummaryView | 2 | 없음 | ❌ |
| SetInputSheet | 6 | 없음 | ❌ |
| WorkoutPreviewView | 1 | 없음 | ❌ |
| RoutineListView | 4 | 없음 | ❌ |
| QuickStartPickerView | 0 | 없음 | ✓ |
| SessionPagingView | 0 | 없음 | ✓ |
| ContentView | 0 | 없음 | ✓ |

**하드코딩 컬러 분포:**
- `.green` 15회 (progress, complete, buttons)
- `.gray` 10회 (secondary actions, completed dots)
- `.red` 3회 (destructive, heart rate)
- `.yellow` 2회 (pause, sync warnings)

**근본 원인**: Watch 타겟에서 공유 DesignSystem.swift에 접근 불가

### C. 카테고리 컬러 체계

#### 유사색 충돌 (⚠ 인접 배치 시 구분 어려움)

| 쌍 | RGB 차이 | 위험도 |
|----|----------|--------|
| MetricHRV ↔ WellnessVitals | < 5% 전 채널 | 🔴 높음 |
| MetricRHR ↔ MetricHeartRate | R채널 유사, G차이 있음 | 🟡 중간 |
| MetricBody ↔ ScoreFair | 동일 RGB | 🔴 의미 충돌 |

#### 다크 모드 누락

다음 컬러에 다크 모드 variant 미정의 (universal 단일값):
- MetricHeartRate, MetricActivity, MetricSteps, MetricSleep, MetricBody
- WellnessVitals, WellnessFitness
- 모든 Score 그라데이션 (Excellent~Warning)
- 모든 HR Zone (Zone1~Zone5)
- AccentColor (warmGlow)

> 다크 배경 위 contrast ratio 미달 우려 (WCAG AA 4.5:1 기준)

#### Score 그라데이션 불일치

| 레벨 | Condition | Wellness | 차이 |
|------|-----------|----------|------|
| Excellent | `(0, 0.8, 0.545)` teal | `(0, 0.8, 0.4)` teal | G채널 차이 |
| Good | `(0.22, 0.78, 0.42)` lime | `(0.6, 0.8, 0.2)` yellow-lime | 색상 다름 |
| Fair | `(0.918, 0.702, 0.059)` gold | `(1.0, 0.624, 0.039)` gold | 채도 차이 |
| Tired/Warning | `(0.922, 0.498, 0.18)` orange | `(1.0, 0.271, 0.227)` red | 의미 다름 |

### D. AccentColor 우회

`.accentColor` 직접 참조 11건 (DS.Color.warmGlow 우회):

| 파일 | 횟수 | 용도 |
|------|------|------|
| GlassCard.swift | 4 | Hero/Standard 카드 보더+오버레이 |
| WaveShape.swift | 2 | 탭 배경 gradient |
| HeroScoreCard.swift | 1 | 링 gradient |
| ProgressRingView.swift | 1 | 기본 색상 |
| EmptyStateView.swift | 2 | 아이콘, 버튼 |
| WaveRefreshIndicator.swift | 2 | 리프레시 애니메이션 |

> Correction #136에 따라 `Color("AccentColor")` 또는 `DS.Color.warmGlow` 경유 필수

---

## Proposed Approach

### Phase 1: DS 토큰 확장 (기반 작업)

1. **Opacity 토큰 추가**: `DS.Opacity.{subtle, light, medium, emphasis}`
2. **Shadow 토큰 추가**: `DS.Shadow.{card, elevated}` (현재 인라인 정의)
3. **watchOS DS 레이어 생성**: `WatchDesignSystem.swift` (Watch 타겟용 경량 DS)
4. **Score 그라데이션 통합**: Condition/Wellness 공통 5단계 또는 의도적 분리 결정

### Phase 2: 카테고리 컬러 재검토

1. **MetricHRV ↔ WellnessVitals 분리**: hue 20°+ 차이 확보
2. **MetricBody ≠ ScoreFair**: MetricBody 색상 조정 (gold → amber?)
3. **MetricRHR ↔ MetricHeartRate 분리**: RHR을 더 따뜻한 톤으로
4. **다크 모드 variant 전체 추가**: 밝기 +10~15% 조정
5. **WCAG AA contrast 검증**: 다크/라이트 모두 4.5:1 이상

### Phase 3: iOS 매직넘버 제거

1. 6개 위반 지점 DS 토큰으로 교체
2. `.accentColor` → `DS.Color.warmGlow` 11건 교체
3. 누락된 패턴 통일 (SectionGroup 일관성 등)

### Phase 4: watchOS DS 적용

1. `WatchDesignSystem.swift` 생성 (DS.Color.watch 네임스페이스)
2. 7개 뷰의 30개 하드코딩 컬러를 토큰으로 교체
3. Watch asset catalog에 누락 컬러 추가 (Score 그라데이션 등)

### Phase 5: 최종 감사

1. 전체 앱 빌드 검증 (iOS + watchOS)
2. 다크/라이트 모드 스크린샷 비교
3. iPad + iPhone + Watch 시뮬레이터 확인

---

## Constraints

- **기술적**: Watch 타겟과 iOS 타겟은 별도 모듈 → 공유 코드는 별도 파일 복사 또는 SPM 패키지 필요
- **시간**: F3 full loop (brainstorm → plan → work → review → compound)
- **호환성**: 기존 UI 동작 변경 없이 토큰만 교체 (시각적 변화 최소화)
- **Correction #129**: 비주얼 변경은 v1(보수적) → v2(강화) 2단계 접근

## Edge Cases

- 카테고리 컬러 변경 시 차트/sparkline 색상도 연쇄 변경
- Watch에서 Score 컬러가 없는 상태에서 HealthKit 데이터 표시 추가 시 fallback
- AccentColor 변경 시 시스템 UI 요소(네비게이션 바, 탭 바 tint) 영향

## Scope

### MVP (Must-have)
- [ ] DS.Opacity 토큰 추가
- [ ] iOS 매직넘버 6개 제거
- [ ] `.accentColor` → `DS.Color.warmGlow` 11건 교체
- [ ] 카테고리 유사색 3쌍 분리
- [ ] 다크 모드 variant 전체 추가
- [ ] watchOS DS 레이어 생성 + 30개 컬러 토큰화
- [ ] Score 그라데이션 통합/정리

### Nice-to-have (Future)
- [ ] WCAG AAA (7:1) contrast 달성
- [ ] DS.Shadow 토큰 추가
- [ ] Watch/iOS 공유 SPM 패키지로 DS 통합
- [ ] 접근성 테스트 (색맹 시뮬레이션)
- [ ] Color contrast 자동 검증 테스트

## Open Questions

1. MetricHRV 색상을 변경할 것인가, WellnessVitals를 변경할 것인가?
2. Condition/Wellness score 그라데이션을 완전 통합할 것인가, 의도적으로 다르게 유지할 것인가?
3. watchOS DS를 파일 복사로 할 것인가, SPM shared package로 할 것인가?

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (Phase 1~5 순서대로)
