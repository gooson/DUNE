---
tags: [xcodegen, rename, branding, project-yml, bundle-id, product-name, directory-rename]
category: general
date: 2026-02-25
severity: important
related_files:
  - DUNE/project.yml
  - scripts/build-ios.sh
  - scripts/hooks/pre-commit.sh
  - scripts/hooks/cleanup-artifacts.sh
related_solutions: []
---

# Solution: xcodegen 기반 앱 이름 전체 리뉴얼 (Dailve → DUNE)

## Problem

### Symptoms

- 앱 이름을 "Dailve"에서 "DUNE"으로 변경해야 함
- 디렉토리명, 타겟명, PRODUCT_NAME, UI 텍스트 모두 변경 필요
- Bundle ID(`com.raftel.dailve`)와 CloudKit container는 유지해야 함

### Root Cause

브랜딩 리뉴얼. xcodegen 기반 프로젝트에서 앱 이름 변경은 `project.yml`이 single source of truth이므로 여기서 시작하되, 디렉토리 구조, import 경로, 빌드 스크립트, CI/CD 인프라까지 광범위하게 영향을 미침.

## Solution

### 변경 범위 분류

| 카테고리 | 변경 대상 | 변경 여부 |
|----------|-----------|-----------|
| 디렉토리 | `Dailve/` → `DUNE/` 등 4개 | ✅ git mv |
| project.yml | 타겟명, 스킴명, PRODUCT_NAME | ✅ 전면 재작성 |
| Swift 소스 | struct 이름, UI 텍스트 | ✅ 선택적 수정 |
| 테스트 | `@testable import` | ✅ 48파일 일괄 변경 |
| 빌드 스크립트 | 경로, 스킴명 | ✅ 전면 수정 |
| .claude 인프라 | rules, skills, agents | ✅ 경로/명칭 업데이트 |
| Bundle ID | `com.raftel.dailve` | ❌ 유지 |
| iCloud container | `iCloud.com.raftel.dailve` | ❌ 유지 |
| UserDefaults 키 | 기존 키 | ❌ 유지 |
| Logger subsystem | `com.raftel.dailve` | ❌ 유지 |

### 실행 순서 (의존성 기반)

```
1. git mv (디렉토리 리네이밍) — 다른 모든 작업의 전제
2. 파일 리네이밍 (entitlements, App.swift)
3. project.yml 전면 업데이트
4. Swift 소스 코드 수정 (struct, UI 텍스트)
5. 빌드 스크립트 업데이트
6. .claude/ 인프라 업데이트 + @testable import 일괄 변경
7. xcodegen → xcodebuild 빌드 검증
```

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/project.yml` | 타겟·스킴·PRODUCT_NAME 전면 변경 | xcodegen source of truth |
| `DUNE/App/DUNEApp.swift` | struct 이름 변경 | @main entry point |
| `DUNEWatch/DUNEWatchApp.swift` | struct 이름 변경 | Watch entry point |
| `scripts/build-ios.sh` | 경로·스킴·프로젝트명 변경 | CI/빌드 인프라 |
| `scripts/hooks/pre-commit.sh` | 디렉토리 패턴 변경 | commit hook |
| `DUNETests/**` (48파일) | `@testable import` 변경 | 모듈명 변경 반영 |

### Key Code

**project.yml 핵심 변경** — Bundle ID는 유지하면서 PRODUCT_NAME만 변경:
```yaml
targets:
  DUNE:
    type: application
    settings:
      base:
        PRODUCT_NAME: DUNE
        PRODUCT_BUNDLE_IDENTIFIER: com.raftel.dailve  # 유지!
        INFOPLIST_KEY_CFBundleDisplayName: DUNE
```

**@testable import 일괄 변경** — sed로 48파일 한 번에:
```bash
find DUNETests -name '*.swift' -exec sed -i '' \
  's/@testable import Dailve/@testable import DUNE/g' {} +
```

**git mv로 디렉토리 리네이밍** — 히스토리 보존:
```bash
git mv Dailve DUNE
git mv DailveWatch DUNEWatch
git mv DailveTests DUNETests
git mv DailveUITests DUNEUITests
```

## Prevention

### 앱 이름 변경 시 체크리스트

1. **변경하면 안 되는 것 먼저 목록화**: Bundle ID, CloudKit container, UserDefaults 키, Logger subsystem
2. **grep으로 전체 참조 검색**: `grep -r "OldName" --include="*.swift" --include="*.yml" --include="*.sh" --include="*.md"`
3. **변경 순서**: 디렉토리 → project.yml → 소스 → 스크립트 → 인프라 → 빌드 검증
4. **빌드 검증은 반드시 마지막**: xcodegen 재생성 후 xcodebuild로 확인

### Checklist Addition

- [ ] 앱 이름 변경 시 Bundle ID 변경 여부 명시적 확인
- [ ] `@testable import` 모듈명이 project.yml 타겟명과 일치하는지 확인
- [ ] pre-commit hook의 디렉토리 패턴이 새 이름과 일치하는지 확인

## Lessons Learned

1. **xcodegen 프로젝트에서 이름 변경은 project.yml 중심**: Xcode IDE에서 수동 변경 불필요. project.yml 수정 후 xcodegen generate로 반영
2. **`@testable import`는 타겟명을 따름**: PRODUCT_NAME이 아닌 project.yml의 target key가 모듈명이 됨
3. **Bundle ID와 PRODUCT_NAME은 독립적**: `PRODUCT_NAME: DUNE` + `PRODUCT_BUNDLE_IDENTIFIER: com.raftel.dailve`는 완전히 유효한 조합
4. **git mv는 히스토리 보존**: `git mv OldDir NewDir`로 리네이밍하면 git이 rename으로 추적 (similarity 100%)
5. **sed 일괄 변경 후 반드시 역검증**: `grep -r "OldName"` 으로 누락 확인 필수
6. **agent-memory 파일은 건드리지 않음**: 리뷰 에이전트의 학습 캐시는 자동으로 업데이트됨
