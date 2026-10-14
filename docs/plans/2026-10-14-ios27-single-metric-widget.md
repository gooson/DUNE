---
tags: [widgetkit, app-intents, ios27, privacy]
category: plan
topic: iOS 27 configurable portrait score widget
date: 2026-10-14
status: implemented
confidence: medium
related_solutions: []
related_brainstorms: []
---

# Implementation Plan: iOS 27 configurable portrait score widget

## Context

기존 DUNE Today는 3개 점수를 보여주는 StaticConfiguration 위젯이다. 설치된 위젯의 식별자를 유지하면서 Condition, Readiness, Wellness 중 하나를 고르는 별도 위젯을 추가한다.

## Requirements

- 기존 `WellnessDashboardWidget` kind, 설정 방식, 지원 크기를 유지한다.
- 별도 kind와 AppIntentConfiguration을 사용하고 기본 선택을 Condition으로 한다. small, medium, large, iOS 27 portrait extra-large를 지원한다.
- 기존 App Group 점수와 시간 단위 타임라인을 사용한다. 데이터 부재, 개인정보 가림, 명암 모드, EN/KO/JA 번역을 처리한다.
- 점수 선택과 위젯 식별자 계약을 검증한다.

## Approach

별도 provider와 view를 추가한다. 점수·상태·메시지는 테스트 가능한 공유 데이터 함수에서 함께 선택한다. 기존 상태 색상과 레이블을 재사용하고 크기별 배치를 제공한다.

## Affected Files

| File | Change |
|---|---|
| `DUNEWidget/SingleMetricWidget.swift` | Intent, provider, entry, and layouts |
| `DUNEWidget/WellnessDashboardWidget.swift` | Register second widget |
| `Shared/WidgetScoreData.swift` | Select metric snapshot |
| `Shared/WidgetSurfaceAccessibility.swift` | Stable second kind and routes |
| `Shared/Resources/Localizable.xcstrings` | New UI strings in EN/KO/JA |
| `DUNETests/WidgetScoreDataTests.swift` | Selection tests |
| `DUNETests/WidgetSurfaceAccessibilityTests.swift` | Identity and family tests |

## Implementation Steps

1. 공유 데이터 선택 함수와 별도 AppIntent 위젯을 추가한다.
2. String Catalog 번역, 프로젝트 타깃 등록, 단위 테스트를 추가한다.
3. 정적 검사 후 Xcode/기기 검증 대기 항목을 기록한다.

## Edge Cases

| 경우 | 처리 |
|---|---|
| 선택한 점수만 없음 | 다른 점수를 차용하지 않고 `--`와 앱 열기 안내 표시 |
| 모든 데이터 없음 | 안전한 빈 상태 표시 |
| 개인정보 가림 | 점수, 상태, 설명에 privacySensitive 적용 |

## Verification

- 로컬 iOS SDK 선언과 Apple WidgetFamily 문서 및 WWDC26 세션 277을 확인한다.
- String Catalog 정렬/검사, diff 검사, Swift 구문 검사를 실행한다.
- 다른 호스트의 실행 충돌을 피하도록 Xcode 빌드, 테스트, UI 테스트, 새 디자인맵 캡처는 후속 검증으로 기록한다.

## Testing Strategy

- 단위 테스트: 선택한 metric의 점수·상태·메시지 일치와 결측값 격리, 기존/new kind 및 family 계약.
- 수동 검증: small/medium/large/portrait, 명암 모드, 개인정보 가림, 위젯 갤러리 설정.

## Risks

- 실제 레이아웃과 개인정보 가림 렌더링은 병합 전 기기/시뮬레이터 확인이 필요하다.
- AppIntent 검색과 위젯 갤러리 메타데이터는 병합 전 Xcode 빌드와 갤러리 확인이 필요하다.

## Confidence Assessment

- Medium: SDK 선언 및 소스 정합성은 확인했지만 런타임 검증이 대기 중이다.
