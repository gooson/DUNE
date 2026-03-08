---
topic: health-data-qa
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
  - docs/solutions/architecture/2026-03-08-on-device-prediction-features.md
  - docs/solutions/architecture/2026-02-24-wellness-readiness-shared-snapshot-parity.md
  - docs/solutions/general/2026-03-02-training-readiness-localization-leak-fix.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md
---

# Implementation Plan: Health Data Q&A

## Context

Today 탭에는 HealthKit 기반 인사이트와 Foundation Models 기반 코칭/리포트 패턴이 이미 존재하지만, 사용자가 자연어로 자신의 건강 데이터를 질문하고 멀티턴으로 후속 질문을 이어갈 수 있는 인터페이스는 없다. TODO 105는 Foundation Models의 Tool Calling과 `LanguageModelSession`을 이용해 HealthKit/Shared Snapshot 데이터를 안전하게 요약하고 질의응답하는 기능을 요구한다.

## Requirements

### Functional

- Today 탭에서 건강 데이터 Q&A를 시작할 수 있는 사용자 진입점이 있어야 한다.
- Foundation Models 지원 기기에서는 `LanguageModelSession` 기반 멀티턴 대화를 유지해야 한다.
- Tool Calling으로 건강 데이터 조회를 수행하되, raw HealthKit dump 대신 사전 집계된 요약을 반환해야 한다.
- 최소한 readiness/condition, sleep, recent workouts/recovery 요인을 질문에 답할 수 있어야 한다.
- Foundation Models 미지원 기기 또는 추론 실패 시 graceful fallback을 제공해야 한다.

### Non-functional

- `FoundationModels` import는 Domain이 아닌 Data/Presentation에만 둔다.
- 4096 토큰 제약을 고려해 세션 기본 컨텍스트와 tool 출력은 compact summary로 제한한다.
- UI 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja를 모두 반영한다.
- 새 로직에는 Swift Testing 기반 단위 테스트를 추가한다.
- XcodeGen 재생성 없이도 신규 Swift 파일이 `DUNE/project.yml`의 recursive source rule로 포함되어야 한다.

## Approach

Today 탭 Dashboard에 작은 Q&A 진입점을 추가하고, 실제 Foundation Models 통합은 Data 레이어의 신규 서비스가 담당한다. 서비스는 `SharedHealthDataService`와 기존 HealthKit query service를 조합해 compact summary를 만들고, Tool protocol 기반 도구를 `LanguageModelSession(model:tools:instructions:)`에 주입한다. Presentation에는 별도 session view model을 두어 메시지 상태, in-flight 요청, 멀티턴 transcript 생명주기를 관리한다.

핵심 설계 포인트:

- 기본 컨텍스트는 `SharedHealthSnapshot`에서 추출한 compact baseline summary로 시작한다.
- 세부 데이터는 tool 호출로만 조회해 토큰 낭비를 줄인다.
- 답변 프롬프트에는 "의료 진단이 아닌 정보성 설명", "앱 데이터 밖의 추정 금지", "데이터 없음 명시"를 포함한다.
- 서비스 availability/failure는 기존 `AICoachingMessageService` 패턴처럼 조기 fallback으로 처리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Backend-only service만 구현 | UI 범위가 작고 빠름 | TODO의 "사용자가 질문" 플로우가 미완성 | Reject |
| Dashboard Today 탭에 sheet 기반 Q&A 추가 | 기존 shared snapshot 주입과 FM 패턴 재사용 가능, 범위가 작음 | 새 sheet/view model/UI 문자열이 필요 | Accept |
| Wellness/Activity 전역 챗봇으로 확장 | 장기적으로 더 풍부함 | 범위가 커지고 리뷰/테스트 비용 급증 | Reject |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Protocols/HealthDataQuestionAnswering.swift` | add | Q&A 서비스 추상화 및 응답 모델 정의 |
| `DUNE/Data/Services/HealthDataQAService.swift` | add | Foundation Models session 생성, instructions, tool registration, fallback 처리 |
| `DUNE/Data/Services/HealthDataQATools.swift` | add | readiness/sleep/workout/recovery 요약 tool 정의 |
| `DUNE/Presentation/Dashboard/HealthDataQAViewModel.swift` | add | 멀티턴 메시지 상태, send/cancel, availability 노출 |
| `DUNE/Presentation/Dashboard/Components/HealthDataQACard.swift` | add | Today 탭 진입 카드 또는 CTA UI |
| `DUNE/Presentation/Dashboard/HealthDataQASheet.swift` | add | 대화 UI와 입력창, message list |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | Today 탭에서 Q&A sheet 진입점 연결 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | update | 필요 시 availability/entry copy 또는 shared service 전달 정리 |
| `DUNETests/HealthDataQAServiceTests.swift` | add | compact context/tool output/fallback 테스트 |
| `DUNETests/HealthDataQAViewModelTests.swift` | add | 멀티턴 상태 전이, 에러/중복 전송 가드 테스트 |
| `Shared/Resources/Localizable.xcstrings` | update | 신규 Today/Q&A UI 문자열 3개 언어 추가 |

## Implementation Steps

### Step 1: Service contract와 compact health context 구성

- **Files**: `DUNE/Domain/Protocols/HealthDataQuestionAnswering.swift`, `DUNE/Data/Services/HealthDataQAService.swift`, `DUNE/Data/Services/HealthDataQATools.swift`
- **Changes**:
  - Domain 프로토콜과 request/response/message 모델 추가
  - `SharedHealthSnapshot`, `SleepQuerying`, `WorkoutQuerying`, `HRVQuerying`를 묶어 tool-friendly summary 생성
  - `SystemLanguageModel.default.isAvailable` 체크, default instructions, response token limit 설정
  - `Tool` protocol을 사용하는 readiness/sleep/workout/recovery summary 도구 구현
- **Verification**:
  - 서비스 단위 테스트에서 compact prompt/tool summary 내용 검증
  - simulator 환경에서 fallback 경로가 deterministic하게 동작하는지 확인

### Step 2: Today 탭 Q&A UI와 멀티턴 session state 연결

- **Files**: `DUNE/Presentation/Dashboard/HealthDataQAViewModel.swift`, `DUNE/Presentation/Dashboard/Components/HealthDataQACard.swift`, `DUNE/Presentation/Dashboard/HealthDataQASheet.swift`, `DUNE/Presentation/Dashboard/DashboardView.swift`
- **Changes**:
  - Dashboard에서 sheet를 열 수 있는 CTA 추가
  - view model이 session lifetime, user/assistant message list, in-flight state, empty/error 상태를 관리
  - 중복 전송/빈 질문 가드, response race 방지, model unavailable 안내 copy 추가
  - sharedHealthDataService 기반으로 질문 세션을 초기화
- **Verification**:
  - view model 테스트로 send success/failure/busy state 검증
  - Today 탭에서 sheet 진입과 dismiss가 빌드 가능한지 확인

### Step 3: Localization, 테스트, 빌드 안정화

- **Files**: `Shared/Resources/Localizable.xcstrings`, `DUNETests/HealthDataQAServiceTests.swift`, `DUNETests/HealthDataQAViewModelTests.swift`
- **Changes**:
  - 신규 사용자 대면 문자열의 en/ko/ja 카탈로그 추가
  - Tool output이 과도하게 길어지지 않도록 summary 길이 제한 테스트 추가
  - view model의 concurrent send, unavailable fallback, empty data response 테스트 추가
- **Verification**:
  - `scripts/build-ios.sh`
  - `scripts/test-unit.sh --ios-only`

## Edge Cases

| Case | Handling |
|------|----------|
| Foundation Models 미지원 기기 | CTA 비활성/보조 설명 또는 fallback 응답으로 graceful degrade |
| Shared snapshot만 존재하고 HealthKit live query 불가 | snapshot 기반 요약만 사용하고 누락 데이터는 명시 |
| Health data가 비어 있음 | 도구가 빈 요약 대신 "no data yet" 형태의 compact summary 반환 |
| 사용자가 의학적 진단을 요구 | instructions에서 진단 금지, 앱 데이터 기반 정보성 답변으로 제한 |
| 사용자가 매우 긴 질문/연속 질문 | response token limit과 compact transcript 유지, 필요 시 질문 재요청 |
| 연속 탭 전환/시트 dismiss 중 응답 완료 | view model이 cancel-before-spawn 및 stale result guard로 무시 |

## Testing Strategy

- Unit tests:
  - `HealthDataQAServiceTests`에서 availability fallback, base context formatting, tool summary 압축, missing data copy 검증
  - `HealthDataQAViewModelTests`에서 send lifecycle, duplicate send guard, error state, message append 순서 검증
- Integration tests:
  - `scripts/test-unit.sh --ios-only`
- Manual verification:
  - A17 Pro+ 실기기에서 Today 탭 Q&A 진입 → 질문 2회 연속 → follow-up 질문으로 멀티턴 유지 확인
  - HealthKit 미허용/미지원 환경에서 안내 copy와 non-crash fallback 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Tool protocol 구현 시 SDK 시그니처 오해 | Medium | High | iOS 26.2 `FoundationModels.swiftinterface` 기준으로 구현 후 `swiftc`/build 검증 |
| 토큰 예산 초과로 응답 품질 저하 | Medium | Medium | base context를 compact summary로 유지하고 세부 데이터는 tool 호출로 분리 |
| Today 탭 UI 범위가 예상보다 커짐 | Medium | Medium | sheet + simple message list MVP로 제한, rich chat polish는 제외 |
| localization 누락 | Medium | High | `localization.md` 체크리스트와 xcstrings 동시 수정 |
| 시뮬레이터에서 FM 미지원이라 실제 tool-calling 동작 검증 부족 | High | Medium | fallback/unit tests로 회귀를 잠그고, manual device verification을 명시 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 코드베이스에 Foundation Models fallback 패턴과 shared snapshot 아키텍처가 이미 있어 재사용성은 높다. 다만 Tool Calling 기반 멀티턴 session은 신규 경로이므로 SDK 시그니처와 실기기 동작을 빌드/테스트/수동 검증으로 함께 잠가야 한다.
