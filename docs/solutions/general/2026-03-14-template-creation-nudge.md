---
tags: [template, recommendation, nudge, dashboard, activity]
date: 2026-03-14
category: solution
status: implemented
---

# Template Creation Nudge

## Problem

사용자가 반복적으로 동일한 운동 패턴을 수행하지만, 이를 템플릿으로 저장하지 않아 매번 수동으로 운동을 구성해야 함.

## Solution

### 핵심 구조

1. **WorkoutTemplateRecommendationService** (기존): 42일 lookback, 3+ 반복 패턴 감지
2. **TemplateOverlapChecker**: Jaccard 유사도 (intersection/union >= 80%) 로 기존 템플릿과 중복 판정
3. **TemplateNudgeDismissStore**: UserDefaults + JSON encode, 7일 TTL 해제 상태 관리
4. **TemplateNudgeCard**: Dashboard InlineCard 기반 넛지 UI (dismiss/save/start CTAs)
5. **SuggestedWorkoutSection bookmark**: Activity 탭 추천 카드에 bookmark 아이콘 오버레이
6. **TemplateFormView pre-fill init**: 추천 → 템플릿 변환 시 이름/운동 목록 사전 입력

### 패턴 결정

| 결정 | 이유 |
|------|------|
| Jaccard similarity (intersection/union) | 순서 무관 운동 구성 비교에 적합 |
| TemplateSnapshot으로 init-time lowercasing | 반복 비교 시 불필요한 문자열 변환 제거 |
| @Query in View → ViewModel에 snapshot 전달 | SwiftData ViewModel import 금지 규칙 준수 |
| sheet(item:) binding | isPresented + optional check는 dismiss 후 빈 sheet 위험 |
| UserDefaults JSON encode | 간단한 key-value, CloudKit 동기화 불필요 |
| Optional callback for bookmark | 기존 SuggestedWorkoutSection 호출부 깨뜨리지 않음 |

### 파일 구조

```
Domain/UseCases/
  TemplateOverlapChecker.swift     # TemplateSnapshot + Jaccard checker
  TemplateNudgeDismissStore.swift  # UserDefaults dismiss 상태
Presentation/Dashboard/
  Components/TemplateNudgeCard.swift  # Dashboard 넛지 카드
  DashboardView.swift              # @Query + sheet(item:) 통합
  DashboardViewModel.swift         # loadTemplateNudge() + dismissTemplateNudge()
Presentation/Activity/
  Components/SuggestedWorkoutSection.swift  # bookmark overlay
  ActivityView.swift               # sheet(item:) for recommendation save
Presentation/Exercise/
  Components/CreateTemplateView.swift  # pre-fill init
```

## Prevention

- **sheet 바인딩**: `isPresented` + 조건 체크 대신 `sheet(item:)` 사용하여 데이터 정합성 보장
- **대소문자 비교**: 비교 대상 데이터는 init 시점에 정규화 (lowercased)
- **Optional callback**: 기존 호출부에 영향 없이 기능 추가 시 `((Type) -> Void)?` 패턴 사용
- **Sendable + UserDefaults**: `nonisolated(unsafe) let defaults` 패턴 사용 (UserDefaults는 thread-safe)
