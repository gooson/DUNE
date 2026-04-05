---
tags: [ux, navigation, consistency, section-group, chevron]
date: 2026-04-05
category: plan
status: draft
---

# Plan: Section Navigation UX Consistency

## Goal

모든 탭 섹션의 상세 전환 UX를 SectionGroup 헤더 chevron 패턴으로 통일.

## Related Documents

- Brainstorm: `docs/brainstorms/2026-04-05-section-navigation-consistency.md`
- Solution (Activity nav): `docs/solutions/architecture/2026-02-23-activity-detail-navigation-pattern.md`
- Solution (Life SectionGroup): `docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md`
- Solution (Sleep SectionGroup): `docs/solutions/architecture/2026-03-29-sleep-detail-ux-sectiongroup-consistency.md`

## Approach

### Core Change: SectionGroup에 `showChevron` 파라미터 추가

SectionGroup 헤더에 선택적 chevron.right 아이콘을 표시. `infoAction`과 공존 가능.

```swift
struct SectionGroup<Content: View>: View {
    // ... existing params ...
    var showChevron: Bool = false  // NEW - backward compatible

    // header에서:
    HStack(spacing: DS.Spacing.xs) {
        // accent bar + icon + title

        if let infoAction { ... }

        if showChevron {
            if infoAction == nil { Spacer() }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
    }
}
```

### 각 탭 변경 전략

**패턴**: NavigationLink(value:)가 SectionGroup 전체를 감싸고, SectionGroup에 `showChevron: true` 전달.

```swift
// 통일 패턴
NavigationLink(value: Destination.xxx) {
    SectionGroup(title: "Title", icon: "icon", iconColor: color, showChevron: true) {
        CardContent()
    }
}
.buttonStyle(.plain)
```

## Affected Files

| File | Change |
|------|--------|
| `SectionGroup.swift` | `showChevron: Bool = false` 파라미터 추가 |
| `DashboardView.swift` | 히어로 카드 + 주요 카드에 SectionGroup + chevron 적용 |
| `ActivityView.swift` | 기존 SectionGroup에 `showChevron: true` 추가, MuscleMap/WeeklyStats 패턴 변경 |
| `WellnessView.swift` | 히어로 + "View All" → SectionGroup + chevron, Body History link card 제거 |
| `LifeView.swift` | Weekly Report 버튼 → SectionGroup + chevron, Heatmap 추가 |
| `Localizable.xcstrings` | 새 SectionGroup 타이틀 문자열 (en/ko/ja) |

## Implementation Steps

### Step 1: SectionGroup 컴포넌트 확장

- `showChevron: Bool = false` 파라미터 추가
- `infoAction`이 있으면 info 버튼 뒤에 chevron 배치
- `infoAction`이 없으면 Spacer() + chevron
- 기존 호출부는 default false로 영향 없음

### Step 2: Activity 탭 (기존 패턴 강화)

이미 SectionGroup + NavigationLink 패턴을 사용하는 섹션에 `showChevron: true` 추가:
- Injury Risk, Personal Records, Consistency, Exercise Mix, Weekly Report → showChevron: true
- Training Readiness Hero → SectionGroup 래핑 + showChevron: true
- Muscle Map → 하단 "View Details" 제거, SectionGroup showChevron: true
- Weekly Stats → SectionGroup 래핑 + showChevron: true
- Training Volume → NavigationLink 연결 + showChevron: true (뷰 이미 존재)

### Step 3: Dashboard 탭

- Condition Hero → SectionGroup("Condition", ..., showChevron: true) 래핑
- Cumulative Stress → SectionGroup("Cumulative Stress", ..., showChevron: true) 래핑
- Weather Card → SectionGroup("Weather", ..., showChevron: true) 래핑
- Recovery & Sleep → SectionGroup("Recovery & Sleep", ..., showChevron: true) 래핑, 하단 버튼 제거
- Today Brief → Briefing 부분 SectionGroup 래핑 + 하단 "View Details" 제거
- Daily Digest → SectionGroup 래핑 + showChevron
- Workout Recommendation → SectionGroup 래핑 + showChevron

### Step 4: Wellness 탭

- Wellness Hero → SectionGroup("Wellness Score", ..., showChevron: true) 래핑
- Sleep Prediction → SectionGroup("Sleep Prediction", ..., showChevron: true) 래핑
- Body History → 하단 link card 제거, SectionGroup + showChevron으로 변경
- Injury History → "View All" 제거, SectionGroup + showChevron
- Posture History → "View All" 제거, SectionGroup + showChevron

### Step 5: Life 탭

- Weekly Report → 독립 버튼 제거, SectionGroup + showChevron으로 변경
- Habit Heatmap → SectionGroup + showChevron 래핑

### Step 6: 번역 추가

새 SectionGroup 타이틀로 사용되는 문자열을 xcstrings에 en/ko/ja 등록.

### Step 7: 테스트

- 기존 DUNETests 실행하여 regression 확인
- 빌드 검증

## Test Strategy

- 유닛 테스트: SectionGroup의 showChevron 파라미터가 뷰 계층에 반영되는지 확인 (기존 테스트 있으면 확장)
- 빌드 테스트: `scripts/build-ios.sh`
- 회귀 테스트: 기존 네비게이션 동작이 깨지지 않는지 확인

## Risks & Edge Cases

1. **히어로 카드 이중 배경**: SectionGroup의 material background + 히어로 카드 자체 배경이 겹침 → 히어로 카드 내부 배경을 제거하거나 SectionGroup 배경을 투명하게 처리 필요
2. **NavigationLink 중첩**: SectionGroup 외부에 NavigationLink, 내부 카드에도 NavigationLink가 있으면 충돌 → 내부 NavigationLink 제거 필요
3. **infoAction + showChevron 공존**: 일부 섹션은 info 버튼과 chevron이 동시에 필요 → 레이아웃 확인
4. **iPad 레이아웃**: SectionGroup이 2열 배치될 때 chevron 위치 확인
5. **번역 누락**: 새 SectionGroup 타이틀에 대한 3개 언어 번역 필수

## Scope Decision

- 메트릭 그리드(개별 카드 컬렉션), 운동 리스트(개별 row) 등 개별 아이템 네비게이션은 현행 유지
- Sheet로 열리는 항목(Template Nudge, RPE Help 등)은 chevron 미적용
- Smart Insights는 개별 카드이므로 현행 유지
