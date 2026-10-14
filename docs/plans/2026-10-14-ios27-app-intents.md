---
topic: iOS 27 App Intents for workout templates and habits
date: 2026-10-14
status: implemented
confidence: medium
related_solutions: [docs/solutions/general/2026-04-05-habit-early-completion-fix.md]
related_brainstorms: []
---

# Implementation Plan: 운동 템플릿 열기와 습관 완료 단축어

## Context

Shortcuts에서 저장된 운동 템플릿을 열고 수동 체크형 습관을 오늘 완료할 수 있도록 한다. 두 동작 모두 기존 SwiftData 객체의 UUID를 사용한다.

## Requirements

- 템플릿은 앱 화면으로 열지만 운동 기록이나 HealthKit workout을 자동 생성하지 않는다.
- 습관 완료는 같은 날 재실행해도 로그가 늘어나지 않는다.
- 보관된 항목, 자동 연결 습관, 주기형 습관, 수량·시간형 습관은 선택 및 실행에서 제외한다.
- 잠금 화면에서 건강 관련 습관의 이름이나 완료 결과를 노출하지 않는다.

## Approach

`AppEntity` DTO와 `EntityQuery`를 앱의 기존 ModelContainer에 연결한다. `OpenIntent`는 iOS 27 scene routing으로 Activity 탭에 UUID를 전달하고, ActivityView가 템플릿을 재조회해 기존 `startFromTemplate` 경로를 사용한다. 습관 intent는 MainActor의 저장 서비스에서 같은 날 로그를 조회하고 하나만 삽입한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| SwiftData 모델 자체를 AppEntity로 노출 | 코드 적음 | 모델 수명·Sendable·개인정보 경계 불명확 | 제외 |
| URL scheme으로 화면 전환 | 구현 쉬움 | URL 외부 입력·다중 scene 처리 추가 | 제외 |
| UUID DTO + scene routing | 안정적인 식별자와 화면 처리 분리 | iOS 27 scene API 검증 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/App/DUNEApp.swift` | 수정 | App Intent 저장소 등록 및 갱신 |
| `DUNE/App/ContentView.swift` | 수정 | 템플릿 intent scene routing |
| `DUNE/Presentation/Activity/ActivityView.swift` | 수정 | UUID 재조회 후 기존 시작 흐름 호출 |
| `DUNE/App/Intents/*.swift` | 추가 | AppEntity, query, intent, 저장소 |
| `DUNE/Resources/Info.plist` | 수정 | scene routing manifest |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 재생성 | 새 소스와 테스트 포함 |
| `DUNETests/AppIntentStoreTests.swift` | 추가 | 실제 SwiftData 저장 경로와 중복 방지 |

## Implementation Steps

1. App Intent 저장소와 UUID DTO query를 추가한다. 존재하지 않거나 제한된 항목은 반환하지 않는다.
2. 템플릿 OpenIntent와 습관 완료 intent를 추가한다. 완료 동작은 인증을 요구한다.
3. scene routing을 ActivityView의 기존 템플릿 시작 경로에 연결한다.
4. in-memory SwiftData 테스트, generic iOS build, simulator Shortcuts 검증을 수행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 저장 후 템플릿/습관 삭제 | 실행 시 다시 조회하고 오류 반환 |
| 같은 날 재실행 | 기존 로그를 반환하고 추가하지 않음 |
| 날짜 경계 | 사용자의 현재 Calendar day interval 사용 |
| 여러 기기 동시 실행 | 기기별 중복 방지만 보장; CloudKit 동시 쓰기는 별도 정합성 과제 |
| 저장 실패 | 성공 응답 없이 오류 전파 |

## Testing Strategy

- In-memory SwiftData: query 필터, 최초 완료, 재완료, 다른 날짜, 보관/자동/유형 제한, 무효 UUID.
- Generic iOS build로 App Intents 컴파일 확인.
- Simulator lock 해제 후 실제 Shortcuts 경로와 cold/warm launch 확인. Activity 화면의 디자인맵 캡처도 같은 시점에 갱신한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| iOS 27 scene API 세부 시그니처 차이 | 중간 | 빌드 실패 | 설치 SDK generic build로 확인 |
| SwiftData 관계 캐시와 query 불일치 | 중간 | 중복 로그 | 명시적 FetchDescriptor 기반 readback 테스트 |
| CloudKit 기기 간 동시 완료 | 낮음 | 중복 로그 | 로컬 멱등성 범위 명시, 별도 동기화 정책 추후 |
