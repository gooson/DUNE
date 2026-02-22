---
tags: [swiftui, activity-tab, ui-consistency, xcodebuild, xcodegen, pre-commit]
category: general
date: 2026-02-23
severity: important
related_files:
  - Dailve/Presentation/Activity/ActivityView.swift
  - Dailve/Presentation/Activity/Components/ExerciseListSection.swift
  - scripts/build-ios.sh
  - scripts/hooks/pre-commit.sh
  - .claude/skills/xcode-project/SKILL.md
  - CLAUDE.md
related_solutions:
  - docs/solutions/testing/2026-02-16-xcodegen-test-infrastructure.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: Activity Recent Workouts 스타일 정합 + iOS 빌드 가드 표준화

## Problem

Activity 탭에서 `Recent Workouts` 섹션만 다른 섹션과 카드 스타일이 달랐고, 빌드 검증도 실행자마다 명령이 달라 동일 작업에서 반복적으로 오해가 발생했다.

### Symptoms

- `Recent Workouts`만 `SectionGroup` 스타일(rounded material + 통일 헤더)을 사용하지 않아 룩앤필이 이질적
- 빌드 확인 시 `generic/platform=iOS` 같은 비표준 명령 사용으로 Watch/Simulator 환경 이슈와 혼동
- "다시 빌드 에러 났다" 피드백이 반복되며 검증 신뢰도 저하

### Root Cause

- UI: `ExerciseListSection`이 단독 렌더링되어 Activity 탭 공통 섹션 컨테이너 패턴에서 벗어남
- Workflow: 팀 표준 빌드 엔트리포인트가 없어 매번 ad-hoc `xcodebuild` 명령을 수동 조합

## Solution

UI 스타일을 공통 패턴으로 정렬하고, 빌드 검증을 단일 스크립트 + pre-commit 가드로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Dailve/Presentation/Activity/ActivityView.swift` | `Recent Workouts`를 `SectionGroup`으로 래핑 | Activity 탭 섹션 스타일 일관성 확보 |
| `Dailve/Presentation/Activity/Components/ExerciseListSection.swift` | 내부 `Recent Workouts` 타이틀 제거, `See All`/리스트 유지 | 중복 헤더 제거 + 기존 동작 보존 |
| `scripts/build-ios.sh` | `xcodegen generate` + iOS Simulator destination 고정 빌드 + 실패 요약 스크립트 추가 | 재현 가능한 표준 빌드 경로 제공 |
| `scripts/hooks/pre-commit.sh` | Swift/Xcode 관련 staged 변경 시 `build-ios.sh` 자동 실행 | 커밋 전 회귀 조기 감지 |
| `.claude/skills/xcode-project/SKILL.md` | 빌드 명령을 `scripts/build-ios.sh` 기준으로 갱신 | 팀 가이드와 실제 실행 경로 일치 |
| `CLAUDE.md` | Correction Log #95, #96 추가 | 동일 실수 재발 방지 지식 축적 |

### Key Code

```swift
// ActivityView
SectionGroup(title: "Recent Workouts", icon: "clock.arrow.circlepath", iconColor: DS.Color.activity) {
    ExerciseListSection(
        workouts: viewModel.recentWorkouts,
        exerciseRecords: recentRecords
    )
}
```

```bash
# scripts/hooks/pre-commit.sh
if git diff --cached --name-only | grep -Eq "^(Dailve/|DailveTests/|DailveUITests/|DailveWatch/).*\\.(swift|yml|plist|entitlements)$"; then
  "$ROOT_DIR/scripts/build-ios.sh"
fi
```

## Prevention

### Checklist Addition

- [ ] Activity 탭 섹션 추가/수정 시 `SectionGroup` 패턴 적용 여부를 먼저 확인한다.
- [ ] 빌드 검증은 ad-hoc 명령 대신 `scripts/build-ios.sh`만 사용한다.
- [ ] Swift/Xcode 변경 커밋 전 pre-commit 빌드 가드 통과 여부를 확인한다.

### Rule Addition (if applicable)

신규 rule 파일 추가는 하지 않았고, 아래에 반영:
- `CLAUDE.md` Correction Log #95, #96
- `.claude/skills/xcode-project/SKILL.md` 빌드 섹션

## Lessons Learned

- UI 일관성 이슈는 컴포넌트 내부 미세 조정보다 상위 컨테이너 패턴 정렬로 빠르게 해결된다.
- "어떤 명령으로 빌드했는가"가 결과 신뢰도를 결정한다. 단일 스크립트 표준화가 반복 오해를 크게 줄인다.
- pre-commit의 가벼운 자동 검증이 리뷰 단계보다 빠르게 회귀를 잡아낸다.
