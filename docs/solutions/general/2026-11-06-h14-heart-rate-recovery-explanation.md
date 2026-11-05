---
tags: [swiftui, heart-rate-recovery, info-sheet, dynamic-type, accessibility, hit-target]
category: general
date: 2026-11-06
status: done
severity: important
related_files: [DUNE/Presentation/Shared/Extensions/HeartRateRecovery+View.swift, DUNEUITests/Full/ActivityExerciseRegressionTests.swift]
related_solutions:
  - docs/solutions/general/2026-11-06-h12-sleep-debt-explanation.md
  - docs/solutions/general/2026-11-06-h13-wake-analysis-explanation.md
---

# Solution: 큰 글씨에서도 읽고 닫을 수 있는 심박수 회복 설명

## Problem

### Symptoms

기존 HRR₁ 시트에서는 Definition, How It's Measured, Rating Guide의 경계가 약했다. 첫 재설계 iPhone 캡처에서 시트가 처음 열린 순간 Close의 AX 프레임은 42.4pt로 44pt 기준보다 작았다. 섹션 헤더에 붙은 식별자로 `StaticText`를 찾던 첫 UI 검사도 같은 식별자를 가진 이미지가 선택되어 실패했다.

### Root Cause

긴 제목, 아이콘, Close가 한 가로줄의 폭을 나눠 써야 했고, medium 시트 표시 중 원래 44pt Close 프레임이 축소되었다. 복합 헤더의 AX 자식 타입을 확인하지 않고 텍스트 리프로 가정했다.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `HeartRateRecovery+View.swift` | 설명 두 항목과 Rating Guide를 분리된 카드로 배치하고 본문에 자연 높이를 준다. MAX에서는 제목을 아이콘·Close 아래 전체 폭에 둔다. | 원래 문장을 줄임 없이 읽고 스크롤할 수 있게 한다. |
| Same | Close 소스 프레임을 48×48pt로 늘리고 섹션 헤더를 하나의 식별된 AX 요소로 결합한다. | 첫 표시 시 hit target과 헤더 선택을 안정화한다. |
| `ActivityExerciseRegressionTests.swift` | 정확한 헤더 식별자, 첫 화면과 MAX의 Close 프레임, 하단 가이드, 닫기와 복귀를 확인한다. | 실제 AX 타입과 조작 가능 범위를 검증한다. |

기존 HRR₁ 뜻과 측정 설명, Good `> 20 bpm`·Normal `12–20 bpm`·Low `< 12 bpm`, 색상 점, detent 및 계산은 그대로다.

### Key Code

```swift
InfoSheetHelpers.SectionHeader(icon: icon, title: title)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier)
```

## Prevention

- [ ] 복합 SwiftUI 헤더의 실제 AX 노드 타입과 label을 확인한 뒤 selector를 정한다.
- [ ] 확장 후뿐 아니라 medium 시트의 첫 표시 프레임에서 Close 크기를 잰다.
- [ ] MAX에서 마지막 가이드 행, 원래 수치·색상 점, 닫기 후 복귀를 확인한다.

## Lessons Learned

소스 프레임 44pt만으로 첫 표시 AX target 44pt가 보장되지 않았다. 48pt 소스 컨트롤은 새 iPhone 캡처에서 처음 46.3×46.3pt, 확장 후 48×48pt였다. MAX의 세로 헤더는 제목을 온전히 보여주면서 설명 순서를 유지했다.

## Validation

H14의 서로 다른 5개 메서드·프로필 조합(iPhone·iPad·Duo 접힘·Duo 펼침 일반, Duo 접힘 MAX)이 선택 SDK와 독립 PNG/AX 리뷰를 통과했다. 원래 세 범위와 Close·복귀도 해당 캡처에서 확인했다. App 파일은 최종 Batch02 검증 중 바뀌지 않았다. 실제 디자인맵의 해당 네 기본 프로필 행은 이 발행에서 갱신한다. PR 상태는 별도 기록을 따른다. Dark, 실기기, VoiceOver 순회, 전체 테스트는 주장하지 않는다.

## Publication evidence

[H14 paired native PNG/AX and method provenance](../../design/full-redesign-map/review/h14-heart-rate-recovery-explanation-native-2026-11-06/index.html) document the selected passing SDK methods and independent visual review. The scoped actual-map primary rows are published. This does not claim full CI or PR merge.
