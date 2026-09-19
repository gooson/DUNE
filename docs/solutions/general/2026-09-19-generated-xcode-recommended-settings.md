---
tags: [xcode, xcodegen, build-settings, recommended-settings]
date: 2026-09-19
category: general
status: implemented
---

# 프로젝트 재생성 시 Xcode 추천 설정 유지

## Problem

Xcode의 추천 설정을 생성된 프로젝트에서만 적용하면 xcodegen 재생성 시 사라져 같은 안내가 다시 나타날 수 있다.

## Solution

`DUNE/project.yml`의 프로젝트 공통 `settings.base`에 다음 값을 YES로 지정했다.

- `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`: 이미지·색상 에셋 심볼 확장 생성
- `CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED`: 번역 누락 정적 분석
- `DEAD_CODE_STRIPPING`: 사용하지 않는 코드 제거
- `ENABLE_USER_SCRIPT_SANDBOXING`: 빌드 스크립트 샌드박싱

`scripts/build-ios.sh`가 기존 생성 경로를 통해 Debug·Release 모두에 적용한다. 현재 생성 프로젝트에는 사용자 셸 스크립트 빌드 단계가 없다. 문자열 카탈로그 심볼 생성 설정은 별개이며 기존 NO를 유지한다.

## Prevention

추천 설정은 생성된 pbxproj만 수정하지 말고 project.yml에 기록한다. 향후 셸 스크립트 빌드 단계를 추가할 때는 샌드박싱에 맞게 입력·출력 파일을 선언한다.

## Lessons Learned

추천 설정의 실제 빌드 값을 생성 원본에 명시하면 재생성 후에도 유지된다. Xcode 버전 확인 메타데이터만 바꿔 안내를 숨기는 방식에 의존할 필요가 없다.
