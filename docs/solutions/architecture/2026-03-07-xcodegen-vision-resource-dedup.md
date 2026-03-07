---
tags: [xcodegen, visionos, pbxproj, xcstrings, resource-groups, malformed-project]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/project.yml
  - DUNE/DUNE.xcodeproj/project.pbxproj
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/visionos-multi-target-setup.md
  - docs/solutions/general/2026-03-01-xcodegen-scheme-perpetual-diff.md
  - docs/solutions/general/2026-03-07-visionos-app-icon-wiring.md
---

# Solution: XcodeGen visionOS resource group dedup

## Problem

visionOS target resource wiring을 정리하는 과정에서 XcodeGen이 `DUNEVision` 루트 그룹과 shared 파일 reference를 중복 생성해, 생성된 `project.pbxproj`가 malformed 상태가 되었다.

### Symptoms

- Xcode navigator에 root-level `DUNEVision` 그룹이 두 개 보였다.
- `xcodebuild` 시작 시 `file reference is a member of multiple groups` 경고가 반복됐다.
- `Localizable.xcstrings`가 `Resources`와 `Shared` 양쪽에 걸려 membership이 임의 보존됐다.
- visionOS 리소스 배치가 target-specific group과 shared group 사이에서 계속 흔들렸다.

### Root Cause

- `project.yml`에서 shared iOS 코드/리소스를 `DUNEVision/...` 같은 target-specific group에 직접 매달아 XcodeGen이 중간 wrapper group을 추가 생성했다.
- 같은 실제 파일(`AppLogger.swift`, `AppSection.swift`, `Localizable.xcstrings`)을 서로 다른 group path로 다시 선언하면서 PBXFileReference dedupe가 발생했다.
- 특히 `Localizable.xcstrings`는 원본이 `DUNE/Resources`에 이미 존재하는데 widget/vision target에서도 다른 group으로 다시 붙이려 해서 malformed warning이 발생했다.

## Solution

`DUNEVision`에는 visionOS 전용 파일 트리만 남기고, shared 파일은 원래 source path를 유지한 채 target membership만 재사용하도록 `project.yml`을 정리했다. `Localizable.xcstrings`는 XcodeGen이 같은 file reference를 재사용하지 않도록 `Shared/Resources` 아래에 symlink path를 추가해 widget/vision이 별도 경로로 참조하게 만들었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/project.yml` | `DUNEVision` target에서 `group: DUNEVision/...` 매핑 제거, shared 문자열 경로를 `../Shared/Resources/Localizable.xcstrings`로 전환 | target-specific wrapper group과 duplicate file reference 생성을 막기 위해 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 재생성 후 중복 root `DUNEVision` group 제거, visionOS navigator를 `App/Presentation/Resources`만 남는 구조로 정리 | malformed project 경고 원인을 제거하기 위해 |
| `Shared/Resources/Localizable.xcstrings` | `../../DUNE/Resources/Localizable.xcstrings`를 가리키는 symlink 추가 | source-of-truth는 유지하면서 widget/vision용 별도 file reference를 강제하기 위해 |

### Key Code

```yaml
# DUNE/project.yml
targets:
  DUNEWidget:
    sources:
      - path: ../DUNEWidget
      - path: ../Shared/Resources/Localizable.xcstrings
        group: Shared

  DUNEVision:
    sources:
      - path: ../DUNEVision
      - path: App/AppLogger.swift
      - path: App/AppSection.swift
      - path: Domain
        excludes:
          - "Models/TemplateWorkoutConfig.swift"
          - "Models/WatchConnectivityModels.swift"
      - path: ../Shared/Resources/Localizable.xcstrings
        group: Shared

# one-time filesystem setup
ln -s ../../DUNE/Resources/Localizable.xcstrings Shared/Resources/Localizable.xcstrings
```

검증:

- `PROJECT_SPEC="DUNE/project.yml" PROJECT_FILE="DUNE/DUNE.xcodeproj" REGENERATE=1 bash -lc 'cd /Users/shanks/.codex/worktrees/88fb/Health && source scripts/lib/regen-project.sh && regen_project'`
- `xcodebuild -project /Users/shanks/.codex/worktrees/88fb/Health/DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' build`
- 빌드 결과: malformed `file reference` 경고 없이 `BUILD SUCCEEDED`

## Prevention

XcodeGen target spec에서 shared 파일을 target-specific logical group(`DUNEVision/...`)으로 다시 매달지 않는다. 같은 파일을 여러 target이 써야 할 때는 원래 group 하나만 재사용하거나, navigator 위치를 분리해야 하면 실제로 다른 path를 갖는 별도 reference(이 저장소에서는 symlink 포함)를 사용한다.

### Checklist Addition

- [ ] `project.yml`에서 shared 파일에 `group: {TargetName}/...`를 붙이지 않았는지 확인한다.
- [ ] `regen_project` 후 `xcodebuild` 시작 로그에 `file reference is a member of multiple groups` 경고가 없는지 확인한다.
- [ ] `Localizable.xcstrings`처럼 source-of-truth가 하나인 리소스는 path dedupe 여부까지 확인한다.

### Rule Addition (if applicable)

새 rule 파일까지는 필요 없지만, `CLAUDE.md` Correction Log에 XcodeGen shared-file group dedupe 주의사항을 추가해 두는 것이 적절하다.

## Lessons Learned

- XcodeGen에서는 같은 실파일을 다른 group path로 다시 선언해도 “새 reference”가 아니라 “기존 reference 재배치”로 처리될 수 있다.
- navigator 구조를 예쁘게 보이게 만들려는 시도가 PBXGroup 중복과 malformed project warning으로 바로 이어질 수 있다.
- `xcstrings` 같은 shared 리소스는 code file보다 dedupe 영향이 더 크므로, source path 설계를 먼저 고정한 뒤 target wiring을 해야 한다.
