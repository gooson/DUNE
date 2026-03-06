---
tags: [whats-new, release, onboarding, localization, watch, settings]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: What's New 공간 (배포 공지 + 첫 진입 유도)

## Problem Statement

현재 앱은 Today, Activity, Wellness, Life, Apple Watch 연동까지 기능 폭이 넓지만, 사용자가 첫 배포 후 또는 업데이트 후 "무엇이 새로워졌는지" 한 번에 이해할 수 있는 공간이 없다.
또한 출시 공지에 활용할 수 있는 기능 설명과 스크린샷 자산이 앱 내부 구조와 분리되어 있어, 버전별 변경점을 누적 관리하고 재사용하기 어렵다.

필요한 것은 다음 조건을 모두 만족하는 `What's New` 공간이다.

- 최종 사용자가 보는 용도
- 첫 진입 시 자동 노출
- 스크린샷 + 기능 설명 중심
- 서버 없이 번들 데이터만으로 운영
- 다국어 지원
- Apple Watch 기능 포함
- 출시 직전 수동 편집 가능
- 기존 Settings 계열 디자인 톤과 자연스럽게 연결

## Target Users

- 첫 설치 직후 앱의 핵심 가치를 빠르게 파악해야 하는 사용자
- 업데이트 후 추가된 기능을 짧은 시간 안에 확인하고 싶은 기존 사용자
- iPhone과 Apple Watch를 함께 사용하며 연동 기능까지 이해하고 싶은 사용자
- 긴 공지문보다 시각적인 스크린샷과 짧은 설명을 선호하는 사용자

## Success Criteria

1. 첫 설치 또는 새 버전 업데이트 후 앱 진입 시 `What's New`가 자동으로 노출된다.
2. 3-5개 핵심 업데이트를 스크린샷과 짧은 설명으로 직관적으로 이해할 수 있다.
3. iPhone 기능과 Apple Watch 기능을 한 공간에서 구분감 있게 보여줄 수 있다.
4. 사용자가 `Settings > About`에서 언제든 다시 열 수 있다.
5. 서버 없이 앱 번들만으로 버전별 내용을 누적 관리할 수 있다.
6. `en / ko / ja` 다국어를 지원한다.
7. 출시 직전 텍스트/스크린샷 교체 작업이 단순해야 한다.

## Current Feature Inventory

### iPhone / iPad 주요 기능

- `Today`
  - Condition Score hero
  - Weather + coaching card
  - Insight cards
  - Pinned metrics
  - Notification hub
  - Settings 진입
- `Activity`
  - Training Readiness
  - Muscle recovery map
  - Weekly stats
  - Suggested workout
  - Training volume
  - Recent workouts
  - Personal records / achievement history
  - Consistency / exercise mix
- `Workout Logging`
  - Quick start
  - Exercise picker
  - Template workout / compound workout
  - Cardio session
  - Rest timer
  - Workout share card
  - HealthKit workout detail
- `Wellness`
  - Wellness Score hero
  - Physical / Active Indicators cards
  - Body composition 기록
  - Body history
  - Injury tracking
- `Life`
  - Habit tracking
  - Daily completion flow
  - Workout 기반 auto achievement
  - Reminder schedule

### Apple Watch 주요 기능

- Carousel home
  - Routine
  - Popular
  - Recent
  - Browse all exercises
- Workout flow
  - Workout preview
  - Set input
  - Rest timer
  - Session controls
  - Paging workout session
- Cardio flow
  - Live workout metrics
  - Heart-rate zone pages
- Summary / sync
  - Session summary
  - HealthKit write
  - iPhone sync
  - Recent exercise memory

## Proposed Approach

### 1. Entry Strategy

기본 진입 구조는 2단계로 구성한다.

1. 앱 첫 설치 또는 새 버전 업데이트 직후 `What's New`를 자동 표시
2. `Settings > About`에 `What's New` 재진입 포인트 제공

권장 동작:

- 자동 노출은 앱 루트가 안정적으로 뜬 뒤 sheet 또는 full-screen cover로 표시
- 같은 버전에서는 한 번만 자동 표시
- 사용자가 닫은 뒤에는 `About`에서 다시 확인 가능

이 방식은 "첫 진입 유도" 요구와 "다시 열 수 있는 안정적인 홈" 요구를 동시에 만족한다.

### 2. Information Architecture

`What's New` 화면 구조는 공지문이 아니라 "가벼운 제품 소개 허브"처럼 설계한다.

#### 현재 버전 섹션

- Hero
  - 버전명 또는 릴리스 테마
  - 이번 업데이트 핵심 한 줄 설명
- Highlights
  - 핵심 3-5개 카드
  - 각 카드 = 스크린샷 + 제목 + 1-2문장 설명
- Platform / Area grouping
  - Today
  - Activity
  - Wellness
  - Life
  - Apple Watch
- CTA
  - 관련 탭으로 이동
  - 또는 "앱에서 직접 확인해보기" 안내

#### 누적 히스토리 섹션

- 버전별 archive 리스트
- 이전 릴리스도 접어서 확인 가능
- "이번 버전"과 "이전 버전"의 위계를 분명히 유지

이 구조면 배포 공지에도 같은 내용을 재활용하기 쉽고, 앱 안에서도 버전 히스토리 역할을 함께 수행할 수 있다.

### 3. Content Model (No Server)

서버 없이 운영하려면 릴리스 내용을 앱 번들 안의 정적 데이터로 관리해야 한다.

권장 모델:

```swift
struct WhatsNewRelease: Identifiable, Hashable {
    let id: String              // ex) "1.0.0"
    let version: String
    let build: String?
    let isMajor: Bool
    let items: [WhatsNewItem]
}

struct WhatsNewItem: Identifiable, Hashable {
    let id: String
    let area: WhatsNewArea      // today, activity, wellness, life, watch
    let title: String
    let summary: String
    let screenshotAssetName: String?
    let supportedPlatforms: [WhatsNewPlatform]
    let deepLink: WhatsNewDestination?
}
```

저장 정책:

- `@AppStorage`로 마지막 확인 버전 저장
- 현재 앱 버전이 `lastSeenWhatsNewVersion`보다 새로우면 자동 표시
- 릴리스 데이터는 코드 또는 번들 리소스에 포함

### 4. Editing Workflow

출시 직전 편집이 쉬워야 하므로, 콘텐츠 소스는 지나치게 분산되면 안 된다.

권장 방식:

- 버전별 릴리스 엔트리를 한 파일에서 관리
- 스크린샷은 안정적인 asset name 규칙으로 등록
- 텍스트는 `.xcstrings` 기반으로 관리

편집 포인트:

- 제목/설명 교체
- 카드 순서 조정
- 강조 기능 추가/제거
- 스크린샷 asset 교체

즉, "개발 완료 후 마지막 순간에도 문구를 손보기 쉬운 구조"가 중요하다.

### 5. Localization Strategy

다국어 요구가 있으므로 이 공간도 기존 프로젝트 규칙을 그대로 따라야 한다.

- 텍스트는 `Localizable.xcstrings` 기반
- 사용자 대면 문구는 영어 원문을 key로 관리
- Watch 관련 설명도 iPhone 쪽 `What's New`에 함께 노출 가능
- 스크린샷은 텍스트 오버레이를 최소화해 locale 차이를 줄이는 것이 유리

주의:

- 스크린샷 안 텍스트가 길면 ko/ja에서 실제 UI와 어긋날 수 있음
- 그래서 MVP는 "텍스트가 적은 스크린샷 + 별도 설명 캡션" 조합이 가장 안전하다

### 6. Visual Direction

이 화면은 Notification hub처럼 정보 밀도가 높은 inbox가 아니라, Settings / About 계열의 차분한 제품 소개 화면이 더 적합하다.

권장 스타일:

- 기존 wave background 계열 유지
- 큰 이미지 카드 + 짧은 설명
- `iPhone`, `Apple Watch` 배지 또는 section label 제공
- 과도한 리스트형 UI보다 editorial card 레이아웃 우선

### 7. Recommended MVP User Flow

1. 사용자가 새 버전 앱 실행
2. 루트 로딩 이후 `What's New` 자동 표시
3. 핵심 카드 3-5개 확인
4. 닫기 또는 CTA 탭
5. 이후에는 `Settings > About > What's New`에서 재진입

이 흐름이 가장 단순하고, 출시 공지용 자산과도 동일한 서사를 유지할 수 있다.

## Constraints

### 기술적 제약

- 서버 없이 운영해야 하므로 모든 릴리스 콘텐츠는 앱 번들에 포함되어야 함
- 자동 표시 로직은 기존 onboarding, permission prompt, sheet 표시와 충돌하지 않도록 조정 필요
- Watch 기능을 포함하되, 실제 표시 공간은 우선 iPhone 앱 안에서 해결하는 것이 단순함
- 다국어 지원 시 텍스트뿐 아니라 스크린샷 전략도 같이 설계해야 함

### 운영 제약

- 버전이 쌓일수록 이미지 자산과 텍스트 유지보수 비용이 증가
- 화면이 자주 바뀌면 스크린샷이 빠르게 낡을 수 있음
- 출시 직전 수정이 가능해야 하므로 콘텐츠 구조가 지나치게 복잡하면 안 됨

## Edge Cases

- 첫 설치 사용자와 업데이트 사용자의 메시지 톤이 다를 수 있음
- 같은 버전에서 사용자가 `What's New`를 닫았다가 다시 보고 싶을 수 있음
- Apple Watch가 없는 사용자에게도 watch 기능이 노출될 수 있음
- HealthKit 권한이 없어 실제 기능 화면과 설명이 체감상 다를 수 있음
- locale 변경 후 기존에 본 버전이라도 다시 보여줄지 정책이 필요함
- UI가 변경되었는데 예전 스크린샷이 남아 있을 수 있음

## Scope

### MVP (Must-have)

- [ ] 첫 설치/업데이트 후 자동 표시되는 `What's New` 화면
- [ ] `Settings > About` 재진입 포인트
- [ ] 현재 버전용 highlights 3-5개
- [ ] 스크린샷 + 짧은 설명 카드 레이아웃
- [ ] `Today / Activity / Wellness / Life / Apple Watch` 기준 분류
- [ ] 버전별 정적 데이터 구조
- [ ] `en / ko / ja` 다국어 지원
- [ ] last seen version 저장

### Nice-to-have (Future)

- [ ] 이전 버전 archive를 탐색하는 version history
- [ ] 카드별 deep link
- [ ] "이번 버전에서 해볼 것" 같은 guided checklist
- [ ] 스크린샷 기반 step-by-step feature guide
- [ ] App Store / SNS용 릴리스 공지 텍스트를 같은 소스에서 파생 생성
- [ ] locale별 별도 스크린샷 세트
- [ ] Apple Watch 전용 상세 섹션 또는 전용 gallery

## Open Questions

1. 자동 표시 대상은 `첫 설치 + 업데이트` 모두인지, 아니면 `업데이트`만인지?
2. 사용자가 닫으면 같은 버전에서는 다시 자동 표시하지 않을지?
3. MVP에서 CTA는 탭 이동까지만 할지, 상세 화면 deep link까지 포함할지?
4. 스크린샷은 공통 이미지를 우선 쓸지, locale별 별도 이미지를 운영할지?

## Next Steps

- [ ] `/plan whats-new-space` 로 구현 계획 생성
- [ ] 진입 방식 확정: sheet vs full-screen cover
- [ ] 콘텐츠 소스 확정: Swift catalog vs bundled JSON
- [ ] MVP에 포함할 대표 카드 3-5개 선정
- [ ] 스크린샷 캡처 가이드 정의
