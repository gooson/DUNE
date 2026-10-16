---
tags: [ios27, metrickit, statereporting, foundation-models, signpost, privacy]
category: performance
date: 2026-10-14
status: implemented
severity: minor
related_files:
  - DUNE/Data/Services/WorkoutGenerationMetrics.swift
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNE/App/DUNEApp.swift
  - DUNETests/WorkoutGenerationMetricsTests.swift
---

# AI 운동 템플릿 응답 구간의 MetricKit 계측

## Problem

온디바이스 모델 호출의 실기기 응답 시간과 CPU/메모리 비용을 비교할 집계가 없었다. 전체 생성 함수를 감싸면 prompt 준비, 결과 검증, deterministic fallback과 재시도 대기가 모델 응답 시간에 섞인다. 모델 응답에는 운동 요청과 건강 관련 맥락이 있으므로 내용을 telemetry에 전달하면 안 된다.

## Solution

`AIWorkoutTemplateGenerator`의 초기 호출과 재시도 각각에서 prompt를 만든 뒤 `LanguageModelSession.respond`만 `WorkoutGenerationMetrics.measure`로 감싼다. `MetricManager.logHandle(category:)` + `mxSignpost(.begin/.end)`의 SDK 기본 metrics snapshot을 유지해 duration과 optional resource 통계를 활성화한다. category=`AIWorkoutGeneration`, name=`ModelResponse`는 고정이다. 요청·응답·오류 객체·사용자 식별자는 계측 API 인자가 아니다.

각 interval은 고유 `OSSignpostID`를 사용한다. 하나의 고정 StateReporting domain에 `generating` 상태만 기록하고, mutex로 동시 interval 수와 상태 전환을 보호한다. 오류와 취소도 end 처리 후 원래 오류를 전달한다. 마지막 interval이 끝날 때 nil 상태로 복귀한다. stable/volatile metadata는 모두 없고 `StateReporter`는 static으로 보존한다.

앱 init에서 `WorkoutGenerationMetricMonitor`를 보존하며 detached utility Task가 `MetricManager.metricReports`를 소비한다. 테스트 앱에서는 monitor를 생성하지 않는다. manager와 subscription은 앱 수명 동안 유지되고 monitor 해제 시 Task가 취소된다.

### 집계 및 개인정보 계약

- `intervalEntries.fullDayEntry`만 소비해 하위 시간창 및 state entry의 중복 합산을 피한다.
- category와 name이 모두 일치하는 signpost만 보고한다.
- 로그 category `AIWorkoutPerformance`에는 count, duration histogram의 초 단위 경계/count, optional CPU 초, optional 평균 메모리 bytes/sample count만 쓴다.
- raw MetricReport, 진단/stack, 환경 정보, 날짜 범위, 사용자 입력, 생성 내용, HealthKit 값은 직렬화·저장·업로드하지 않는다. 네트워크/파일 수집 경로를 추가하지 않는다.
- CPU/메모리 누락은 0으로 치환하지 않는다. 평균 메모리를 peak나 할당량으로 해석하지 않는다.

### SDK 근거와 검증

설치 SDK는 `iphoneos27.0`이다. MetricKit과 StateReporting의 `arm64e-apple-ios.swiftinterface`를 읽고 실제 `arm64-apple-ios27.0` target으로 Swift 6 strict concurrency typecheck를 수행했다. 공식 문서의 일부 예제와 달리 설치 SDK의 domain 생성자는 `StateReportingDomain(rawValue:)`다.

| 검증 | 결과 |
|------|------|
| 서비스 직접 SDK module emit/typecheck | 통과 |
| FoundationModels `@Generable` 응답을 감싸는 최소 호출 probe | 통과 |
| 새 Swift Testing 테스트 소스 SDK typecheck | 통과, 실행은 미수행 |
| 수정 Swift 파일 frontend parse | 통과 |
| 프로젝트 생성 및 새 소스 등록 | 완료 |
| 독립 정적 검토 | project 등록 P2 수정 |
| 앱 통합 빌드 / focused 테스트 실행 / 실기기 report | 후속 검증 필요 |

테스트 typecheck에는 iPhoneOS 플랫폼의 `Developer/Library/Frameworks`를 `-F`, toolchain의 `usr/lib/swift/host/plugins/testing`을 `-plugin-path`로 지정했다. 테스트는 성공 값 보존, 오류 전파, 실제 Task 취소, 중첩된 interval, 실패 후 재시도의 상태 경계를 검증한다.

공유 호스트 제약으로 Xcode 빌드와 simulator를 실행하지 않는 범위였다. 첫 로컬 커밋에서 pre-commit hook이 full build를 자동 시작하여 즉시 중단(exit 130)했다. 빌드 성공 증거로 사용하지 않는다. 후속 커밋은 저장소의 `DAILVE_SKIP_PRECOMMIT_BUILD=1`을 사용한다.

### 실기기 후속 확인

1. Apple Intelligence를 사용할 수 있는 iOS 27 기기에서 모델 경로를 실행한다. deterministic 경로는 signpost가 없어야 한다.
2. 성공·오류·취소·재시도 시 Instruments에서 interval이 닫히는지 확인한다.
3. 일별 실제 report를 수신한 뒤 `AIWorkoutPerformance` 로그의 count와 duration 분포, 제공되는 CPU/memory 값을 확인한다.
4. Xcode의 simulated MetricKit payload는 report 처리용 가짜 데이터다. 성능 baseline으로 쓰지 않는다.

현재 실제 latency/CPU/memory baseline은 **미측정**이다. 이 값은 MetricKit이 해당 앱 구간에 귀속한 통계이며, 시스템 모델 프로세스와 Neural Engine을 포함한 전체 추론 비용을 보장하지 않는다. StateReporting 상태는 수집하지만 별도의 상태별 합산을 로그에 중복 보고하지 않는다.

## Prevention

- signpost name/category/state에 prompt 또는 식별자를 삽입하지 않는다.
- default metrics snapshot을 일반 signpost/사용자 정의 format으로 대체하기 전에 CPU/memory 수집 영향 확인.
- retry와 fallback 경계를 바꿀 때 interval이 모델 호출만 포함하는지 다시 확인한다.
- 새로운 상태를 추가하기 전에 고정 cardinality와 민감 정보 유입 여부를 검토한다.
- 새 소스는 체크인된 Xcode 프로젝트에도 등록하고, 생성 과정의 무관한 diff는 제외한다.

## Lessons Learned

API 문서의 예제와 설치 SDK 선언이 다를 수 있으므로 실제 compiler로 검증한다. MetricKit 구간 집계는 개선 전후 비교의 수집 기반이며, 정적 typecheck만으로 실기기 성능이나 일별 전달을 확인할 수 없다.

## References

- [Meet the new MetricKit, WWDC26 222](https://developer.apple.com/videos/play/wwdc2026/222/)
- [Monitoring app performance with MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit)
