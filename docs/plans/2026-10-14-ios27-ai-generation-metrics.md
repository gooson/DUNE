---
tags: [ios27, metrickit, statereporting, foundation-models, privacy]
date: 2026-10-14
category: plan
status: approved
---

# PR10: AI 운동 템플릿 생성 성능 계측

## Context

실기기에서 AI 운동 템플릿 생성의 응답 시간 분포와 CPU/메모리 비용을 파악한다. 기준 커밋은 PR9 `5c41c1e2`다. 설치된 iPhoneOS 27.0 SDK에서 `MetricManager`, `mxSignpost`, `StateReporter` 시그니처를 확인했다.

## Approach

초기 호출과 재시도의 `LanguageModelSession.respond`를 각각 같은 고정 signpost로 감싼다. prompt 준비·결과 변환·fallback·재시도 대기는 측정에서 제외한다. 고유 signpost ID는 동시 요청을 구분하며, StateReporting은 진행 중인 호출 수가 0→1/1→0일 때만 `generating`/nil로 전환한다. 메타데이터를 받지 않는다.

앱 init에서 보존한 서비스가 MetricManager를 유지하고 백그라운드 Task로 report를 소비한다. 하루 집계의 해당 signpost만 허용하며 duration histogram, count, optional CPU/average memory 숫자만 로컬 로그에 보고한다. raw report, 환경 정보, 진단, prompt, 생성 내용, HealthKit 값, 사용자 식별자는 저장하거나 업로드하지 않는다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Data/Services/WorkoutGenerationMetrics.swift | Add | signpost/state 수명과 집계 소비 |
| DUNE/Data/Services/AIWorkoutTemplateGenerator.swift | Modify | 두 respond 호출 경계 |
| DUNE/App/DUNEApp.swift | Modify | 앱 수명 구독, 테스트에서는 구독 제외 |
| DUNETests/WorkoutGenerationMetricsTests.swift | Add | 성공/오류/취소/겹치는 구간 상태 회복 |
| docs/solutions/performance/2026-10-14-ai-generation-metrickit.md | Add | SDK 근거, 수집 계약, 검증 한계 |

## Implementation Steps

1. SDK 시그니처와 공식 문서로 API 및 일별 집계 경계를 확인한다.
2. 개인정보를 인자로 받지 않는 계측 및 report 소비를 구현한다.
3. 두 respond 경계와 앱 init에 연결한다.
4. Swift 6 SDK typecheck, 구문 검사, diff/privacy 검토와 focused 테스트 소스를 작성한다.
5. 검토 및 compound 후 로컬 커밋한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 오류/취소 | end signpost 및 nil 상태를 보장하고 원래 오류 전파 |
| 동시 호출 | 고유 ID, 잠금 안에서 active count와 상태 변경 |
| retry | 첫 구간 종료 후 새 구간 시작, backoff 제외 |
| 자원 통계 없음 | 누락을 0으로 오인하지 않음 |
| visionOS 공유 소스 | iOS 전용 conditional compilation |

## Testing Strategy

직접 swiftc typecheck와 정적 검토만 실행한다. 공유 호스트 작업 때문에 Xcode, xcodebuild, simulator 실행을 하지 않는다. focused Swift Testing suite 실행, 앱 통합 빌드, 실기기 일별 report 및 CPU/memory 정확성 검증은 부모 작업의 후속 게이트로 남긴다. UI/문구/화면 변경이 없어 UI 게이트와 디자인맵 갱신은 해당 없음이다.

## References

- https://developer.apple.com/videos/play/wwdc2026/222/
- https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit
