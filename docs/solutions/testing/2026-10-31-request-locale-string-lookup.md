---
tags: [ci, localization, siri, task-local, localized-string-resource]
date: 2026-10-31
category: testing
status: implemented
related_files:
  - DUNE/Domain/Models/HealthQueryLocalization.swift
  - DUNE/Data/Services/HealthQueryService.swift
  - DUNE/Data/Services/HealthQueryService+Workouts.swift
  - DUNE/Data/Services/HealthQueryService+Wellness.swift
  - DUNE/Data/Services/HealthQueryService+Analysis.swift
  - DUNE/Data/Services/HealthQueryAssistant.swift
  - DUNETests/HealthQueryLocalizationTests.swift
related_solutions:
  - docs/solutions/architecture/2026-10-30-grounded-siri-health-queries.md
  - docs/solutions/testing/2026-10-31-ci-unit-platform-isolation.md
---

# Siri 요청 언어와 문자열 번역 조회 언어 일치

## Problem

[PR #877의 첫 iOS CI](https://github.com/gooson/DUNE/actions/runs/41160626407/job/124417160471)는 295개 suite의 테스트 2,679개를 실행했고, `HealthQueryLocalizationTests`의 두 테스트에서 총 5개 assertion이 실패했다. 요청의 TaskLocal locale이 `ko_KR`인데도 `75.5 kilograms`, `Latest Workout` 등 영어 단위·응답을 반환했다. 카탈로그에는 해당 키의 한국어 번역이 존재했다.

[`String(localized:locale:)`의 locale](https://developer.apple.com/documentation/swift/string/init(localized:options:table:bundle:locale:comment:))은 보간 값의 형식에 적용되며 번역 조회 언어를 바꾸지 않는다. 기존 코드는 locale의 actor hop 격리는 보장했지만, 앱 언어와 다른 Siri 요청 언어의 번역을 선택하지 못했다.

## Solution

`HealthQueryLocalization.localized(_:)`가 요청 locale을 가진 `LocalizedStringResource`를 만든 뒤 문자열로 해석한다. [`LocalizedStringResource.locale`](https://developer.apple.com/documentation/foundation/localizedstringresource/locale)은 번역 조회 언어를 지정한다.

```swift
static func localized(_ value: String.LocalizationValue) -> String {
    String(localized: LocalizedStringResource(value, locale: locale))
}
```

건강 질의 서비스·확장·assistant의 요청별 번역 호출을 이 helper로 통일한다. 기존 문자열 키·보간 값·번역과 숫자·날짜 포매터의 locale 처리는 유지한다. 앱 전역 언어 설정을 바꾸거나 번역을 코드에 분기하지 않는다.

## Verification

기존 한국어 자연 단위와 assistant actor hop 테스트를 유지한다. 영어·한국어·일본어 요청의 제목 선택과 영어·한국어 동시 요청의 번역 격리 테스트를 추가한다.

관련 소비자는 건강 질의 서비스, wellness·workout·analysis 응답, assistant fallback이다. 표준 실행기로 `HealthQueryLocalizationTests`, `HealthQueryAssistantTests`, `HealthQueryServiceTests`, `HealthQueryWellnessTests`만 선택하고 1,200초 deadline을 적용한다. 카탈로그 포맷과 manual extraction state도 빌드 전후 확인한다. 전체 원격 suite 결과는 [PR #877 검사](https://github.com/gooson/DUNE/pull/877/checks)를 따른다.

로컬 Xcode 27.2의 전용 iPhone 시뮬레이터에서 위 4개 suite의 테스트 47개가 통과했다. 한국어 단위·assistant fallback, 영어·한국어·일본어 제목, 동시 요청의 번역 격리도 실제 실행됐다. 앱과 테스트 타깃의 컴파일 및 빌드 전후 카탈로그 검사도 통과했다. 낭독 응답의 번역 조회를 검증한 결과이며 실제 Siri 음질·억양 검증은 포함하지 않는다.

## Prevention

- 번역 선택과 보간 숫자·날짜 형식의 locale을 구분한다.
- 앱 언어와 요청 언어가 다른 경우를 실제 번역 리소스가 포함된 타깃에서 검사한다.
- actor hop 이후와 동시 요청에서도 제목·낭독 응답의 언어를 직접 검증한다.
- 한국어 개발 환경의 성공만으로 영어 CI 환경의 언어 선택을 검증했다고 판단하지 않는다.

## Lessons Learned

TaskLocal은 요청 상태의 격리를 해결한다. 해당 값을 받는 API가 어떤 동작에 locale을 적용하는지도 별도로 확인해야 한다.
