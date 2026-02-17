---
tags: [ux, wellness, sleep, body, tab-structure, redesign, oura, whoop, bear, apple-health]
date: 2026-02-17
category: brainstorm
status: draft
---

# Brainstorm: Sleep+Body 통합 Wellness 탭 & 앱 전체 UX 개편

## Problem Statement

현재 Dailve는 4탭 구조(Condition / Activity / Sleep / Body)를 사용한다.
Sleep 탭(3카드)과 Body 탭(3카드+Form)이 각각 얇은 콘텐츠로 독립 탭을 차지하며,
사용자는 수면과 체성분이라는 연관된 데이터를 별도 탭에서 왔다갔다해야 한다.

**핵심 문제:**
1. **정보 분산**: 수면 품질과 체성분 변화는 회복/웰니스의 두 축인데 분리되어 있음
2. **얇은 탭**: Sleep 탭은 카드 3개, Body 탭도 카드 3개 — 각각 탭 하나를 정당화하기엔 부족
3. **경쟁사 대비 구조 열위**: Oura(3탭), WHOOP(홈+서브), Apple Health(Summary) 등 모두 통합 접근
4. **탭 네이밍 불명확**: "Condition"은 추상적, "Body"는 체성분만 연상
5. **앱 전체 디자인 일관성 부재**: 탭마다 다른 카드 스타일, 레이아웃 패턴

## Target Users

- **Primary**: Apple Watch 착용 30-50대 건강 관심자 — 아침에 컨디션 + 수면 + 체중 변화를 한 눈에
- **Secondary**: 운동인 — 회복 상태(수면+HRV)와 체성분 변화를 연결해서 트레이닝 조절
- **Key need**: "어제 잘 잤나? 몸은 어떤 방향으로 가고 있나?" 를 하나의 화면에서

## Success Criteria

- [ ] 4탭 → 3탭 구조 전환 완료 (Today / Train / Wellness)
- [ ] Wellness 탭: Single Scroll로 수면+체성분 정보 통합
- [ ] 3초 내 수면 품질 + 체성분 트렌드 파악 가능
- [ ] Oura의 미니멀 고급감 + Apple Health의 정보 밀도 + Bear의 따뜻한 여백
- [ ] 모든 탭에서 일관된 디자인 시스템 적용
- [ ] Dynamic Type 전 단계 지원
- [ ] iPad에서 정보 밀도 최적화

---

## 의사결정 요약

| 항목 | 결정 |
|------|------|
| 통합 탭 이름 | **Wellness** |
| 내부 구조 | **Single Scroll** (수면 → 체성분 섹션 연속) |
| UX 레퍼런스 | **Oura**(고급감) + **Apple Health**(정보밀도) + **WHOOP**(데이터 집약) + **Bear**(여백/감성) |
| 개편 범위 | **앱 전체 UX** (3탭 전체 + 디자인 시스템) |
| 탭바 구조 | **Today** / **Train** / **Wellness** (3탭) |
| 수면 섹션 | **압축 + 신규** (Score+Stage 합치고, 수면 부채/시간대 차트 추가) |
| Body 입력 | **현재 Form Sheet 유지** (toolbar + 버튼) |
| Body 히스토리 | **숨김** (상세 화면으로 이동, 탭에는 최신값+트렌드만) |

---

## 새로운 앱 구조

### 탭바 (3탭)

| Tab | Name | Icon | Purpose |
|-----|------|------|---------|
| 1 | **Today** | `heart.text.clipboard` | 오늘의 컨디션 점수 + 건강 신호 + 활동 요약 |
| 2 | **Train** | `flame` | 운동 기록 + 추천 + 근육 활동 |
| 3 | **Wellness** | `leaf.fill` | 수면 분석 + 체성분 추적 |

**이전 대비 변경점:**
- `Condition` → `Today` (더 직관적, 매일 확인하는 느낌)
- `Activity` → `Train` (운동 강조, 일상 활동은 Today로)
- `Sleep` + `Body` → `Wellness` (통합)

### Wellness 탭 Layout (Single Scroll)

```
ScrollView
├── [Loading] WellnessSkeletonView (.redacted shimmer)
├── [Empty] EmptyStateView + "HealthKit 권한 허용" 버튼
│
├── ── SECTION 1: Sleep ──
│   ├── SleepHeroCard (압축)
│   │   ├── Sleep Score (ring gauge, Oura 스타일)
│   │   ├── Total Duration (h m)
│   │   ├── Efficiency %
│   │   └── Stage Breakdown (horizontal stacked bar + 축약 범례)
│   │
│   ├── SleepTimelineCard (신규)
│   │   ├── 취침~기상 타임라인 (hypnogram 스타일)
│   │   └── 각 stage 터치 시 duration tooltip
│   │
│   └── SleepTrendCard
│       ├── 7일 바 차트 (현재 유지, 개선)
│       └── "Avg 7h 12m · Goal 8h" 요약 라인
│
├── ── SECTION DIVIDER ── (subtle, ~16pt spacing)
│
├── ── SECTION 2: Body ──
│   ├── BodySnapshotCard
│   │   ├── Weight (latest + ▲/▼ change vs 7d ago)
│   │   ├── Body Fat % (latest + change)
│   │   └── Muscle Mass (latest + change)
│   │
│   ├── WeightTrendChart (현재 유지, 개선)
│   │   ├── 90일 라인차트
│   │   └── 목표선 표시 (future)
│   │
│   └── "View All Records" NavigationLink → BodyHistoryDetailView
│
└── ── SECTION 3: Quick Actions ──
    └── "Add Body Record" 버튼 (Form Sheet 호출)
```

### Today 탭 변경점

**기존 Condition → Today 리네이밍 + 구조 개선:**
- `navigationTitle`: "Dailve" → "Today"
- Steps, Exercise 카드 유지 (Activity 섹션에서 이동하지 않음 — 이미 Dashboard에 있음)
- Sleep 메트릭 카드 → Wellness 탭 링크로 대체 (중복 제거)
- Weight 메트릭 카드 → Wellness 탭 링크로 대체 (중복 제거)

**새 구조:**
```
ScrollView
├── ConditionHeroView (유지)
├── ScoreContributorsView (유지)
├── "Health Signals" Section
│   ├── HRV card
│   ├── RHR card
│   └── BMI card (Weight/Body Fat은 Wellness로 이동)
├── "Activity" Section
│   ├── Steps card
│   └── Exercise card
├── "Wellness Snapshot" Section (신규)
│   ├── Sleep mini card (Score + Duration, 탭 → Wellness 탭)
│   └── Weight mini card (Latest + Change, 탭 → Wellness 탭)
└── Updated footer
```

### Train 탭 변경점

**기존 Activity → Train 리네이밍:**
- `navigationTitle`: "Activity" → "Train"
- 구조는 현재 유지 (이미 잘 설계됨)
- Today 섹션의 Exercise/Steps와 중복 허용 (탭별 맥락이 다름)

---

## 레퍼런스별 차용 패턴

### Oura Ring에서 가져올 것

| 패턴 | 적용 |
|------|------|
| **Score Ring Gauge** | Sleep Score를 원형 게이지로 (현재 텍스트만) |
| **Aurora 그라디언트** | 카드 배경에 부드러운 radial gradient |
| **"One Big Thing"** | Wellness 탭 상단에 가장 중요한 인사이트 1줄 |
| **3탭 구조** | Today / Train / Wellness |
| **컬러 코딩 상태** | Green/Yellow/Red 대신 DS.Color.scoreExcellent~Warning 활용 |

### Apple Health에서 가져올 것

| 패턴 | 적용 |
|------|------|
| **카드 그리드** | Today 탭의 메트릭 카드 2열 그리드 |
| **Pinned Metrics** | 사용자가 Today에 표시할 카드 선택 (future) |
| **정보 밀도** | 카드 내 값+변화+미니차트 3중 정보 |
| **편집 가능 레이아웃** | "Edit" 모드로 카드 순서/표시 변경 (future) |

### WHOOP에서 가져올 것

| 패턴 | 적용 |
|------|------|
| **데이터 집약적 카드** | BodySnapshotCard에 3개 값+변화 한꺼번에 |
| **Progressive Disclosure** | 탭에서는 요약, 상세는 NavigationLink |
| **기능적 컬러만** | 장식적 컬러 배제, 상태 표시에만 색상 사용 |
| **Dark ground** | (Optional) 다크모드 최적화 시 참고 |

### Bear에서 가져올 것

| 패턴 | 적용 |
|------|------|
| **여백** | 섹션 간 충분한 spacing (xl~xxl) |
| **따뜻한 미니멀** | 차갑지 않은 중성 톤, 둥근 모서리 |
| **타이포그래피 위계** | 명확한 3단계: heroScore / sectionTitle / body |
| **마찰 제거** | 불필요한 탭/스와이프 줄이기 (Single Scroll 결정의 근거) |

---

## 디자인 시스템 개선 방향

### 컬러

현재 `DS.Color`에 추가/조정 필요:
- `wellness` 계열 색상 추가 (Sleep과 Body를 아우르는 톤)
- `surface` 계열 확장 (카드 깊이 3단계: primary/secondary/tertiary)
- Aurora 그라디언트용 gradient stop 정의

### 카드 스타일 통일

현재 `StandardCard`, `InlineCard`, `GlassCard` 혼용 → 용도 명확화:
- **StandardCard**: 주요 정보 카드 (Score, Trend Chart)
- **InlineCard**: 보조 정보 (Error banner, Tip)
- **GlassCard**: Hero 요소 (점수 링, 스냅샷)

### Micro-interactions

| 인터랙션 | 스펙 |
|----------|------|
| 카드 프레스 | `.scaleEffect(0.97)` + `.sensoryFeedback(.soft)` |
| 섹션 전환 | `.transition(.opacity)` 200ms |
| Score ring fill | Overshoot 2-3% → settle (DS.Animation.slow) |
| 값 변화 | `.contentTransition(.numericText())` (이미 사용 중) |
| Pull to refresh | 네이티브 `.refreshable` (유지) |

### 타이포그래피

Bear 영감의 3단계 위계:
- **Hero**: `.largeTitle.rounded.bold` (점수 표시)
- **Section**: `.title3.semibold` (섹션 헤더)
- **Body**: system default (카드 내 텍스트)
- **Caption**: `.caption` + `.secondary` (보조 정보)

---

## Wellness 탭 상세 설계

### SleepHeroCard (압축)

```
┌─────────────────────────────────────────┐
│  ╭────╮                                 │
│  │ 87 │  Total: 7h 32m                 │
│  │ring│  Efficiency: 94%               │
│  ╰────╯                                 │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░▒▒▒▒▒▒▒▒▓▓░░        │
│  Deep 1h20  Core 3h45  REM 1h52  Awake 35│
└─────────────────────────────────────────┘
```

**변경점 (현재 대비):**
- Score를 원형 ring gauge로 (Oura 스타일) — 현재는 plain text
- Score + Duration + Efficiency + Stage를 **하나의 카드**에 합침 (현재 2개 카드)
- Stage bar + legend를 더 컴팩트하게

### SleepTimelineCard (신규)

```
┌─────────────────────────────────────────┐
│  11:30 PM ─────────────────── 7:02 AM   │
│  ████ ▓▓▓▓▓▓▓ ░░░░░ ▓▓▓▓▓ ████ ░░░ █ │
│  Deep  Core    REM   Core   Deep  REM   │
│  (hypnogram style timeline)             │
└─────────────────────────────────────────┘
```

**신규 추가 이유:**
- Oura/WHOOP 모두 수면 타임라인(hypnogram) 제공
- 사용자가 "언제" 깊은 수면을 했는지 직관적 파악
- HealthKit `HKCategorySample`에서 stage 시간대 데이터 획득 가능

### BodySnapshotCard

```
┌─────────────────────────────────────────┐
│  Weight        Body Fat       Muscle    │
│  72.3 kg       18.5%          35.1 kg   │
│  ▼ 0.4 (7d)   ▲ 0.2 (7d)    — (7d)    │
│                                         │
│  HealthKit · Feb 17, 2026              │
└─────────────────────────────────────────┘
```

**변경점:**
- 현재 `latestValuesCard`와 유사하지만 **7일 전 대비 변화량** 추가
- 변화 방향에 따라 DS.Color.positive/negative 사용
- 소스 표시 (HealthKit / Manual)

### Body History → 상세 화면

현재 탭에 있던 전체 히스토리 목록은 새로운 `BodyHistoryDetailView`로 이동:
- NavigationLink "View All Records" 로 진입
- 기존 `historySection` + context menu 그대로 이전
- 탭에서는 최신값 + 트렌드 차트만 노출

---

## 앱 전체 일관성 확보

### 각 탭 배경 그라디언트

```swift
// Today: HRV 컬러 기반 (현재 유지)
LinearGradient(colors: [DS.Color.hrv.opacity(0.03), .clear], ...)

// Train: Activity 컬러 기반 (현재 유지)
LinearGradient(colors: [DS.Color.activity.opacity(0.03), .clear], ...)

// Wellness: Sleep 컬러 기반 (신규)
LinearGradient(colors: [DS.Color.sleep.opacity(0.03), .clear], ...)
```

### 공통 패턴

모든 탭에 적용할 일관된 패턴:
1. **Loading**: `{Tab}SkeletonView` (`.redacted(reason: .placeholder)`)
2. **Empty**: `EmptyStateView` with action button
3. **Error**: `errorBanner()` (non-blocking) + retry
4. **Background**: subtle LinearGradient
5. **Pull to refresh**: `.refreshable`
6. **Section headers**: `DS.Typography.sectionTitle` + `maxWidth: .infinity, alignment: .leading`

---

## Edge Cases

| 케이스 | 처리 |
|--------|------|
| 수면 데이터 없음 + 체성분 데이터 있음 | Sleep 섹션 EmptyState (mini), Body 섹션 정상 표시 |
| 둘 다 없음 | 전체 EmptyStateView (HealthKit 권한 안내) |
| Historical sleep data | 기존 `.ultraThinMaterial` 배너 유지 |
| Body 레코드 1개뿐 (트렌드 차트 불가) | 차트 숨김, SnapshotCard만 표시 (현재와 동일) |
| iPad multitasking | `sizeClass` 기반 카드 너비 조정 |
| 매우 긴 수면 (12h+) | 타임라인 가로 스크롤 또는 축소 |
| 체성분 변화 없음 | "—" 표시 (dash), 변화 색상 없음 |

---

## Constraints

- **기술적**: iOS 26+, Swift 6, HealthKit 시뮬레이터 제한
- **아키텍처**: Domain 레이어 SwiftUI import 금지 유지
- **데이터**: Sleep hypnogram은 HealthKit `HKCategoryValueSleepAnalysis`에서 가능하나 시간대별 stage 분리 필요
- **성능**: Wellness 탭이 Sleep+Body 두 서비스 동시 호출 → `async let` 병렬 fetch 필수
- **SwiftData**: Body 레코드의 `@Query`는 Wellness 탭으로 이동
- **CloudKit**: `@Relationship` optional 규칙 유지

---

## Scope

### MVP (Must-have)

1. **탭 구조 변경**: 4탭 → 3탭 (Today / Train / Wellness)
2. **AppSection enum 수정**: `.dashboard` → `.today`, `.exercise` → `.train`, `.sleep` + `.body` → `.wellness`
3. **WellnessView 생성**: Single Scroll with Sleep + Body 섹션
4. **SleepHeroCard 통합**: Score + Stage를 하나의 카드로 압축
5. **BodySnapshotCard 개선**: 7일 변화량 추가
6. **Body 히스토리 분리**: `BodyHistoryDetailView`로 이동
7. **Today 탭 리네이밍**: "Condition" → "Today"
8. **Train 탭 리네이밍**: "Activity" → "Train"
9. **Wellness 배경 그라디언트**: Sleep 컬러 기반
10. **WellnessViewModel**: Sleep + Body 데이터 통합 fetch

### Nice-to-have (Future)

| 기능 | 설명 |
|------|------|
| **SleepTimelineCard** | Hypnogram 스타일 수면 타임라인 |
| **수면 부채 표시** | 7-14일 누적 수면 목표 대비 부족량 |
| **체중 목표선** | Weight 차트에 목표 체중 표시 |
| **수면-체성분 상관 인사이트** | "수면 7h+ 주간에 체중 -0.3kg 경향" |
| **Aurora 그라디언트 카드** | Oura 스타일 부드러운 카드 배경 |
| **Wellness Score** | 수면+체성분 종합 점수 |
| **Today 탭 Wellness Snapshot** | Sleep/Weight 미니 카드로 Wellness 탭 바로가기 |
| **카드 프레스 인터랙션** | .scaleEffect + haptic |
| **iPad Inspector 패턴** | 메트릭 상세를 trailing inspector로 |

---

## Open Questions

1. **Wellness 탭 아이콘**: `leaf.fill` vs `figure.mind.and.body` vs `sparkles` — 어느 것이 Sleep+Body를 가장 잘 표현?
2. **Sleep Score ring**: Oura처럼 원형 ring 안에 숫자? 아니면 현재 큰 텍스트 유지?
3. **Today 탭 Wellness Snapshot**: Today에서 Wellness로 바로가기 미니카드를 넣을지, 깔끔하게 분리할지?
4. **Body 입력 진입점**: Wellness 탭 하단 버튼 vs toolbar + 버튼 — Single Scroll에서 toolbar가 적절한지?
5. **다크모드**: WHOOP 스타일 dark-first 접근? 아니면 light/dark 동등 지원?

---

## Next Steps

- [ ] Open Questions 의사결정
- [ ] `/plan wellness-tab-app-ux-overhaul` 으로 구현 계획 생성
- [ ] MVP 항목을 Phase 1(탭 구조) / Phase 2(Wellness 내부) / Phase 3(디자인 통일) 로 분리

---

## Reference Research Summary

### Oura Ring (2025 Redesign)
- **3탭**: Today / Vitals / My Health
- Score ring gauge + Aurora gradient + Progressive disclosure
- "One Big Thing" 패턴: 가장 중요한 인사이트 하나를 상단에
- 5탭→3탭 축소로 인지부하 감소

### WHOOP
- 5개 핵심 영역 (Strain/Recovery/Sleep/Stress/Health) + Coach
- 컬러: 검정 배경 + Red accent (기능적 미니멀리즘)
- 3개 ring (Strain/Sleep/Recovery) 메인 화면
- Progressive disclosure: 표면 단순, 탭하면 깊이

### Apple Health (iOS 18)
- Summary 탭: Pinned metrics 카드 그리드
- 사용자 커스터마이즈 가능한 레이아웃
- Boxed grid로 인지부하 최소화
- 편집 모드로 표시 항목 선택

### Bear (Apple Design Award)
- 따뜻한 미니멀리즘, 커스텀 타이포그래피
- 여백을 통한 호흡감
- "마찰 제거"가 핵심 철학
- 프리미엄 느낌 = 빼기의 미학
