---
tags: [dashboard, briefing, coaching, morning, UX]
date: 2026-03-14
category: brainstorm
status: draft
---

# Brainstorm: 투데이탭 매일 아침 브리핑

## Problem Statement

사용자가 앱을 열었을 때 다양한 메트릭 카드와 인사이트가 나열되어 있지만, **"오늘 나의 상태가 어떻고 무엇을 해야 하는지"** 를 한눈에 파악하기 어렵다. 기존 대시보드는 데이터 브라우징에 최적화되어 있고, 아침 루틴에 맞는 **요약형 내러티브**가 부재하다.

## Target Users

- 매일 아침 앱을 열어 컨디션을 확인하는 습관적 사용자
- 수치보다 **"오늘 어떻게 하면 좋을지"** 가이드를 원하는 사용자
- HRV/RHR 데이터를 꾸준히 쌓아 baseline이 형성된 사용자

## Success Criteria

1. 브리핑 시트 완독률 70%+ (dismiss까지 스크롤)
2. 브리핑 확인 후 대시보드 체류 시간 감소 (이미 맥락을 파악했으므로)
3. 브리핑에서 추천한 행동(운동 강도 조절 등)의 실행률 추적 가능

## Proposed Approach

### UI: 전용 시트/오버레이

- 그날 첫 앱 실행 시 **모달 시트**로 브리핑 표시
- 아래로 스와이프해서 닫기
- 투데이탭에서 다시 열 수 있는 진입점 (예: 히어로 카드 탭 또는 상단 버튼)
- 브리핑을 이미 본 경우 진입점은 축소/subtle 상태

### 콘텐츠 구성 (4개 섹션)

#### 1. 전날 vs 오늘 비교 (Recovery Summary)

```
┌─────────────────────────────────────┐
│  🌙 어젯밤 수면                      │
│  6h 42m · 깊은 수면 1h 20m           │
│  ▼ 전날 대비 48분 부족                │
│                                     │
│  💓 오늘의 컨디션                     │
│  72점 (Good) · HRV ▲5ms · RHR ▼2bpm │
│  "어제보다 회복이 잘 되었습니다"       │
└─────────────────────────────────────┘
```

- 데이터: `SleepQueryService` (전날 수면), `ConditionScore` (오늘), HRV/RHR delta
- 비교 기준: 전일 동시간 또는 7일 평균 baseline

#### 2. 오늘의 추천/가이드 (Today's Guide)

```
┌─────────────────────────────────────┐
│  🏋️ 오늘의 운동 가이드               │
│  컨디션 72점 → 중강도 추천            │
│  "상체 근력 운동이나 30분 조깅이       │
│   적합합니다"                        │
│                                     │
│  ⚡ 회복 포인트                       │
│  "수면 부채 1.2h — 오늘 30분 일찍     │
│   취침하면 주말 전 해소 가능"          │
└─────────────────────────────────────┘
```

- 데이터: `ConditionScore.status` → 강도 매핑, `SleepDeficitAnalysis`, `CoachingEngine`
- 기존 `CoachingInsight`의 recovery/training 카테고리 활용

#### 3. 주간 맥락 (Weekly Context)

```
┌─────────────────────────────────────┐
│  📊 이번 주 흐름                     │
│  [월■ 화■ 수■ 목□ 금□ 토□ 일□]       │
│  컨디션 평균 68점 (▲ 지난주 대비 +4)   │
│                                     │
│  🎯 주간 운동 목표                    │
│  3/5일 완료 · 남은 2일               │
└─────────────────────────────────────┘
```

- 데이터: `recentScores` (7일), `weeklyGoalProgress`
- 요일별 컨디션 미니 히트맵 + 주간 평균 트렌드

#### 4. 날씨 연동 조언 (Weather-Aware Tips)

```
┌─────────────────────────────────────┐
│  🌤️ 오늘 날씨 & 운동                 │
│  맑음 22°C · 실외 운동 적합           │
│  "오후 미세먼지 보통 예상 —            │
│   오전 실외 운동을 추천합니다"         │
└─────────────────────────────────────┘
```

- 데이터: `WeatherSnapshot`, outdoor fitness level
- 기존 `CoachingInsight`의 weather 카테고리 활용

### 텍스트 생성: 템플릿 + AI 하이브리드

1. **즉시 표시**: 템플릿 기반 문장 생성 (지연 없음)
   - `BriefingTemplateEngine`: 조건별 문장 조합
   - 예: `"{status}입니다. HRV가 {delta}ms {direction}했고, 수면은 {sleepDuration} 기록했습니다."`
2. **비동기 교체**: `AICoachingMessageService` 응답 도착 시 자연어 버전으로 교체
   - 실패 시 템플릿 텍스트 유지 (graceful degradation)
3. **캐싱**: 같은 날 같은 데이터면 AI 응답 재사용

### 트리거 로직

```swift
// 그날 첫 실행 판정
@AppStorage("lastBriefingDate") private var lastBriefingDate: String = ""

var shouldShowBriefing: Bool {
    let today = Date.now.formatted(.iso8601.year().month().day())
    return lastBriefingDate != today
}

func markBriefingSeen() {
    lastBriefingDate = Date.now.formatted(.iso8601.year().month().day())
}
```

- 시간 무관, 날짜 기준
- 사용자가 dismiss하면 `lastBriefingDate` 갱신
- 투데이탭에서 재열람 가능 (날짜 체크 우회)

## Constraints

### 기술적

- 브리핑 데이터 = 기존 `DashboardViewModel.loadData()`의 결과물 재활용
- 새 HealthKit 쿼리 추가 최소화 (이미 대시보드가 모든 메트릭 로드)
- AI 메시지 서비스 지연/실패 시 UX 깨지면 안 됨
- Swift 6 concurrency 준수

### UX

- 시트가 대시보드 로딩을 지연시키면 안 됨 (병렬 또는 대시보드 로드 완료 후 표시)
- 데이터 부족 시 (baseline 미형성, 수면 데이터 없음) 해당 섹션 숨기기
- "매일 시트가 뜨는 게 귀찮다" → 설정에서 끄기 옵션

### 데이터

- Condition Score가 아직 계산 안 된 상태 (baseline 수집 중) → 브리핑 미표시 또는 제한된 브리핑
- 수면 데이터 없음 → 수면 섹션 스킵
- 날씨 권한 없음 → 날씨 섹션 스킵

## Edge Cases

| 상황 | 대응 |
|------|------|
| 앱 첫 설치 (데이터 없음) | 브리핑 미표시. baseline 수집 안내 |
| 수면 데이터만 없음 | 수면 섹션 스킵, 나머지 표시 |
| 날씨 권한 거부 | 날씨 섹션 스킵 |
| AI 서비스 타임아웃 | 템플릿 텍스트 유지 |
| 오후에 첫 실행 | 정상 표시 (시간 무관) |
| 앱 강제 종료 후 재실행 | 이미 본 경우 미표시 (`lastBriefingDate` 기준) |
| 시트 dismiss 전 앱 백그라운드 | 다음 foreground 시 시트 유지 |
| 자정 넘어 앱 사용 중 | 날짜 변경 감지 불필요 (다음 cold start에 새 브리핑) |

## Scope

### MVP (Must-have)

- [ ] 그날 첫 실행 시 브리핑 시트 자동 표시
- [ ] 4개 섹션: 수면/컨디션 비교, 오늘의 가이드, 주간 맥락, 날씨 조언
- [ ] 템플릿 기반 텍스트 (즉시 표시)
- [ ] 데이터 부족 시 섹션 graceful degradation
- [ ] 투데이탭에서 재열람 진입점
- [ ] 설정에서 브리핑 on/off 토글

### Nice-to-have (Future)

- [ ] AI 하이브리드 텍스트 (비동기 교체)
- [ ] 브리핑 내 액션 버튼 (예: "추천 운동 시작하기" → 운동 탭 이동)
- [ ] watchOS 브리핑 (축약 버전)
- [ ] 위젯용 브리핑 요약 (1줄 텍스트)
- [ ] 브리핑 히스토리 (과거 브리핑 다시보기)
- [ ] 푸시 알림 연동 ("아침 브리핑이 준비되었습니다")
- [ ] 사용자 선호 섹션 순서 커스터마이징

## Resolved Questions

1. **브리핑 재열람 UI**: 히어로 카드 아래쪽 섹션에 배치. 브리핑을 본 후에도 축소된 형태로 남아 탭하면 시트 재오픈
2. **애니메이션**: 화려하고 감성적으로. 시트 등장 시 섹션별 stagger fade-in, 숫자 카운트업, 그래프 드로잉 등 몰입감 있는 연출
3. **주간 맥락 요일 범위**: 오늘 기준 최근 7일 (월~일 고정 아님)

## Open Questions

1. **설정 위치**: 기존 설정 화면 내 "대시보드" 섹션? 별도 "브리핑" 섹션?

## Architecture Sketch

```
DashboardView
├─ .sheet(isPresented: $showBriefing)
│  └─ MorningBriefingView
│     ├─ MorningBriefingViewModel
│     │  ├─ BriefingTemplateEngine (텍스트 생성)
│     │  ├─ AICoachingMessageService (비동기 교체, Future)
│     │  └─ BriefingDataProvider (DashboardViewModel 데이터 가공)
│     ├─ RecoverySummarySection
│     ├─ TodayGuideSection
│     ├─ WeeklyContextSection
│     └─ WeatherAdviceSection
├─ BriefingEntryPoint (재열람 버튼)
└─ (기존 대시보드 컴포넌트들)

Domain Layer (새로 추가)
├─ BriefingTemplateEngine (UseCase)
│  └─ 조건별 문장 템플릿 조합
└─ BriefingData (Model)
   └─ 브리핑에 필요한 데이터 DTO
```

## Next Steps

- [ ] `/plan morning-briefing` 으로 구현 계획 생성
