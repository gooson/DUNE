---
topic: Siri health information queries and grounded explanations
tags: [siri, app-intents, foundation-models, healthkit, design]
date: 2026-10-30
category: plan
status: approved
confidence: medium
related_solutions:
  - ../solutions/architecture/2026-03-09-health-data-qa-tool-calling.md
  - ../solutions/architecture/2026-10-14-ios27-app-intents-swiftdata-routing.md
related_brainstorms:
  - ../brainstorms/2026-10-30-siri-health-queries-xcode-27-2-research.md
---

# Implementation Plan: Siri health information

## Context

사용자가 Siri 조사와 SQ01–SQ14 비주얼 시안을 확인한 뒤 `/run`을 요청했다. 저장된 운동·세트·개인 기록·신체·수면·컨디션을 조회하고 비교·검색·보고서로 이어지는 실제 기능을 구현한다. 고정 예시 수치를 앱에 넣지 않고 기존 SwiftData와 권한 내 HealthKit 데이터를 사용한다.

원본 워크트리의 Live Activity 작업은 제외하고 최신 origin/main 기반 `feature/siri-health-information`에서 진행한다. 조사·시안 25개 파일과 Siri 전용 맵 연결만 가져왔다. 최신 main의 다른 테마·디자인맵 변경은 유지한다.

## Requirements

### Functional

- SQ01 최근 운동, SQ02 기간별 운동량, SQ03 완료한 근력 세트, SQ04 실제 최고 중량, SQ05 유산소 상세를 조회한다.
- SQ06 신체 최신값과 항목별 측정일, SQ07 비교 기간의 신체 변화, SQ08 수면, SQ09 DUNE 컨디션과 기준선 근거를 제공한다.
- SQ10 운동·수면 기간 비교, SQ11 특정 운동과 이전 동일 운동 비교, SQ12 원본 운동 메모 검색을 제공한다.
- SQ13 사용자가 확인한 운동 보고서를 공유하고, SQ14 긴 분석의 조회·설명·취소 상태를 제공한다.
- App Intents는 인증을 요구하고 구조화된 결과·음성 문장·snippet을 반환한다. 대표 shortcuts는 전체 intent 중 자주 쓰는 항목으로 제한한다.
- 기존 Today 건강 Q&A에 정형 조회와 상세 결과 진입을 연결한다. AI를 사용할 수 없어도 명시적 조회는 작동한다.
- Foundation Models의 질문 계획·도구 호출과 결과 설명은 검증된 조회 결과만 사용한다. 앱이 직접 계산한 수치를 모델이 바꾸지 않게 한다.
- 화면에 보이는 운동 엔터티 문맥과 범용 앱 내 검색 진입을 연결한다. 건강 전용 Siri schema를 임의로 만들지 않는다.
- 원본 메모 검색과 Spotlight 의미 검색은 사용 가능한 경로를 명시적으로 구분한다. 민감 정보 인덱싱은 사용자 선택과 보호된 인덱스를 전제로 한다.

### Non-functional

- 날짜·단위·원본 ID·출처·조회 시각을 보존한다. 빈 HealthKit 결과로 권한 거부를 추정하지 않는다.
- HealthKit 읽기와 SwiftData snapshot 투영은 분리한다. 모델 세션은 요청별 격리·취소와 입력/출력 상한을 갖는다.
- 앱의 저장 스키마를 변경하지 않는다. 동일 운동의 로컬/HealthKit 중복을 연결 ID 우선으로 제거한다.
- 영어 키·한국어·일본어 String Catalog를 함께 등록하고 manual extraction·포맷을 빌드 전후 확인한다.
- Siri 시스템 외곽을 앱 UI로 재현하지 않는다. 네이티브 DUNE 응답 카드는 기존 디자인 토큰과 테마를 사용한다.

## Approach

Foundation-only Domain `HealthQueryRequest`/`HealthQueryResult`와 `@MainActor HealthQuerying.execute`를 공유한다. `HealthQueryService`가 앱 초기화 때 실제 container와 shared health service를 받아 읽기 전용 snapshot을 구성한다. Data의 계산/질의는 SwiftData 객체를 async 모델에 전달하지 않는다. UI·intent·AI 도구는 같은 조회 서비스를 호출한다.

결과는 상태·측정값·시계열·기록·출처·음성 요약·제한을 포함한다. 기간은 실제 해석된 DateInterval을 반환하고 기본 최대 366일, 메모/기록 건수 상한을 적용한다. 최고 기록처럼 전 범위를 요구하는 조회는 범위와 절단 여부를 답변에 명시한다. 신체 최신값은 오늘을 제외하는 기존 fallback API를 단독 사용하지 않는다.

Siri 노출은 typed 조회 intent와 자유 질문 intent, 기록 열기/앱 검색으로 구성한다. `requiresLocalDeviceAuthentication`와 protected-data 확인으로 민감 출력을 보호한다. 엔터티 후보 조회에서도 보호 상태를 확인한다. Intent 실행은 main process를 사용하고 cold launch의 app init에서 의존성을 구성한다.

AI 설명은 별도 가용성 상태를 갖는다. 정형 기록을 숨기지 않고 모델 오류·미지원·오프라인·한도에 따라 원래 조회 결과를 유지한다. 27 API는 기존 Xcode 26 CI를 위한 compile guard와 가용성 검사 뒤 사용한다. PCC는 entitlement를 보유했다고 가정하지 않고 실제 availability와 사용자의 클라우드 분석 선택을 검사한다. 임의 entitlement 추가·계정 신청은 하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 기존 QA에 Siri 전달만 추가 | 변경 적음 | 신체·세트·정형 fallback·기간 계약 부족 | 제외 |
| 기능별 독립 질의 서비스 14개 | 단순 개별 구현 | 중복·단위·기간·출처 불일치 | 제외 |
| 공통 읽기 결과 + 얇은 UI/intent/AI 어댑터 | 정확성과 재사용, 의미 있는 테스트 | DTO·초기 통합 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Domain/Models/HealthQuery.swift` | 추가 | 요청·기간·결과·원본 snapshot·단위·상태 |
| `DUNE/Domain/Protocols/HealthQuerying.swift` | 추가 | UI/intent/AI 공통 질의 계약 |
| `DUNE/Data/Services/HealthQueryService*.swift` | 추가 | 실제 데이터 읽기·출처 병합·집계 |
| `DUNE/Data/Services/HealthQueryAssistant*.swift` | 추가 | 질문 계획·도구·모델 가용성·근거 기반 설명 |
| `DUNE/Data/Services/HealthDataQAService.swift` | 수정 | 공통 질의 도구·정형 fallback 연결 |
| `DUNE/App/Intents/Health*.swift`, `DUNEShortcuts.swift` | 추가·수정 | 엔터티·인증·typed 조회·freeform·검색·긴 분석 |
| `DUNE/App/DUNEApp.swift` | 수정 | init/런타임 갱신 의존성·scene 라우팅 |
| `DUNE/App/ContentView.swift` | 수정 | 건강 정보 진입과 외부 요청 연결 |
| `DUNE/Presentation/HealthQuery/*.swift` | 추가 | V2 응답·필터·기록·근거·보고서·설정 |
| 운동 상세의 문맥 annotation | 수정 | 현재 운동 ID를 시스템에 전달 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 영어 키·한국어·일본어 |
| `DUNETests/HealthQuery*Tests.swift` | 추가 | 계산·상태·범위·dedup·질문·가용성 |
| `DUNEUITests/Full/HealthQueryUITests.swift` | 추가 | seeded 주요 기능·상태·실제 화면 수집 |
| `docs/design/` | 추가·수정 | 제안 유지·실제 캡처와 상태 갱신 |

## Implementation Steps

### Step 1: 공통 질의와 실제 데이터

요청/결과 DTO, 명시적 기간 경계, 읽기 서비스, 검증된 snapshot, 연결 ID 기반 중복 정책을 만든다. 각 기능은 빈 결과·부분 실패·잘못된 입력을 사실대로 반환한다. 관련 단위 테스트로 수치/날짜/원본 일치를 확인하고 논리 단위로 커밋한다.

### Step 2: 네이티브 V2 응답과 Siri

공통 결과를 카드·그래프·근거·음성 문장·보고서 미리보기로 표시한다. 앱 소유 화면 내 기록 열기와 비교를 제공한다. typed intent·엔터티·대표 shortcut·화면 문맥을 연결한다. 보호 상태에서는 메모·수치·엔터티 후보를 반환하지 않는다.

### Step 3: 자연어·설명·선택적 검색과 분석

기존 QA에 공통 도구와 자유 질문 계획을 연결한다. 27에서 가능한 Dynamic Profiles/tool-calling 제어와 모델·locale availability를 사용하되 정형 응답 fallback을 유지한다. 의미 검색·PCC는 실제 availability/사용자 설정 조건을 확인하고 미지원 상태를 분명히 표시한다. 긴 작업은 취소와 진행 단계를 제공한다.

### Step 4: 검증과 맵

관련 단위 테스트와 표준 build 스크립트를 실행한다. 영향 UI 테스트 + smoke를 전용 기기에서 직렬 실행한다. iPhone 먼저 검증하고 반응형 화면이 영향받는 iPad·Duo 접힘/펼침의 새 캡처를 수집한다. 실제 화면맵에 이번 코드·기기·상태 출처를 기록한다. 실패는 원인 수정 후 최대 1회 재시도한다.

## Edge Cases

| Case | Handling |
|---|---|
| HealthKit 읽기 거부/빈 결과 | 앱이 알 수 있는 접근 가능한 기록 없음으로 표현 |
| 잠금 상태 | 수치·메모·엔터티 후보 숨김, 잠금 해제 필요 |
| 원본 삭제·중복·tombstone | 실행 때 재조회, exact link ID 우선 |
| 오늘/어제/달력 주간/월간/DST | 주입 가능한 calendar와 now로 DateInterval 해석 |
| 항목별 측정일 다름·stale snapshot | 원본 날짜와 fetchedAt 보존 |
| NaN/음수/단위 오류 | 검증 후 제외, 부분 데이터 사실 표시 |
| 계획 세트·워밍업·bodyweight | 완료한 실제 세트 기준, 수치 부재를 0으로 치환하지 않음 |
| 모델이 다른 수치 생성 | 정형 결과를 원본으로 유지, 설명 검증·fallback |
| 동시 질문·취소·런타임 교체 | 요청별 세션/토큰과 Task cancellation으로 오래된 결과 방지 |
| PCC 미지원·quota·네트워크 | 조회 결과 유지, 클라우드 설명 불가 상태 |
| 검색 상한·과거 기록 절단 | 결과 범위와 제한 명시, 전체 검색 완료로 주장하지 않음 |

## Testing Strategy

- Unit: 기간 경계·입력 상한·숫자 검증·실제 세트/볼륨·PR·중복·tombstone·측정일·부분 실패·취소·수치 grounding·가용성 fallback.
- Integration: in-memory SwiftData와 주입한 HealthKit 프로토콜로 읽기 결과, cold-launch DI, intent 계약을 검사한다. 시스템 AppIntentsTesting은 SDK·서명 조건을 확인하고 지원 경로에서만 실행 증거를 남긴다.
- UI: `HealthQueryUITests`와 관련 Q&A/공통 smoke를 표준 runner로 실행한다. 접근성 anchor, 주요 값·출처·상태·전환·공유 미리보기·취소를 검사한다. 전체 테스트는 명시 요청이 없으므로 자동 확대하지 않는다.
- Visual: 영향받는 새 화면과 실제 값/큰 글씨를 전용 iPhone/iPad/Duo에서 새로 캡처하고 시안과 구분한다. Watch 앱 UI를 변경하지 않으면 Watch mockup은 시안으로 유지한다.
- Localization: formatter/manual 체크 전후, formatter 계약 테스트와 보간 키 확인.
- Build: 실제 설치된 Xcode 27.1로 `scripts/build-ios.sh`; Xcode 27.2 및 실제 한국어 Siri/낭독/PCC entitlement는 미검증 범위를 별도로 명시한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 건강 전용 schema 없음 | 확정 | 자유 발화 연결 제한 | typed shortcuts + 질문 파라미터, 실제 지원 범위 명시 |
| PCC entitlement 없음 | 미확인 | 클라우드 모델 사용 불가 | 조건부 가용성과 정형/온디바이스 fallback |
| Xcode 26 CI와 27 SDK 차이 | 높음 | CI 컴파일 | compiler guards, API명 실 SDK 확인 |
| 큰 범위와 여러 데이터 소스 | 중간 | 정확성·성능 | bounded snapshots·병렬 HK 조회·동일 집계 계약 |
| simulator/HealthKit 환경 | 중간 | 실제 권한·Siri 미검증 | deterministic injected tests와 실제 기기 잔여 항목 구분 |

## Confidence Assessment

- **Overall**: Medium. 기존 QA·snapshot·intent 라우팅은 재사용 가능하다. 최신 Siri 발화·PCC·시스템 snippet 호스트는 배포 기기의 실제 동작 검증이 필요하다.
- `/run` 승인에 따라 계획 승인 대기 없이 구현·검증·리뷰·문서화·Ship를 진행한다.
