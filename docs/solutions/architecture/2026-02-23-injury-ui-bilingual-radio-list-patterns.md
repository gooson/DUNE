---
tags: [swiftui, injury, bilingual, radio-list, form-ui, dry, enum-extension, bilingualDisplayName]
category: architecture
date: 2026-02-23
severity: important
related_files:
  - Dailve/Presentation/Injury/InjuryFormSheet.swift
  - Dailve/Presentation/Injury/InjuryHistoryView.swift
  - Dailve/Presentation/Injury/InjuryCardView.swift
  - Dailve/Presentation/Injury/InjuryWarningBanner.swift
  - Dailve/Presentation/Shared/Extensions/InjurySeverity+View.swift
  - Dailve/Presentation/Shared/Extensions/BodyPart+View.swift
  - Dailve/Presentation/Shared/Extensions/InjuryRecord+View.swift
related_solutions:
  - docs/solutions/architecture/2026-02-21-wellness-section-split-patterns.md
---

# Solution: Injury UI Bilingual Display + Severity Radio List 패턴

## Problem

### Symptoms

1. Severity Picker가 `.pickerStyle(.segmented)`로 구현되어 아이콘과 텍스트가 좁은 공간에 압축됨
2. Severity 항목의 의미(운동 가능/회피/금지)가 표시되지 않아 사용자가 선택 근거를 알 수 없음
3. Body part, body side 이름이 영문 또는 한글 단일 언어로만 표시되어 한글 사용자에게 불편
4. Injury history 카드에 날짜 범위(시작~종료)와 경과일이 동시에 표시되지 않음
5. 날짜/경과일 포맷 로직이 `InjuryCardView`와 `InjuryHistoryView`에 각각 중복 구현

### Root Cause

- Severity 선택 UI: `Picker(.segmented)`는 3개 이상 항목에서 공간 부족. 부가 정보(설명) 표시 불가
- 한국어 병기 부재: `displayName`(영문)과 `localizedDisplayName`(한글)이 별도 존재하나 조합 패턴이 없었음
- DRY 위반: `durationLabel`, `dateRangeLabel`, `DateFormatter` 캐시가 View별로 독립 구현

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `InjurySeverity+View.swift` | `bilingualDisplayName`, `localizedSeverityDescription` 추가 | 단일 소스로 한글 병기 + 설명 제공 |
| `BodyPart+View.swift` | `BodyPart.bilingualDisplayName`, `BodySide.bilingualDisplayName` 추가 | 영문(한글) 병기 패턴 통일 |
| `InjuryRecord+View.swift` | NEW — `durationLabel`, `dateRangeLabel` + `DateCache` | P1 DRY 수정: 공유 날짜/경과일 포맷 |
| `InjuryFormSheet.swift` | Severity `.segmented` → 세로 라디오 리스트 | 아이콘+이름+설명+체크마크 한 행에 표시 |
| `InjuryHistoryView.swift` | 공유 프로퍼티 사용, 중복 함수/캐시 제거 | DRY 적용 |
| `InjuryCardView.swift` | 공유 프로퍼티 사용, 중복 computed var/캐시 제거 | DRY 적용 |
| `InjuryWarningBanner.swift` | `bilingualDisplayName` 사용 | 병기 통일 |

### Key Code

**1. bilingualDisplayName 패턴 (enum extension)**

```swift
// InjurySeverity+View.swift
var bilingualDisplayName: String {
    switch self {
    case .minor: "경미 (Minor)"
    case .moderate: "보통 (Moderate)"
    case .severe: "심각 (Severe)"
    }
}

// BodyPart+View.swift — displayName/localizedDisplayName 조합
extension BodyPart {
    var bilingualDisplayName: String {
        "\(displayName) (\(localizedDisplayName))"
    }
}
```

- `InjurySeverity`는 단일 switch (영문과 한글 순서가 역전되므로 문자열 보간 대신 리터럴 사용)
- `BodyPart`, `BodySide`는 기존 `displayName` + `localizedDisplayName` 조합으로 유지보수 부담 최소화

**2. 세로 라디오 리스트 (Form Section 내)**

```swift
Section("Severity") {
    ForEach(InjurySeverity.allCases, id: \.self) { severity in
        Button {
            viewModel.selectedSeverity = severity
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: severity.iconName)
                    .font(.title3)
                    .foregroundStyle(severity.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(severity.bilingualDisplayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(severity.localizedSeverityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.selectedSeverity == severity {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(severity.color)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- `.buttonStyle(.plain)` 필수 — Form 내 Button의 기본 스타일이 텍스트 색상을 변경함
- `.contentShape(Rectangle())` — 빈 공간 탭도 반응하도록

**3. 공유 날짜/경과일 포맷 (InjuryRecord+View.swift)**

```swift
extension InjuryRecord {
    private enum DateCache {
        static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()
    }

    var durationLabel: String {
        let days = durationDays
        if isActive { return days == 0 ? "Today" : "\(days)일째" }
        else { return "\(days)일" }
    }

    var dateRangeLabel: String {
        let start = DateCache.formatter.string(from: startDate)
        if isActive { return "\(start)~" }
        let end = endDate.map { DateCache.formatter.string(from: $0) } ?? ""
        return "\(start) ~ \(end)"
    }
}
```

- `DateFormatter`는 `static let`으로 캐싱 (Correction #80)
- `private enum DateCache` 패턴으로 네임스페이스 격리

## Prevention

### Checklist Addition

- [ ] 새 enum에 UI 표시가 필요하면 `bilingualDisplayName` computed property 추가 여부 확인
- [ ] 2곳 이상 동일 날짜/문자열 포맷 로직이 있으면 `{Model}+View.swift`로 추출 (Correction #64)
- [ ] Form 내 커스텀 선택 UI 사용 시 `.buttonStyle(.plain)` + `.contentShape(Rectangle())` 확인

### Naming Convention

| 프로퍼티명 | 용도 | 예시 |
|-----------|------|------|
| `displayName` | 영문 단일 | "Shoulder" |
| `localizedDisplayName` | 한글 단일 | "어깨" |
| `bilingualDisplayName` | 병기 | "Shoulder (어깨)" 또는 "경미 (Minor)" |
| `localizedSeverityDescription` | 한글 설명문 | "주의하며 운동 가능" |

## Lessons Learned

1. **Segmented Picker의 한계**: 3개 항목까지는 적합하나, 부가 정보(설명, 아이콘) 표시가 필요하면 세로 라디오 리스트가 UX상 우월. Form Section 내 `ForEach` + `Button` 패턴으로 구현
2. **bilingual 패턴 통일**: `bilingualDisplayName`이라는 프로퍼티명을 BodyPart, BodySide, InjurySeverity 3개 타입에 일관 적용하여 call site에서 예측 가능한 API 제공
3. **DRY는 복잡도 높은 로직일수록 빠르게 추출**: DateFormatter 캐시 + 조건부 포맷팅 로직은 2곳 중복에서도 즉시 추출 (Correction #64 적용)
4. **리뷰 → 수정 → 빌드 1회 검증**: 리뷰 결과를 파일별로 batch 적용 후 최종 빌드 1회로 검증 (Correction #27)
