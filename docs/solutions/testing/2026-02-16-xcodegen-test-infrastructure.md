---
tags: [xcodegen, swift-testing, unit-test, ui-test, project-yml, test-infrastructure]
category: testing
date: 2026-02-16
severity: important
related_files: [Dailve/project.yml, DailveTests/, DailveUITests/, .claude/skills/xcode-project/SKILL.md]
related_solutions: []
---

# Solution: xcodegen 기반 테스트 인프라 구축

## Problem

### Symptoms

- Xcode 프로젝트 파일(`.xcodeproj`)이 없어 빌드/테스트 불가
- 유닛 테스트가 전혀 없는 상태로 코드 품질 검증 불가
- 워크플로우에서 테스트 작성이 선택사항이었음

### Root Cause

MVP 초기 구현 시 코드만 작성하고 프로젝트 구성과 테스트를 후순위로 미룸.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Dailve/project.yml` | xcodegen 스펙 생성 | 프로젝트 설정의 source of truth |
| `DailveTests/*.swift` (6개) | 32개 유닛 테스트 작성 | UseCase, ViewModel, Model 커버리지 |
| `DailveUITests/*.swift` (2개) | 런치/네비게이션 UI 테스트 | Critical flow 검증 |
| `.claude/skills/xcode-project/SKILL.md` | 프로젝트 관리 스킬 | 빌드/테스트 명령 표준화 |
| `.claude/rules/testing-required.md` | 테스트 필수 규칙 | 워크플로우에 테스트 강제 |
| `.claude/skills/testing-patterns/SKILL.md` | 테스트 패턴 상세화 | Mock, 네이밍, AAA 패턴 정의 |
| `.claude/skills/work/SKILL.md` | Phase 2에 테스트 필수 추가 | 구현 시 테스트 동반 작성 |

### Key Code

```yaml
# project.yml — 3-target 구성
targets:
  Dailve:
    type: application
    platform: iOS
    sources: [App, Data, Domain, Presentation, Resources]
  DailveTests:
    type: bundle.unit-test
    sources: [path: ../DailveTests]
    dependencies: [target: Dailve]
  DailveUITests:
    type: bundle.ui-testing
    sources: [path: ../DailveUITests]
    dependencies: [target: Dailve]
```

```swift
// Swift Testing 패턴
@Suite("CalculateConditionScoreUseCase")
struct CalculateConditionScoreUseCaseTests {
    @Test("Returns nil score when insufficient days")
    func insufficientDays() { ... }
}

// Protocol-based mock
struct MockHRVService: HRVQuerying {
    var samplesResult: [HRVSample] = []
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samplesResult }
}
```

## Prevention

### Checklist Addition

- [ ] 새 프로젝트 시작 시 `project.yml` + 테스트 타겟을 함께 생성
- [ ] 새 UseCase/ViewModel 추가 시 반드시 테스트 파일 동반 생성

### Rule Addition

`testing-required.md` 규칙으로 테스트 작성이 워크플로우에 강제됨.

## Lessons Learned

1. **테스트 인프라는 첫 커밋에 포함해야 한다**: 나중에 추가하면 기존 코드의 빌드 에러를 함께 잡아야 해서 작업량이 배가됨
2. **xcodegen은 `.xcodeproj`를 gitignore하게 해준다**: `project.yml`이 source of truth이므로 머지 충돌 제거
3. **Swift Testing > XCTest**: `@Suite`, `@Test`, `#expect` 가 더 간결하고 parameterized test 지원이 우수
