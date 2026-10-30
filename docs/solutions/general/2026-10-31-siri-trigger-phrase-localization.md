---
tags: [siri, app-intents, app-shortcuts, localization, xcstrings]
category: general
date: 2026-10-31
severity: important
status: implemented
related_files:
  - DUNE/App/Intents/DUNEShortcuts.swift
  - DUNE/Resources/AppShortcuts.xcstrings
  - scripts/format-xcstrings.swift
  - scripts/tests/test_format_xcstrings.py
related_solutions:
  - architecture/2026-10-30-grounded-siri-health-queries.md
---

# Solution: Siri 호출 문구의 전용 번역 카탈로그 추가

## Problem

사용자가 Siri에 “오늘의 컨디션”이라고 말했지만 실행되지 않았다고 보고했다. 기기 종류와 Siri 응답은 확인하지 못했다.

### Root Cause

코드에 확인된 결함은 `DUNEAppShortcuts`의 영어 호출 문구만 있고 `AppShortcuts.xcstrings`가 없다는 점이다. `Localizable.xcstrings`의 화면·응답 번역만으로 Siri 호출 문구가 번역되지는 않는다. 또한 앱 이름 없는 발화를 DUNE 요청으로 연결할 수 있다고 가정하면 안 된다. 실제 실패의 모든 원인이 확인된 것은 아니다.

Apple은 [App Shortcuts 소개](https://developer.apple.com/videos/play/wwdc2023/10102/)에서 호출 문구 전용 `AppShortcuts` 카탈로그와 앱 이름 또는 별칭을 포함하는 조건을 설명한다. 이는 일반 UI의 `Localizable` 테이블과 별개인 시스템 지정 테이블이다. `.claude/**` 원본은 변경하지 않았다.

## Solution

- 기존 단축어 10개의 문구를 `AppShortcuts.xcstrings`에 등록했다. 영어와 한국어·중국어 간체/번체·일본어·스페인어를 포함한다.
- 컨디션에는 기존 문구 외에 질문형과 명사형을 추가했다. 한국어 예시는 “DUNE에서 오늘의 컨디션 보여줘”, “DUNE에서 오늘 컨디션 어때”, “DUNE 오늘의 컨디션”이다.
- 모든 언어에서 `${applicationName}` 토큰을 보존했다. 앱 이름을 번역문에 하드코딩하지 않는다.
- `Resources`의 기존 xcodegen 포함 규칙으로 iOS 앱에 리소스를 연결하고 생성된 프로젝트를 갱신했다.
- formatter 기본 목록과 기존 Xcode sync 검사에 새 카탈로그를 포함했다. 소스의 모든 호출 문구가 요청 언어에 번역되어 있는지 검사한다.

중국어·스페인어 앱 전체 UI/응답 번역이나 Watch용 intent 추가는 이 변경의 범위가 아니다. 기존 응답·화면·저장·인증 동작은 변경하지 않았다. 호출은 변경된 앱 설치본이 필요하다.

## Verification

- `python3 -B -m unittest scripts.tests.test_format_xcstrings`: 11개 통과. 12개 키·6개 언어(72개 문구), 수동 추출 상태, Xcode sync 불변성을 포함한다.
- `xcrun xcstringstool compile DUNE/Resources/AppShortcuts.xcstrings --output-directory /tmp/dune-siri-compiled`: 성공.
- `swift scripts/format-xcstrings.swift --check --check-manual`: 성공.
- 앱 빌드: 최초 실행은 `sandbox-exec: sandbox_apply: Operation not permitted` 및 Preview 매크로 실행 오류로 실패했다(`.xcodebuild/siri-localization-build.log`, exit 65). 권한을 조정한 1회 재시도는 `ClangStatCache` 단계에서 SDK 캐시 자식들이 CPU 사용 없이 대기했다. 1초 스택 샘플에서도 `CFRunLoopRun`/Mach 응답 대기를 확인했다. 소유 watchdog을 종료해 중단했다(`.xcodebuild/siri-localization-build-retry.log`, exit 130). 그룹 종료에 권한 오류가 출력되어 추가 조회했고, 소유 빌드와 캐시 자식 2개가 모두 종료된 것을 확인했다. 이 시점에서는 앱 빌드와 최종 Siri 메타데이터 추출이 미완료였다.
- `swiftc -frontend -parse DUNE/App/Intents/DUNEShortcuts.swift`: 성공. 빌드 중단 후 카탈로그 포맷·manual 상태와 `git diff --check`도 통과했다.
- **후속 Review/Resolve 검증 완료**: SDK 캐시 2개가 실제 생성됐고 이전 프로세스가 종료된 것을 확인한 뒤 재개한 앱 빌드가 성공했다. 리뷰의 한국어 요청형 문구 P2 1건을 수정한 뒤 계약 테스트 11개와 증분 앱 빌드도 통과했다. 최종 로그는 `/tmp/dune-siri-review-ship/catalog-tests.log`, `/tmp/dune-siri-review-ship/build-final.log`다. `ValidateAppShortcutStringsMetadata`·Siri NL training이 성공했고 앱에 들어간 6개 언어의 각 12개 호출 문구를 원본과 대조했다. 실제 Siri 음성 인식 검증과는 별개다.
- UI 판정기(`/tmp/dune-siri-ui-plan.json`)의 미매핑 `full` 경고를 검토했다. 실제 변경은 iOS Siri 호출 메타데이터와 검사 도구이며 앱 화면·레이아웃·조회 로직·Watch 소스 변경이 없어 앱 UI suite와 디자인맵 재캡처는 생략했다. Siri 시스템의 실제 인식 성공 증거를 뜻하지 않는다.
- 실제 iPhone의 Siri 언어별 음성 인식·앱 이름 발음·실행·낭독은 미검증이다. 이번 작업으로 실기기 호출 문제 전체가 해결되었다고 단정하지 않는다.

## Prevention

- 호출 문구를 추가·삭제할 때 전용 카탈로그의 모든 언어와 함께 갱신한다.
- `${applicationName}` 토큰을 유지하고 새 언어는 호출 문구와 응답 번역 범위를 따로 확인한다.
- 카탈로그 컴파일·intent 단위 테스트·앱 빌드와 실제 Siri 인식 검증을 구분한다.
- 사용자에게 알려 줄 예문에는 앱 이름을 포함한다.

## Lessons Learned

응답이 현지화되어 있어도 해당 언어로 Siri를 호출할 수 있다는 뜻은 아니다. 호출 문구의 전용 리소스, 앱 이름을 포함한 발화, 설치된 버전, 실제 Siri 라우팅을 각각 확인해야 한다.
