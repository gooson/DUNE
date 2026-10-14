---
tags: [ios27, watchos27, visionos27, deployment-target, xcodegen, simulator-selection, github-actions]
category: testing
date: 2026-10-14
severity: important
status: implemented
related_files:
  - DUNE/project.yml
  - DUNE/DUNE.xcodeproj/project.pbxproj
  - scripts/test-unit.sh
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
  - scripts/tests/test_ui_test_runner.py
  - .github/workflows/build-ios.yml
  - .github/workflows/test-unit.yml
  - .github/workflows/test-ui.yml
  - .github/workflows/test-ui-nightly.yml
related_solutions:
  - docs/solutions/testing/2026-02-16-xcodegen-test-infrastructure.md
  - docs/solutions/testing/2026-03-03-ios-build-destination-fallback-hardening.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
---

# Solution: 모든 타깃과 CI의 iOS 27 배포 기준 동기화

## Problem

### Symptoms

- 앱 타깃만 올리면 확장, Watch, visionOS 또는 생성된 Xcode 프로젝트가 이전 최소 버전에 남을 수 있다.
- 기본 시뮬레이터 이름이 OS 27을 요청해도 fallback이 더 오래된 런타임을 고를 수 있다.
- 직전 기능 브랜치를 대상으로 하는 스택 PR은 `main`만 감시하는 CI를 실행하지 않는다.
- 로컬 Xcode 27 빌드만으로 CI가 Xcode 27 SDK를 사용한다고 보장할 수 없다.

### Root Cause

배포 요구사항이 XcodeGen 설정, 생성된 프로젝트, 테스트 스크립트의 기본값과 선택 로직, GitHub Actions 실행 환경에 분산되어 있었다. 이 값들은 자동으로 함께 변경되지 않는다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/project.yml`, 생성된 `.pbxproj` | iOS, watchOS, visionOS의 모든 타깃을 27.0으로 설정하고 Xcode 생성 메타데이터도 27로 조정 | 설정 원본과 체크인된 프로젝트를 일치시킴 |
| `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh` | OS 27을 기본으로 삼고 fallback 선택 전에 27 미만 후보 제거 | 27 기기 이름이 없을 때 OS 26으로 되돌아가지 않도록 함 |
| `scripts/tests/test_ui_test_runner.py` | 26/27 혼합 목록과 26만 있는 목록을 세 실행 경로에서 검사 | 기본 문자열뿐 아니라 런타임 하한을 검증 |
| `.github/workflows/*.yml` | Xcode 27 runner와 경로를 사용하고 `codex/ios27-*` base PR도 실행 | 스택의 각 PR을 로컬과 같은 SDK로 검증 |

### Key Code

정확한 이름, 같은 이름 fallback, 임의의 기기를 고르기 **전에** 사용 가능한 시뮬레이터를 최소 지원 OS로 걸러낸다. 결과가 비면 지원하지 않는 런타임으로 실행하지 않고 명확한 오류를 낸다.

```text
사용 가능한 기기 → OS 주 버전 27 이상 → 선호 이름/런타임 → 같은 이름 → 지원되는 다른 기기
```

## Prevention

### Checklist Addition

- [ ] XcodeGen 재생성 뒤 모든 타깃의 `IPHONEOS_DEPLOYMENT_TARGET`, `WATCHOS_DEPLOYMENT_TARGET`, `XROS_DEPLOYMENT_TARGET`을 확인한다.
- [ ] 지원/미지원 런타임 혼합 목록과 미지원 목록만 있는 경우를 모두 테스트한다.
- [ ] 스택 브랜치를 도입할 때 workflow의 `runs-on`, `DEVELOPER_DIR`, PR base 필터를 함께 확인한다.
- [ ] 기준 PR 머지 전에 해당 SDK에서 영향받는 빌드와 테스트를 실행한다.

### Rule Addition

새 `.claude/rules` 규칙은 추가하지 않는다. 위 체크리스트와 시뮬레이터 선택 계약 테스트가 반복 위험을 다룬다.

## Lessons Learned

최소 배포 버전은 단일 Xcode 설정이 아니라 전체 실행 경로의 계약이다. XcodeGen의 `xcodeVersion`과 프로젝트 호환 형식은 배포 타깃과 별개의 값이며, CI도 사용할 Xcode 이미지를 명시해야 한다. 스택 PR에는 임시 부모 브랜치와 일치하는 workflow base 필터가 필요하다.
