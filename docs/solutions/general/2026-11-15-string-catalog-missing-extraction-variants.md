---
tags: [localization, xcstrings, interpolation, xcode, extraction]
category: general
date: 2026-11-15
status: implemented
severity: important
related_files:
  - Shared/Resources/Localizable.xcstrings
  - scripts/tests/test_format_xcstrings.py
related_solutions:
  - 2026-10-26-string-catalog-extraction-stability.md
---

# Solution: Xcode가 반복 추가하는 빈 문자열 키 등록

## Problem

원본 checkout에서 빌드 후 Shared 카탈로그에 `%@ / 100`, `%@ of 100`,
`%@%% applied`, `Last %@ days`, `RISK` 빈 항목이 반복 추가됐다.
스크린샷과 원본 checkout의 diff가 동일했다. 확인 당시 checkout은 `main`이고
로컬·원격 `develop` 브랜치는 없었다.

### Root Cause

정수 보간을 위한 `%lld` 키를 등록해도 Xcode가 추출한 `%@` 키를 대신하지 않는다.
기존 항목의 `extractionState: manual`은 미등록 키의 자동 추가를 막지 않는다.
`RISK`도 코드에는 있으나 카탈로그에 없었다.

## Solution

4개 보간 키를 `manual`로 추가하고 기존 `%lld` 항목의 en/ja/ko 번역을 재사용했다.
번역 안의 보간 타입도 `%@`로 맞췄다. 기존 키·번역은 보존했다.
`RISK`는 A08 레이아웃 맵의 영어 라벨을 유지하도록 `manual`,
`shouldTranslate: false`로 등록했다. 자동 추출 설정과 formatter는 변경하지 않았다.

## Validation

- 수정 전 회귀 테스트에서 미등록 5개 키와 sync 후 바이트 차이를 재현했다.
- `python3 -B -m unittest scripts.tests.test_format_xcstrings`: 11개 통과, skip 0.
- 기존 추출 회귀 테스트에 5개 키를 추가했다. 실제 `xcstringstool sync`를
  같은 복사본에 두 번 적용해도 바이트가 동일했다.
- formatter `--check --check-manual` 통과.
- 실제 `xcstringstool compile` 성공, 기존 컴파일 번역 값 변경·삭제 0개.
- 앱 코드·레이아웃·테마 변경은 없다. 앱 빌드와 UI 캡처는 실행하지 않았다.
  T05의 한국어·일본어 보간 번역이 연결되므로 일반 iPhone·iPad·Duo 접힘/펼침의
  해당 locale 실제 캡처는 미갱신이다. 이번 검증은 추출·리소스 컴파일 범위이며
  기존 이미지를 새 번역 화면의 검증으로 사용하지 않는다. P05의 점수 표기는
  모든 언어에서 동일하고 A08의 RISK 표기도 유지된다. Watch 카탈로그는 영향이 없다.

## Prevention

빈 자동 생성 키를 되돌리기만 하지 말고 실제 추출 키와 번역의 보간 타입을 함께
등록한다. 빌드 전후 formatter 검사와 실제 Xcode sync 회귀 테스트로 재발을 검사한다.

## Lessons Learned

수동 관리 상태와 키 등록 완전성은 별개의 조건이다. `%lld`와 `%@`는 같은 숫자를
표시하더라도 별도 키이므로 실제 추출 결과를 기준으로 등록해야 한다.
