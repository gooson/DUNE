---
tags: [localization, xcstrings, xcodegen, build-settings]
category: general
date: 2026-09-19
status: implemented
severity: important
related_files: [DUNE/project.yml, DUNE/DUNE.xcodeproj/project.pbxproj]
---

# String Catalog Swift 심볼 충돌

## Problem

`Localizable.xcstrings`에서 Swift 이름을 만들 수 없거나 같은 심볼이 생성된다는 오류가 다수 발생했다. 프로젝트 설정의 `STRING_CATALOG_GENERATE_SYMBOLS = YES`가 영어 텍스트 키를 Swift 심볼로 변환하면서 `Add Habit`/`Add habit`, `Body Fat`/`Body Fat (%)` 등이 충돌했다. 포맷 지정자만 있는 키와 예약어에 가까운 키도 실패했다.

## Solution

코드는 영어 키를 직접 사용하는 localization 방식을 채택하고 있다. `DUNE/project.yml`의 공통 `settings.base`에 `STRING_CATALOG_GENERATE_SYMBOLS: NO`를 명시하고 `scripts/build-ios.sh`로 프로젝트를 재생성했다. 번역 키와 번역 내용은 유지했다.

검증:
- `xcstringstool generate-symbols`로 기존 오류 재현.
- 공통 Debug/Release 설정의 심볼 생성 비활성화 확인.
- `scripts/build-ios.sh` 성공 (`BUILD SUCCEEDED`).
- Shared 및 Watch 카탈로그의 `xcstringstool compile` 성공.

## Prevention

프로젝트 재생성 시 유지되어야 하는 설정은 생성된 pbxproj에만 수정하지 말고 `project.yml`에 명시한다. 심볼 생성을 도입하려면 대소문자, 구두점, 포맷 지정자, 예약어에 따른 충돌을 먼저 해결해야 한다.

## Lessons Learned

번역 키로 유효한 문자열도 Swift 식별자로 자동 변환할 수 있는 것은 아니다. 문자열 리소스 컴파일과 Swift 심볼 생성은 별도 기능이다.
