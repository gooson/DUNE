---
tags: [sleep, sectiongroup, ux-consistency, subtitle, metric-detail, localization]
category: architecture
date: 2026-03-29
severity: minor
related_files:
  - DUNE/Presentation/Shared/Components/SectionGroup.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailView.swift
  - Shared/Resources/Localizable.xcstrings
  - DUNEUITests/Smoke/SleepDetailSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md
  - docs/solutions/architecture/2026-02-21-wellness-section-split-patterns.md
---

# Solution: 수면 상세 화면 SectionGroup 그룹핑 + 섹션 설명 추가

## Problem

### Symptoms

- MetricDetailView의 수면 카드 11개가 flat하게 나열되어 정보 계층 구조 부재
- Activity/Wellness 탭은 SectionGroup으로 카드를 그룹핑하지만 수면 상세는 미사용 → UX 일관성 저하
- 각 카드가 무엇을 보여주는지 설명이 없어 신규 사용자가 데이터 맥락 파악 어려움

### Root Cause

- 수면 상세가 기능 추가 위주로 확장되면서 공통 UI 패턴(SectionGroup)으로 재정렬되지 않음
- SectionGroup 컴포넌트에 subtitle 파라미터가 없어 섹션 설명 지원 불가

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SectionGroup.swift` | `subtitle: LocalizedStringKey? = nil` 파라미터 추가 | 섹션 설명 지원 (기존 호출부 호환) |
| `MetricDetailView.swift` | 11개 수면 카드를 4개 SectionGroup으로 재구성 | UX 일관성 + 정보 계층화 |
| `Localizable.xcstrings` | 7개 새 문자열 en/ko/ja 등록 | 다국어 지원 |
| `SleepDetailSmokeTests.swift` | 4개 섹션 존재 확인 UI 테스트 | 레이아웃 회귀 방지 |

### Key Decisions

1. **subtitle padding**: 초기 구현에서 `.padding(.leading, DS.Spacing.xs)`를 추가했으나, 외부 VStack의 `.padding(.horizontal, DS.Spacing.xs)`와 중복되어 제거. subtitle은 accent bar 시작 위치에 정렬됨.

2. **4그룹 구조**: Sleep Quality / Sleep Patterns / Nocturnal Health / External Factors
   - BreathingDisturbanceCard를 Nocturnal Health에 배치 (호흡 장애는 야간 건강 지표에 더 적합)
   - External Factors는 2개 카드만 포함하지만 논리적 분류상 별도 그룹이 적절

3. **설명 문구 톤**: 기능 설명(정보적) 톤. 각 섹션별 다른 동사 사용 (Analyzes/Tracks/Monitors/Explores)

## Prevention

### Checklist

- [ ] MetricDetailView에 새 수면 카드 추가 시 적절한 SectionGroup에 배치
- [ ] SectionGroup subtitle 추가 시 외부 padding과 중복되지 않는지 확인
- [ ] 다른 탭(Activity, Wellness)에도 subtitle을 확장할 때 동일 패턴 참조

## Lessons Learned

1. **SectionGroup subtitle 추가 시 padding 주의**: SectionGroup의 header VStack에 `.padding(.horizontal)`이 이미 적용되어 있으므로, subtitle에 별도 leading padding을 추가하면 이중 들여쓰기가 됨
2. **설명 문구는 카드와 매칭 필수**: "sleep score"처럼 섹션 내 카드와 직접 대응하지 않는 용어를 사용하면 혼란 유발
3. **Life 탭 UX 일관성 패턴 재사용**: 이전 Life 탭 SectionGroup 정렬 경험이 수면 화면에도 동일하게 적용됨
