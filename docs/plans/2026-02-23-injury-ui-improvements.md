---
tags: [injury, ux, severity, localization, history-card]
date: 2026-02-23
category: plan
status: draft
source: docs/brainstorms/2026-02-23-injury-ui-improvements.md
---

# Plan: Injury UI 개선

## Summary

부상 입력/표시 UI 4가지 개선: Severity 세로 라디오 리스트, Severity 설명 추가, Location 한글 병기, History 카드 날짜 개선. 전체 Injury UI 7개 파일에 일관 적용.

## Affected Files

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `Presentation/Shared/Extensions/InjurySeverity+View.swift` | modify | `description`, `localizedDescription` 추가 |
| 2 | `Presentation/Shared/Extensions/BodyPart+View.swift` | modify | `bilingualDisplayName` 추가 (BodyPart + BodySide) |
| 3 | `Presentation/Injury/InjuryFormSheet.swift` | modify | Severity 세로 라디오, Body Part 한글 병기 |
| 4 | `Presentation/Injury/InjuryHistoryView.swift` | modify | injuryRowContent 날짜 행 + 한글 병기 + Detail 한글 병기 |
| 5 | `Presentation/Injury/InjuryCardView.swift` | modify | 날짜 표시 개선 + 한글 병기 |
| 6 | `Presentation/Injury/InjuryWarningBanner.swift` | modify | 부위명 한글 병기 |

## Implementation Steps

### Step 1: Extension 추가 (InjurySeverity+View, BodyPart+View)

**InjurySeverity+View.swift** — `description` + `localizedDescription` 추가:

```swift
var description: String {
    switch self {
    case .minor: "Can train with caution"
    case .moderate: "Avoid exercises for affected area"
    case .severe: "No exercises for affected area"
    }
}

var localizedDescription: String {
    switch self {
    case .minor: "주의하며 운동 가능"
    case .moderate: "해당 부위 운동 회피 권장"
    case .severe: "해당 부위 운동 금지"
    }
}
```

**BodyPart+View.swift** — `bilingualDisplayName` 추가:

```swift
extension BodyPart {
    var bilingualDisplayName: String {
        "\(displayName) (\(localizedDisplayName))"
    }
}

extension BodySide {
    var bilingualDisplayName: String {
        "\(displayName) (\(localizedDisplayName))"
    }
}
```

### Step 2: InjuryFormSheet — Severity 세로 라디오 리스트

현재 `.pickerStyle(.segmented)` → 세로 라디오 리스트로 교체.

Section("Severity") 내부:
- ForEach(InjurySeverity.allCases)
- 각 행: `Button` → 탭 시 selection 변경
- 행 구성: `[아이콘] [한글명 (영문)] [체크마크]` + 아래에 `[설명]`
- 선택된 항목: `.checkmark` 이미지 표시 또는 `Image(systemName: "checkmark")`

Body Part Picker 내부:
- `Text(part.displayName)` → `Text(part.bilingualDisplayName)`
- Side picker: `Text(side.displayName)` → `Text(side.bilingualDisplayName)`

### Step 3: InjuryHistoryView — injuryRowContent + Detail 개선

**injuryRowContent** 3행째에 날짜 행 추가:
- Active: `"2/15~"` 형태 (시작일만)
- Recovered: `"2/1 ~ 2/10"` (시작~종료)
- durationDays 표시 개선: Active `"{N}일째"`, Recovered `"({N}일)"`
- Body part: `bilingualDisplayName` 사용

**InjuryDetailView (embedded)**:
- summaryCard: `bilingualDisplayName` + severity `localizedDescription`

DateFormatter: 기존 InjuryCardView의 `Cache.dateFormatter` 패턴 재활용 (Correction #80).

### Step 4: InjuryCardView — 날짜 표시 + 한글 병기

- durationLabel 개선: History row와 동일한 날짜 형식 적용
- `record.bodyPart.displayName` → `record.bodyPart.bilingualDisplayName`
- severity badge: `record.severity.displayName` → 한글 우선 `localizedDisplayName`

### Step 5: InjuryWarningBanner — 한글 병기

- `conflict.injury.bodyPart.displayName` → `conflict.injury.bodyPart.bilingualDisplayName`

## Edge Cases

1. **긴 부위명**: "Hamstrings (햄스트링)" — 카드에서 자연스러운 truncation 확인
2. **0일 경과 Active**: "Today" 또는 "오늘" 표시
3. **Side 약어**: 한글 병기 시 Side는 약어(L/R) 유지하여 너비 절약

## Relevant Corrections

- #1, #20: Domain에 SwiftUI import 금지 → Extension에만 추가
- #36: rawValue UI 표시 금지 → displayName 사용
- #80: Formatter 캐싱 → static let
- #30: 데이터 종속 UI placeholder

## Risks

- **레이아웃 너비**: 한글 병기로 인한 텍스트 길이 증가 → lineLimit/truncation 확인 필요
- **Severity segmented → radio**: Form 내 세로 리스트가 기존 Form 스타일과 조화되는지 확인

## Test Strategy

- 테스트 면제: SwiftUI View body 변경만 (testing-required 규칙 참조)
- Extension 추가 (`description`, `bilingualDisplayName`)는 순수 computed property — 단순 문자열 반환이므로 별도 테스트 불필요
- 빌드 검증: `scripts/build-ios.sh`
