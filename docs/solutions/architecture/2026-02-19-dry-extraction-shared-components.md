---
tags: [dry, duplication, shared-components, extension, changebadge, formatting, swift]
category: architecture
date: 2026-02-19
severity: important
related_files:
  - Dailve/Presentation/Shared/Components/ChangeBadge.swift
  - Dailve/Presentation/Shared/Extensions/TimeInterval+Formatting.swift
  - Dailve/Presentation/Shared/Extensions/ExerciseRecord+Volume.swift
related_solutions:
  - architecture/2026-02-16-review-triage-dry-extraction-patterns.md
---

# Solution: DRY Extraction — Shared Components & Extensions

## Problem

### Symptoms

- 6관점 리뷰에서 P1(2건) + P2(2건) 중복 코드 지적
- 동일 로직이 3~4곳에 복사-붙여넣기로 존재
- 한 곳 수정 시 나머지를 잊으면 불일치 발생

### Root Cause

빠른 기능 개발 중 "일단 동작하게" 하면서 private helper로 각 파일에 동일 로직을 넣음.
기능 완성 후 리팩토링 단계 없이 다음 기능으로 이동.

## Solution

3개의 공유 유틸리티를 추출하여 중복 제거. 순 감소 39줄 (-168, +129).

### Changes Made

| Extraction | From (N곳) | To | Lines Saved |
|-----------|-----------|-----|------------|
| `ChangeBadge` View | 3곳 (PeriodComparison, Detail, ExerciseTypeDetail) | `Shared/Components/ChangeBadge.swift` | ~40줄 |
| `TimeInterval.formattedDuration()` | 4곳 (3 Views + 1 Row) | `Shared/Extensions/TimeInterval+Formatting.swift` | ~30줄 |
| `ExerciseRecord.totalVolume` | 2곳 (2 ViewModels) | `Shared/Extensions/ExerciseRecord+Volume.swift` | ~20줄 |

### Key Code

**ChangeBadge** — 변경 퍼센트 표시 공통 컴포넌트:
```swift
struct ChangeBadge: View {
    let change: Double?
    var showNoData: Bool = false
    // arrow.up.right / arrow.down.right + percentage
}
```

**TimeInterval.formattedDuration()** — 시간 포맷팅:
```swift
extension TimeInterval {
    func formattedDuration() -> String {
        let hours = self / 3600
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return String(format: "%.0fm", self / 60)
    }
}
```

**ExerciseRecord.totalVolume** — 세트 볼륨 합산:
```swift
extension ExerciseRecord {
    var totalVolume: Double {
        (sets ?? []).reduce(0.0) { total, set in
            guard set.isCompleted else { return total }
            // weight × reps, with 0/nil guards
        }
    }
}
```

### Extraction Decision Matrix

| 중복 수 | 복잡도 | 추출 여부 | 근거 |
|---------|--------|----------|------|
| 2+ | 높음 (10줄+, 비즈니스 로직) | 즉시 추출 | Correction #64 |
| 3+ | 낮음 (단순 헬퍼) | 즉시 추출 | Correction #37 |
| 2 | 낮음 (1-3줄) | 허용 | 추상화 비용 > 중복 비용 |

### File Placement Rules

| 유형 | 위치 | 예시 |
|-----|------|------|
| 공통 View 컴포넌트 | `Shared/Components/` | `ChangeBadge.swift` |
| Type Extension | `Shared/Extensions/{Type}+{Purpose}.swift` | `TimeInterval+Formatting.swift` |
| Domain Model Extension | `Shared/Extensions/{Model}+{Purpose}.swift` | `ExerciseRecord+Volume.swift` |

## Prevention

### Checklist Addition

- [ ] 새 기능에 private helper 추가 시, 기존 `Shared/` 에 동일 로직이 있는지 검색
- [ ] 리뷰 시 동일 함수명 / 동일 로직 패턴이 2곳 이상 존재하면 추출 후보로 표시

### Rule Addition

기존 규칙 #37, #64 의 적용 사례로 문서화. 추가 규칙 불필요.

## Lessons Learned

- 빠른 개발 시에도 `Shared/` 디렉토리를 먼저 검색하는 습관 필요
- "동작하면 OK" 이후 리팩토링 단계를 `/review` 가 강제해줌 — Compound Loop의 가치
- 추출 후 원본 파일의 private 함수 삭제를 잊지 않도록 — dead code 즉시 삭제 (Correction #55)
- xcodegen 프로젝트에서 새 파일 추가 시 `xcodegen generate` 필수
