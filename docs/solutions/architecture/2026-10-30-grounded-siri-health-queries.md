---
tags: [siri, app-intents, foundation-models, healthkit, task-local, localization, speech]
category: architecture
date: 2026-10-30
severity: important
related_files:
  - DUNE/Domain/Models/HealthQuery.swift
  - DUNE/Domain/Models/HealthQueryLocalization.swift
  - DUNE/Data/Services/HealthQueryService.swift
  - DUNE/Data/Services/HealthQueryAssistant.swift
  - DUNE/App/Intents/HealthQueryIntent.swift
related_solutions: []
---

# Solution: 검증된 건강 조회를 Siri의 요청 언어로 읽기

## Problem

기존 운동·습관 실행 중심의 단축어에 건강 정보 읽기를 추가할 때, 모델이 만들어 낸 수치를 답하거나 앱 언어로 생성한 단위·날짜를 다른 언어의 Siri가 읽을 위험이 있었다. 공용 모델 세션의 문맥이나 locale을 변경하면 동시 요청도 서로 영향을 받는다. 잠금·조회 실패·실제 기록 없음도 구분해야 했다.

실제 음색이 이상하다는 사용자 보고는 코드 검토만으로 특정 원인까지 확정할 수 없다. 검증 가능한 응답 생성·언어 처리와 실제 청취를 분리했다.

## Solution

| 파일 | 변경 | 이유 |
|---|---|---|
| HealthQuery.swift | 14개 typed query, 기간·상태·단위·출처 DTO | 앱 UI와 Siri가 같은 계약 사용 |
| HealthQueryService와 확장 | 보호 데이터 gate, bounded 읽기, 실제 완료 세트, 중복·삭제 처리 | 값·날짜·출처를 코드로 검증 |
| HealthQueryAssistant.swift | 요청별 모델 세션, typed plan, 한 번의 도구 읽기 예산 | 모델은 계획·표현을 돕고 수치는 조회 결과 유지 |
| HealthQueryLocalization.swift | 요청별 TaskLocal locale | actor hop·동시 호출에서 Siri 언어 격리 |
| HealthQueryIntent.swift | 시스템 locale·ProvidesDialog·전체/supporting 응답 | 시스템 Siri 음성을 사용하고 실제 값을 읽기 |

핵심 흐름은 다음과 같다.

```swift
let locale = systemContext.locale // SDK 27 / compiler availability guard 내부
let result = try await HealthQueryLocalization.$locale.withValue(locale) {
    try await HealthQueryService.shared.execute(request)
}
// IntentDialog의 full과 supporting 모두 검증된 spokenSummary 사용
```

서비스는 잠금 상태를 읽기 전·await 후에 확인한다. 실패한 소스는 partial/unavailable로 보존하고 빈 결과와 혼동하지 않는다. 수면은 기상일로 귀속하고, 캘린더 기간의 끝은 다음 날 자정을 포함하지 않는다. 날짜는 실제 측정 시각과 조회 시각을 구분한다.

낭독은 축약 단위를 풀어 `킬로그램`, `분당 63회`, `1시간 1분 1초`처럼 만든다. 같은 날짜를 지표마다 반복하지 않는다. 별도 AVSpeechSynthesizer로 Siri 음색을 복제하지 않는다. 음색과 억양은 시스템 소유다.

## Prevention

- 잠금과 잠금 해제 중 읽기, 부분 실패와 기록 없음, 실제 완료 세트, 중복·삭제, DST·기간 끝을 테스트한다.
- 모델 도구 예산은 검증·await 전에 소비하고 실패해도 복원하지 않는다. 같은 응답에서 추가 읽기가 발생하지 않게 한다.
- 기록 메모를 모델 지시로 사용하지 않으며 공유 통계에 포함하지 않는다.
- Siri locale을 전역 상태로 바꾸지 않는다. 동시 locale 격리·오류 후 복원·한국어 단위 테스트를 유지한다.
- SwiftUI 부모의 접근성 식별자가 자식 ID를 덮는지 실제 AX 트리를 확인한다. 식별자는 필요한 개별 요소에 둔다.
- 빌드·단위 테스트·UI 테스트·실제 Siri 청취의 증거를 각각 기록한다. 정적 검토와 HTML 시안으로 실제 화면을 승인하지 않는다.
- `.claude/**` 규칙 변경은 이번 작업에 포함하지 않았다.

## Validation and limits

관련 62개 단위 테스트·9개 suite가 `3999e507`에서 통과했고, 최종 앱 소스 `401cbf3d`는 Xcode 27.1 / SDK 27.1 generic iOS 빌드에 성공했다. 이후 문서만 변경했다. 수정 후 UI 재검증과 네이티브 캡처는 저장소 시뮬레이터 실행권 차단으로 미완료다. 실제 Siri 발화·음색·억양, Xcode 27.2 빌드, PCC entitlement는 검증되지 않았다. [실행·리뷰 기록](../../reviews/2026-10-30-siri-health-queries/README.md)에 정확한 결과와 재개 조건을 남긴다.

## Lessons Learned

최신 모델 API를 연결하기 전에 조회 계약과 데이터의 의미를 고정해야 한다. 자연스러운 낭독은 시스템 음성을 사용하는 것과 요청 언어·숫자·단위·날짜를 알맞게 만드는 작업이 함께 필요하다. 실제 음질 개선 여부는 실기기에서 들어야 판단할 수 있다.
