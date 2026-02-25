---
tags: [swiftui, pull-to-refresh, ui-feedback, testing, agent-doc-sync]
category: general
date: 2026-02-26
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Exercise/ExerciseView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNETests/WaveShapeTests.swift
  - .claude/skills/design-system/SKILL.md
related_solutions: []
---

# Solution: Review Fixes for Refresh Feedback and Skill Doc Sync

## Problem

다관점 리뷰에서 기능 회귀와 문서-코드 드리프트가 함께 발견되었습니다.

### Symptoms

- 빈 상태 화면에서 pull-to-refresh를 실행해도 로딩 피드백이 보이지 않음
- refresh indicator 커스터마이징이 전역 appearance에 의존해 다른 화면까지 영향 가능
- `WaveShape` phase 테스트가 이름과 달리 실제 차이를 검증하지 못함
- `design-system` skill 문서의 탭 구조 설명이 실제 앱 구조와 불일치

### Root Cause

- `waveRefreshable`이 `hasContent` 조건으로 인디케이터 렌더링을 제한했고, 동시에 시스템 스피너를 전역에서 숨겨 빈 상태 피드백이 사라졌음
- 테스트가 "non-empty path"만 확인하는 약한 assertion으로 구성되어 회귀 탐지력이 낮았음
- 디자인 문서 업데이트가 코드 구조 변경(3개 메인 탭 + Exercise 화면)과 동기화되지 않았음

## Solution

리뷰 findings를 우선순위와 관계없이 모두 반영했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | `UIRefreshControl.appearance().tintColor` 제거 | 전역 side effect 제거 |
| `DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift` | `hasContent` 조건 제거, `showIndicator` 기준으로만 표시 | 빈 상태 포함 refresh 피드백 보장 |
| `DUNE/Presentation/*View.swift` 4개 | `waveRefreshable` 호출부에서 `hasContent` 인자 제거 | 새 API와 일관화 |
| `DUNETests/WaveShapeTests.swift` | phase 테스트를 시작점 좌표 비교 방식으로 강화 | 실제 phase 변화 검증 |
| `.claude/skills/design-system/SKILL.md` | HeroCard 오버레이/탭 범위 설명을 코드와 동기화 | 에이전트 문서 정확도 회복 |

### Key Code

```swift
// Wave refresh indicator is now shown whenever refresh is active.
.overlay(alignment: .top) {
    if showIndicator {
        WaveRefreshIndicator(color: color)
            .padding(.top, DS.Spacing.sm)
    }
}
```

```swift
// Stronger phase test: compare actual start points from path geometry.
let start0 = firstWavePoint(from: path0)
let startHalfPi = firstWavePoint(from: pathHalfPi)
#expect(abs(start0!.y - startHalfPi!.y) > 0.1)
```

## Prevention

### Checklist Addition

- [ ] Custom refresh UI를 도입할 때 empty state에서도 로딩 피드백이 유지되는지 확인
- [ ] `UIAppearance` 변경은 전역 영향 범위를 검토하고 가능한 국소 적용 우선
- [ ] 테스트 이름과 assertion의 의미가 일치하는지(행동 검증 vs 존재 검증) 확인
- [ ] skill/rule 문서 변경 시 실제 코드 구조(탭 수, 컴포넌트 계약)와 교차 검증

### Rule Addition (if applicable)

현재 규칙 신규 추가는 보류하고, 이번 케이스는 리뷰 체크리스트에 반영했다.

## Lessons Learned

UI polish 작업에서도 로딩 피드백과 같은 기본 상호작용 보장은 별도 회귀 항목으로 다뤄야 한다.  
또한 에이전트가 참조하는 로컬 문서는 코드와 동일한 정확도로 유지해야 자동화 품질이 유지된다.
