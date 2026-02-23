---
tags: [injury, ux, severity, localization, history-card]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Injury UI 개선

## Problem Statement

부상 정보 입력 및 히스토리 표시의 UX 문제:

1. **Severity 선택 UI 불량**: `.pickerStyle(.segmented)` + `HStack { Image + Text }`는 세그먼트 컨트롤이 커스텀 뷰를 제대로 렌더링하지 않아 아이콘과 레이블이 분리되어 보임
2. **Severity 의미 불명확**: "Minor", "Moderate", "Severe" 텍스트만으로는 각 레벨이 운동에 미치는 영향을 사용자가 판단하기 어려움
3. **Location 영어 전용**: `localizedDisplayName`(한글)이 Extension에 구현되어 있으나 UI에서 사용하지 않음. 한국어 사용자에게 "Hamstrings", "Quadriceps" 등은 직관적이지 않음
4. **History 카드 정보 부족**: 시작 날짜, 종료일이 미표시. `{N}d` 형태의 경과일만 표시되어 언제 발생한 부상인지 파악 어려움

## Target Users

- 한국어 사용자 (주요 타겟)
- 운동 중 부상을 기록하고 관리하는 사용자
- 부상 이력을 참고하여 운동 계획을 세우는 사용자

## Success Criteria

1. Severity 선택 시 아이콘+이름+설명이 한 눈에 보이고, 탭 한 번으로 선택 가능
2. 각 severity가 운동에 미치는 영향을 선택 시점에 즉시 이해 가능
3. 부위명을 영문+한글로 동시 표시하여 직관성 향상
4. History 카드에서 부상 기간(시작~종료)과 경과일을 즉시 파악 가능

## Decisions

### 1. Severity UI → 세로 라디오 리스트

**현재**: `Picker(.segmented)` — 아이콘 렌더링 불량, 설명 없음
**변경**: Form Section 내 세로 리스트, 각 행에 아이콘+이름+설명+체크마크

```
┌─────────────────────────────────────┐
│ ⚠️  경미 (Minor)              ✓    │
│    주의하며 운동 가능                │
├─────────────────────────────────────┤
│ ⚠  보통 (Moderate)                 │
│    해당 부위 운동 회피 권장          │
├─────────────────────────────────────┤
│ ⛔ 심각 (Severe)                    │
│    해당 부위 운동 금지               │
└─────────────────────────────────────┘
```

구현 요소:
- `InjurySeverity+View`에 `description` computed property 추가
- 선택 시 severity `color` 테두리 또는 배경 강조
- `Image(systemName: severity.iconName) + severity.localizedDisplayName + (severity.displayName)`

### 2. Severity 설명 추가

`InjurySeverity+View.swift`에 추가:

| Severity | 설명 (한글) | 설명 (영문) |
|----------|------------|------------|
| minor | 주의하며 운동 가능 | Can train with caution |
| moderate | 해당 부위 운동 회피 권장 | Avoid exercises for affected area |
| severe | 해당 부위 운동 금지 | No exercises for affected area |

### 3. Location 한글 병기 → "영문 (한글)"

**형식**: `"Shoulder (어깨)"`, `"Knee (무릎)"`

적용 위치 (전체 Injury UI):
- InjuryFormSheet: Body Part Picker
- InjuryHistoryView: injuryRowContent
- InjuryDetailView: summaryCard
- InjuryCardView: body
- InjuryWarningBanner: conflict 표시

구현:
- `BodyPart+View`에 `var bilingualDisplayName: String` 추가
  - `"\(displayName) (\(localizedDisplayName))"`
- `BodySide+View`에도 동일 패턴
  - `"\(displayName) (\(localizedDisplayName))"` → "Left (왼쪽)"

### 4. History 카드 날짜 정보 개선

**현재**: `[severity icon] [부위명(side)] | [severity badge] · [Nd]`
**변경**: 날짜 행을 명시적으로 추가

Active 상태:
```
[⚠️ icon] Shoulder (어깨) (L)         [Active]
          Moderate (보통) · 9일째
          2/15~
```

Recovered 상태:
```
[⚠️ icon] Knee (무릎) (R)
          Minor (경미) · 10일
          2/1 ~ 2/10
```

구현:
- `injuryRowContent` 3행째에 날짜 행 추가
- Active: `"{startDate}~"` + `"{N}일째"`
- Recovered: `"{startDate} ~ {endDate}"` + `"({N}일)"`
- InjuryCardView에도 동일 패턴 적용

## Constraints

- **레이어 경계**: severity description, bilingualDisplayName은 Presentation Extension에 추가 (Domain 금지 — Correction #1, #20)
- **rawValue UI 표시 금지**: Correction #36 — `displayName` 사용
- **Formatter 캐싱**: Correction #80 — DateFormatter는 `static let` 캐싱
- **레이아웃 안정성**: Correction #30 — 데이터 종속 UI는 항상 렌더 + placeholder

## Edge Cases

1. **긴 부위명**: "Hamstrings (햄스트링)" — 가장 긴 조합. 카드에서 truncation 필요
2. **양쪽(Both) 표시**: "Shoulder (어깨) (Both (양쪽))" — 너무 길어짐. Side는 약어 유지 또는 `(LR)` 패턴
3. **날짜 포맷 locale**: 한국어 환경에서 `2/15` vs `2월 15일` — DateFormatter의 `.short` 스타일 활용
4. **0일 경과**: Active + 오늘 시작 → "오늘" 또는 "Today" 표시

## Scope

### MVP (Must-have)
- [x] Severity 세로 라디오 리스트 (InjuryFormSheet)
- [x] Severity 설명 텍스트 추가 (InjurySeverity+View)
- [x] Location 한글 병기 — 전체 Injury UI (BodyPart+View, 모든 View)
- [x] History 카드 날짜 정보 (InjuryHistoryView, InjuryCardView)
- [x] Detail View 한글 병기 + severity 설명 적용

### Nice-to-have (Future)
- Side도 한글 병기 ("Left (왼쪽)") — 현재는 약어(L/R) 유지
- History 카드에 부상 부위 아이콘(body map mini) 추가
- Severity 선택 시 haptic feedback

## Affected Files

| File | 변경 내용 |
|------|----------|
| `Presentation/Shared/Extensions/InjurySeverity+View.swift` | `description`, `localizedDescription` 추가 |
| `Presentation/Shared/Extensions/BodyPart+View.swift` | `bilingualDisplayName` 추가 |
| `Presentation/Injury/InjuryFormSheet.swift` | Severity 세로 라디오 리스트, Body Part 한글 병기 |
| `Presentation/Injury/InjuryHistoryView.swift` | injuryRowContent 날짜 행 추가, 한글 병기 |
| `Presentation/Injury/InjuryCardView.swift` | 날짜 표시 개선, 한글 병기 |
| `Presentation/Injury/InjuryDetailView.swift` (embedded) | summaryCard 한글 병기, severity 설명 |
| `Presentation/Injury/InjuryWarningBanner.swift` | 부위명 한글 병기 |

## Open Questions

1. Side 약어를 한글로도 표시할지? (현재 "L", "R" → "왼", "오" 또는 유지)
2. Severity 라디오 리스트에서 한글/영문 병기할지, 한글 우선할지? → 결정: `"경미 (Minor)"` 한글 우선

## Next Steps

- `/plan` 으로 구현 계획 생성
- 변경 파일 7개, Fidelity Level: **F2** (명확한 범위, 여러 파일)
