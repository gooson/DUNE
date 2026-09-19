---
tags: [xcode, xcodegen, watchos, xcscheme, regeneration]
date: 2026-09-19
category: general
status: implemented
---

# Watch 스킴 재생성 후 반복 변경 방지

## Problem

프로젝트 생성 후 Xcode가 Watch 스킴 3개의 LaunchAction·ProfileAction에 있는 DUNEWatch 앱 참조의 BlueprintName을 삭제했다. 생성기가 다시 추가하여 같은 미커밋 변경이 반복됐다. main 전환 중 Xcode 저장이 겹치면 fast-forward도 막힐 수 있었다.

## Solution

`scripts/lib/regen-project.sh`의 normalize_xcscheme에서 DUNEWatch.app의 BuildableProductRunnable 내부 BlueprintName만 제거한다. 빌드 항목, 테스트 항목, MacroExpansion과 iOS 실행 참조는 유지한다.

`scripts/tests/test-watch-scheme-normalization.py`는 실제 스킴을 임시 경로에 복제해 생성기의 속성을 재현한 뒤 Watch 3개 정규화, iOS 참조 보존, 빌드·테스트 참조 보존 및 반복 실행의 동일성을 검사한다.

## Prevention

생성 파일만 되돌리지 말고 생성 후처리에 Xcode의 저장 형식을 반영한다. 실행 대상 식별자까지 제거하지 않도록 수정 범위를 제한한다.

## Lessons Learned

동일한 파일이라도 실행 참조와 빌드 참조의 저장 규칙은 다를 수 있다. 단순한 전체 BlueprintName 삭제 대신 문맥에 맞춘 정규화가 필요하다.
