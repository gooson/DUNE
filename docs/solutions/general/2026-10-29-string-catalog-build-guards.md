---
tags: [localization, xcstrings, infoplist, extractionState, xcode, build-validation]
category: general
date: 2026-10-29
status: implemented
severity: important
related_files:
  - Shared/Resources/Localizable.xcstrings
  - DUNEWatch/Resources/InfoPlist.xcstrings
  - scripts/format-xcstrings.swift
  - scripts/hooks/pre-commit.sh
  - scripts/build-ios.sh
  - scripts/tests/test_format_xcstrings.py
  - .github/workflows/build-ios.yml
  - AGENTS.md
related_solutions:
  - 2026-10-26-string-catalog-extraction-stability.md
  - 2026-10-08-string-catalog-format.md
---

# Solution: 빌드 중 문자열 카탈로그 신규 키 추가 검출

## Problem

Watch 빌드에서 `InfoPlist.xcstrings`에 앱 이름·건강 데이터·모션 권한 키가 추가됐다. 이어 Shared 카탈로그에도 `%@ completions`, `%@ of %@ complete`, `%@ of %@ days`, `Completed %@`, `Weekly goal: %@ days`가 추가됐다.

### Root Cause

- `InfoPlist.xcstrings`를 타깃에 추가하면 위치 권한 외에 Xcode가 인식하는 다른 Info.plist 키도 추출된다. 기존 formatter·커밋 검사·회귀 테스트는 Localizable 두 파일만 대상으로 했다.
- `extractionState: manual`은 등록된 키의 추출 상태를 안정화하지만 **누락된 신규 키의 추출을 막지는 않는다**.
- 기존 `%lld` 숫자 키와 실제 SwiftUI 추출의 `%@` 키는 별개다. 의미가 같아도 기존 번역 키가 새 키의 등록을 대신하지 않는다.
- Shared에는 `–`, `%@ / %@`, `Average heart rate: %@ bpm`, `Collapse summary`, `Expand summary` 등 미관리 항목 5개도 남아 있었다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| Watch InfoPlist | main에 추가된 5개 키를 manual로 관리 | 등록된 항목의 추출 상태를 안정화 |
| Shared Localizable | main에 등록된 보간 키 5개와 기존 미관리 항목 5개를 manual로 관리 | 신규·기존 항목의 추출 상태를 안정화 |
| Formatter | 기본 대상에 InfoPlist 추가, `--check-manual` 제공 | 포맷 검사와 추출 상태 검사를 함께 수행 |
| Pre-commit | 세 카탈로그의 Git index 내용을 검사 | 작업 파일만 고친 상태로 잘못된 staged blob을 커밋하는 경우 차단 |
| Build wrapper | Xcode 실행 전후에 `--check --check-manual` 실행 | 누락된 키가 추출되면 검증 실패, 발견한 변경은 보존 |
| Regression tests | Info.plist·XcodeGen 설정의 값과 실제 Xcode sync 결과 비교, 빌드·커밋 검사 실패 경로 검증 | 위치 권한 한 개만 검사하는 누락 재발 방지 |
| CI·AGENTS | 빌드 전 카탈로그 회귀 검사와 관리 절차 연결 | 검사 도구 변경 및 새 리소스 변경에도 적용 |

formatter는 번역 값·추출 상태를 자동 수정하지 않는다. 일반 실행은 포맷만 정리하고, `--check-manual`은 잘못된 상태를 보고한다. 카탈로그의 키·번역 값·번역 완료 상태·주석은 main과 동일하게 보존하고 추출 상태만 manual로 맞췄다. 번역 payload의 완성도 개선은 별도 작업이며, 이번 보완에서 화면 표시를 바꾸지 않는다.

## Prevention

```sh
swift scripts/format-xcstrings.swift
swift scripts/format-xcstrings.swift --check --check-manual
python3 -B -m unittest scripts.tests.test_format_xcstrings
scripts/build-ios.sh
```

- 새 키를 추가할 때 실제 추출 키와 보간 타입을 확인하고 `extractionState: manual`을 지정한다.
- 새 카탈로그를 만들면 formatter·hook·테스트의 대상 목록도 함께 갱신한다.
- Info.plist 권한 문구를 바꾸면 카탈로그의 영어 값도 함께 갱신한다. 테스트는 `xcodegen dump`로 프로젝트 설정을 읽고 Info.plist 값과 합쳐 확인한다.
- 자동 추출은 유지한다. 빌드 후 생성된 미관리 항목을 무시하거나 되돌려 검사를 통과시키지 않는다.
- Xcode GUI의 직접 빌드는 wrapper의 검사를 거치지 않는다. 그 변경도 staged catalog 검사와 CI에서 검출한다.
- 이 검사는 추출 상태·포맷·Info.plist 등록을 검증한다. 모든 언어의 번역 완성도나 화면 배치를 인증하지 않는다.

## Validation

- 카탈로그·Xcode sync·staged blob·빌드 전후 실패 경로를 포함한 관련 회귀 테스트 9개를 검증 대상으로 유지한다. 최종 범위에서 재실행한 결과는 [리뷰·배포 기록](../../reviews/2026-10-29-string-catalog-build-guards-review-ship.md)을 따른다.
- 첫 회귀 검사에서 기존 미관리 항목 5개를 검출했다. 해당 항목을 manual로 정리한 뒤 한 번 재실행해 통과했다.
- 최초 실제 빌드는 sandbox가 Swift 매크로 실행을 막아 실패했다. 해당 로그의 `sandbox-exec: sandbox_apply: Operation not permitted`를 확인한 뒤 sandbox 밖에서 1회 재시도했다.
- Xcode 27.1 / generic iOS / DUNE·embedded Watch·Widget 통합 빌드와 빌드 전후 세 카탈로그 검사가 모두 통과했다. `.xcodebuild/catalog-stability-build.log`의 `BUILD SUCCEEDED`와 실행기 종료 코드 0을 확인했다. 빌드 이후 추가 추출 항목이나 카탈로그 diff 증가가 없었다.
- 리뷰에서 신규 번역의 화면 영향 범위를 지적받아 해당 번역 변경을 제외했다. 세 카탈로그 모두 `extractionState`를 제외한 전체 JSON이 main과 동일함을 확인한다. 화면 문구·배치·코드가 바뀌지 않아 UI 실행과 실제 디자인맵 재캡처는 skipped이며, UI 통과를 뜻하지 않는다.

## Lessons Learned

포맷 일치, 기존 항목의 수동 관리, 신규 추출 키 등록은 서로 다른 문제다. 수동 상태 검사와 실제 추출·sync 회귀 검사, 빌드 후 검사를 함께 적용해야 등록 누락을 발견할 수 있다.
