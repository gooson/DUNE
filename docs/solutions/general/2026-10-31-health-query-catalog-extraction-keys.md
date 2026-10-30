---
tags: [localization, xcstrings, extractionState, swiftui, pre-commit]
category: general
date: 2026-10-31
severity: important
related_files:
  - Shared/Resources/Localizable.xcstrings
  - DUNE/Presentation/HealthQuery/HealthQueryResultCard.swift
  - scripts/tests/test_format_xcstrings.py
related_solutions:
  - 2026-10-29-string-catalog-build-guards.md
---

# Solution: Health Query 빌드에서 반복 추가되는 카탈로그 키

## Problem

Xcode 빌드 후 Shared 카탈로그에 빈 항목 4개가 추가되고,
이를 stage하면 `--check-manual` 커밋 검사가 실패했다.

### Root Cause

실제 main의 staged diff에 `/100`, `× %@`, `Relative change: %@%%`,
`Showing the latest 50 of %@ sources.`가 추가돼 있었다.
기존 `%lld` 보간 키와 `%@` 키는 별개이며, 리터럴 퍼센트의 추출 키에는
`%%`가 사용된다. 등록된 키만 대상으로 했던 부분 추출 회귀 검사는
이 4개의 누락을 검출하지 못했다.

별도 SwiftUI 컴파일 probe에서는 정수 보간이 `%lld`로 추출됐다.
따라서 모든 환경에서 정수 보간이 `%@`가 된다고 일반화하지 않으며,
이번 수정은 사용자 Xcode 빌드에서 관측한 키와 기존 키를 모두 보존한다.

## Solution

- 관측된 4개 키를 `extractionState: manual`로 등록했다.
- 기존 번역, 키, 앱 소스와 화면 문구는 변경하지 않았다. 신규 항목의
  번역 payload도 이번 작업에서 추가하지 않았다.
- 사용자 빌드의 누락 키를 입력하는 `xcstringstool sync` 회귀 검사를 추가했다.
  기존 키의 일부만 재입력하는 검사와 달리 이번 누락을 직접 검출한다.
- 현재 main의 staged 카탈로그에도 동일한 4개 상태만 반영했다.
  적용 전 작업 파일과 index가 동일한지, 전체 JSON 차이가 이 4개뿐인지 확인했다.

## Validation

- `python3 -B -m unittest scripts.tests.test_format_xcstrings`: 10개 통과.
- 새 회귀 검사에서 실제 Xcode sync 후 카탈로그 바이트 불변 확인.
- 기존 모든 항목의 전체 JSON payload 동일, 신규 키 4개만 추가됨.
- formatter와 staged catalog의 `--check --check-manual` 검사 통과.
- 앱 코드·번역 표시 변경이 없어 앱 전체 빌드, UI 테스트와 디자인맵 캡처는
  실행하지 않았다. 앱 전체 빌드 성공을 의미하지 않는다.

## Prevention

카탈로그 검사는 우회하거나 자동 추출을 끄지 않는다. 빌드가 추가한 키는
실제 추출 형태 그대로 등록하고, formatter 실행 후 **staged blob**을 검사한다.
정수 보간의 `%lld`와 `%@`, 리터럴 `%`와 추출 키의 `%%`를 같은 키로 간주하지 않는다.
기존 localization 규칙으로 충분하므로 `.claude/**` 규칙 추가는 하지 않았다.

## Lessons Learned

수동 관리 상태는 기존 키의 변경을 막을 뿐 누락된 키의 생성을 막지 않는다.
회귀 검사는 이미 등록된 키의 불변성과 실제로 누락됐던 추출 키를 함께 검증해야 한다.
