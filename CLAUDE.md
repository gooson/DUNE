# Compound Engineering Workspace

> 이 프로젝트는 Compound Engineering 방법론을 따릅니다.
> 모든 작업은 다음 루프를 통해 개선됩니다: Plan -> Work -> Review -> Compound

## Project Overview

- **Type**: iOS Health & Fitness App (HRV/RHR 기반 컨디션 분석)
- **Stack**: Swift 6 / SwiftUI / HealthKit / SwiftData / CloudKit
- **Target**: iOS 26+
- **Status**: Active Development (MVP)

## Core Principles

1. **Compound over Linear**: 모든 작업이 다음 작업을 더 쉽게 만들어야 합니다
2. **Plan First**: 코딩보다 계획에 80%의 시간을 투자합니다
3. **Document Solutions**: 해결된 문제는 docs/solutions/에 기록하여 미래에 재사용합니다
4. **Review Multi-Perspective**: 코드 리뷰는 6개 이상의 관점에서 수행합니다
5. **Accumulate Knowledge**: 교정 사항은 이 파일에 추가하여 같은 실수를 반복하지 않습니다

## Engineering Discipline

<!-- Based on: https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md -->

1. **Surface Uncertainty**: 불확실하면 멈추고 가정을 명시한다. 해석이 여럿이면 선택지를 제시하고 조용히 고르지 않는다
2. **Push Back**: 더 단순한 구현이 있으면 제안한다. 과잉 설계보다 반론이 낫다
3. **Surgical Scope**: 변경은 요청 범위만. 인접 코드, 주석, 포맷을 개선하지 않는다
4. **Own Your Cleanup**: 내 변경으로 불필요해진 것만 정리한다. 기존 dead code는 mention만 하고 삭제하지 않는다
5. **Verifiable Goals**: 작업을 검증 가능한 목표로 변환한다. "동작하게" 대신 구체적 성공 기준을 정의한다

## Session Workflow

새 세션을 시작할 때:
1. 이 파일과 .claude/rules/ 를 읽습니다
2. docs/solutions/ 에서 관련 과거 해결책을 검색합니다
3. todos/ 에서 현재 작업 항목을 확인합니다
4. 작업 유형에 따라 적절한 skill을 사용합니다

## Fidelity Levels

| Level | 설명 | 워크플로우 |
|-------|------|-----------|
| F1 | 단순 변경 (오타, 1줄 수정) | 직접 수정 |
| F2 | 중간 변경 (명확한 범위, 여러 파일) | /plan -> /work |
| F3 | 복잡한 변경 (불확실, 아키텍처) | /brainstorm -> /plan -> /work -> /review -> /compound |

## Available Skills

| Skill | Purpose | Trigger |
|-------|---------|---------|
| /brainstorm | 요구사항 명확화 | 아이디어가 모호할 때 |
| /plan | 구현 계획 생성 | 기능 구현 전 |
| /work | 4단계 실행 (Setup->Implement->QC->Ship) | 코드 작성할 때 |
| /review | 6관점 코드 리뷰 | PR 전 또는 코드 변경 후 |
| /compound | 해결책 문서화 | 문제 해결 후 |
| /triage | 리뷰 결과 분류 | /review 후 |
| /lfg | 전체 파이프라인 자동화 | 기능 전체 구현 |
| /changelog | 릴리스 노트 생성 | 릴리스 전 |
| /onboard | 프로젝트 온보딩 | 새 팀원/세션 |
| /retrospective | 세션 회고 + 학습 | 작업 완료 후 |
| /debug | 구조화된 디버깅 | 버그 발생 시 |

## Review Agents

코드 리뷰 시 다음 전문가 관점에서 분석합니다:
- **Security Sentinel**: OWASP, 인증, 주입 공격, 비밀 노출
- **Performance Oracle**: N+1 쿼리, 캐싱, 메모리 누수, 알고리즘 복잡도
- **Architecture Strategist**: SOLID, 패턴 일관성, 결합도/응집도, 확장성
- **Data Integrity Guardian**: 유효성 검증, 트랜잭션, 레이스 컨디션
- **Code Simplicity Reviewer**: 과잉 설계, 불필요한 추상화, 가독성, dead code
- **Agent-Native Reviewer**: 프롬프트 품질, 컨텍스트 관리, 도구 사용, 에러 복구

## TODO System

파일명 규칙: `NNN-STATUS-PRIORITY-description.md`
- STATUS: pending, ready, in-progress, done
- PRIORITY: p1 (critical), p2 (important), p3 (minor)
- 예시: `001-ready-p1-fix-auth-bypass.md`

## Conventions

### Code
- See .claude/rules/ for detailed conventions
- See .claude/skills/code-style/ for language-specific patterns

### Documentation
- 한국어로 문서 작성, 코드와 기술 용어는 영어 유지
- 날짜 형식: YYYY-MM-DD
- 파일명: kebab-case

### Git
- Branch naming: feature/{topic}, fix/{topic}, refactor/{topic}
- Commit messages: conventional commits (feat:, fix:, refactor:, docs:, test:)
- PR은 /lfg 또는 /work 를 통해 생성

## Compounding Mechanisms

시스템이 스스로 개선되는 5가지 경로:
1. **Agent Memory**: 리뷰 에이전트가 `memory: project`로 프로젝트별 패턴을 학습
2. **Solution Docs**: `/compound`로 해결된 문제가 `docs/solutions/`에 축적
3. **Correction Log**: `/retrospective`가 이 파일에 교정사항 추가
4. **Rules 축적**: 반복 패턴이 `.claude/rules/`로 승격
5. **Domain Skills 성장**: 프로젝트 진행에 따라 skills가 구체화

## Correction Log

> 아래는 이전 작업에서 발견된 교정 사항입니다. 새 세션에서 동일 실수를 반복하지 않도록 합니다.

<!-- 교정 사항은 /retrospective 실행 시 자동으로 추가됩니다 -->
<!-- 형식: ### YYYY-MM-DD: [교정 내용] -->

### 2026-02-15: MVP 초기 구현 리뷰 교정

1. **Domain 레이어에 SwiftUI import 금지**: `ConditionScore` 등 Domain 모델에 `Color` 프로퍼티를 넣으면 `import SwiftUI` 필요. Presentation의 Extension으로 분리할 것 (`{Type}+View.swift`)
2. **ViewModel에 ModelContext 전달 금지**: ViewModel은 `createValidatedRecord() -> Record?` 패턴으로 검증+생성만 담당. View의 `@Environment(\.modelContext)`가 insert/delete 수행
3. **사용자 입력은 항상 범위 검증**: SwiftData + CloudKit 환경에서 잘못된 데이터는 전 디바이스에 전파됨. 숫자 입력은 반드시 min/max 범위 체크
4. **수학 함수 입력 도메인 검증**: `log()`, `sqrt()` 호출 전 입력값 > 0 확인. 결과의 `isNaN`, `isInfinite` 체크
5. **HealthKit 쿼리 병렬화**: 독립 쿼리 2-3개는 `async let`, 4개+는 `withThrowingTaskGroup`. for 루프 내 await 금지
6. **저장 버튼 idempotency**: `isSaving` 플래그로 중복 탭 방지

### 2026-02-16: Triage 수정사항 교정

7. **ViewModel에서 `import SwiftUI` 금지**: `@Observable`은 `import Observation`으로 충분. SwiftUI import는 ViewModel이 UI 타입에 접근 가능하게 만들어 레이어 경계 위반
8. **Computed property 캐싱**: 정렬/필터 포함 computed property가 SwiftUI body에서 반복 접근되면 `private(set) var` + `didSet { invalidateCache() }` 패턴으로 캐싱
9. **공통 검증 로직 DRY**: 동일 검증(`selectedDate.isFuture`)이 2곳 이상이면 Extension으로 추출. 위치: `Presentation/Shared/Extensions/`
10. **sizeClass 기반 View 분기 안정화**: `@Environment(\.horizontalSizeClass)` 값으로 View 트리를 분기할 때, `@State`로 초기값 캡처하여 iPad multitasking 전환 시 View 재생성 방지
11. **mutation 메서드에 isSaving guard 통일**: `createValidatedRecord`뿐 아니라 `applyUpdate` 등 모든 저장/수정 메서드에 `guard !isSaving` 적용
12. **selectedDate 변경 시 validationError 클리어**: `didSet { validationError = nil }`로 stale error 메시지 방지

### 2026-02-16: /plan 워크플로우 교정

13. **Task 에이전트 리서치 scope 제한**: general-purpose 에이전트에 8개+ 질문 금지. 3개 이하로 제한하고, 코드베이스 내 정보로 충분하면 외부 검색 생략
14. **플랜 파일 생성 후 즉시 경로 안내**: 파일 생성 → 절대 경로 출력 → 요약 → 승인 순서. 사용자가 기다리지 않도록
15. **80% 품질 + 빠른 전달 > 100% 품질 + 느린 전달**: 리서치 완벽주의 금지. 코드베이스 분석 + 기존 지식으로 충분한 경우 외부 검색 생략

### 2026-02-16: 6-관점 리뷰 수정 교정

16. **Cancel-before-spawn 필수**: `triggerReload()` 등 Task 재실행 시 `reloadTask?.cancel()` 후 새 Task 할당. 이전 Task가 stale 데이터를 반영하는 것 방지
17. **isLoading 리셋 전 Task.isCancelled 검사**: 취소된 Task가 `isLoading = false`로 리셋하면 현재 진행 중인 로드의 표시가 사라짐. `guard !Task.isCancelled` 후 state 업데이트
18. **나눗셈 결과 이중 검증**: 분모 != 0 체크만으로 부족 — 중간 계산값(m, b)과 최종값(y1, y2) 모두 `.isNaN && .isInfinite` 검사
19. **Deprecated API 즉시 교체**: Xcode warning 0 정책. `HKWorkout.totalEnergyBurned` → `statistics(for:).sumQuantity()` 등 deprecated는 발견 즉시 수정
20. **Domain에 DateFormatter 금지**: `TimePeriod.rangeLabel` 같은 locale-specific 포맷팅은 `Presentation/Shared/Extensions/{Type}+View.swift`로 분리
21. **Force-unwrap은 `Calendar.date(byAdding:)` 등에도 금지**: 실패 확률이 극히 낮더라도 `?? fallback` 사용. 방어 코딩 원칙 우선

### 2026-02-16: 리뷰 적용 교정

22. **HealthKit 값 범위 검증 필수**: Weight(0-500kg), BMI(0-100), HR(20-300bpm) 등 도메인별 범위 guard. 센서 오류/수동 입력 오류 값이 UI에 노출되면 신뢰도 하락
23. **동일 데이터의 모든 쿼리 경로에서 동일 검증**: `fetchBMI(for:)`와 `fetchLatestBMI`처럼 같은 데이터의 다른 접근 메서드는 동일한 값 검증 수준 유지
24. **historical fallback 시 change 계산 스킵**: 3일 전 데이터로 어제와의 차이를 보여주는 것은 의미 없음. `isHistorical == true`이면 `change = nil`
25. **parallel fetch에 partial failure 보고 필수**: async let 4개+ 사용 시 실패 카운트를 추적하여 "Some data could not be loaded (N of M sources)" 형태로 사용자에게 안내
26. **Hashable 구현 시 == 와 hash 일치 필수**: `==`에서 비교하는 프로퍼티와 `hash(into:)`에 combine하는 프로퍼티가 동일해야 함. 불일치 시 Dictionary/Set에서 예측 불가 동작
27. **리뷰 적용은 파일별 batch**: 6관점 리뷰 결과를 파일별로 병합 후 한 번에 적용. 중간 빌드 없이 최종 1회 빌드+테스트로 검증

### 2026-02-17: Chart UX 레이아웃 안정성 교정

28. **차트 selection info는 VStack 삽입 금지**: 조건부 VStack 자식은 레이아웃 시프트 유발. `.overlay(alignment: .top)` + `.ultraThinMaterial` 패턴 사용
29. **차트 period 전환은 `.id()` + `.transition(.opacity)`**: Spring 애니메이션은 데이터 차트에 부적합. `.id()`로 뷰 교체하면 `@State` 자동 리셋 + crossfade 효과
30. **데이터 종속 UI는 항상 렌더 + placeholder**: `if let data { stats }` 대신 `stats(data ?? "—")` 패턴으로 레이아웃 안정성 확보. `Text(" ")` 대신 `.frame(minHeight:)` 사용
31. **중복 차트 UI는 공통 컴포넌트 추출**: 4개 이상 차트에서 동일 패턴 반복 시 `Shared/Charts/` 에 공통 View 생성 (예: `ChartSelectionOverlay`)

### 2026-02-17: Activity Tab 리뷰 및 CloudKit 교정

32. **CloudKit @Relationship은 반드시 Optional**: `[Type]` 아닌 `[Type]?`으로 선언. non-optional relationship은 두 번째 앱 실행부터 `ModelContainer` fatal crash 유발
33. **@Model 스키마 변경 후 2회 실행 테스트**: 첫 실행은 로컬 스토어만 생성되어 통과. CloudKit 스키마 검증은 두 번째 실행에서 발생
34. **새 필드 추가 시 전체 파이프라인 점검**: EditableSet(입력) → ViewModel(검증) → WorkoutSet(저장) → View(표시)까지 모든 경로 확인
35. **JSON 파싱 서비스는 싱글턴 사용**: 번들 JSON을 매번 파싱하면 메모리/CPU 낭비. `static let shared` 패턴 적용
36. **rawValue를 UI에 직접 표시 금지**: `rawValue.capitalized` 대신 `Presentation/Shared/Extensions/{Type}+View.swift`에 `displayName` computed property 사용
37. **동일 로직 3곳 이상 중복 시 즉시 추출**: Collection extension 또는 공통 함수로 DRY 적용. 2곳은 허용, 3곳부터 필수

### 2026-02-17: 2차 리뷰 검증 강화 교정

38. **문자열→숫자 변환 전 trim+isEmpty 필수**: `Int("")`은 nil 반환하므로 optional binding 실패 시 "비어있으면 skip" 분기가 validation을 우회함. `.trimmingCharacters(in: .whitespaces)` 후 `!trimmed.isEmpty` 먼저 체크
39. **`defer`로 isSaving 리셋 금지**: 반환값이 있는 함수에서 `defer { isSaving = false }`를 사용하면 record가 caller에게 전달된 후 insert 전에 flag가 리셋됨. 명시적으로 return 직전에 리셋
40. **CloudKit inverse relationship 명시적 설정**: `workoutSet.exerciseRecord = record` — SwiftData가 자동 처리하지만 CloudKit sync 경로에서는 타이밍 이슈 가능. 방어적 코딩
41. **정수 곱셈 결과 overflow 검증**: `mins * 60` 등 단위 변환 시 `result / divisor == original` 패턴으로 overflow 확인
42. **도메인 서비스도 자체 입력 범위 검증**: caller의 검증을 신뢰하지 않음. MET(0-30), weight(0-500), duration(0-28800s) 등 물리적 한계 기반 guard

### 2026-02-17: 6-관점 리뷰 전체 수정 교정

43. **`isSaving` 리셋은 View에서 insert 완료 후**: `createValidatedRecord()` → View에서 `modelContext.insert(record)` → `viewModel.didFinishSaving()`순서. ViewModel 내부에서 리셋 금지
44. **방어 코드도 비즈니스 로직 고려**: `guard !records.isEmpty else { return nil }`이 첫 사용자(모든 근육 회복 상태) 시나리오를 깨뜨림. 테스트로 검증 후 적용
45. **Collection extension에서 `Swift.max()` 명시적 호출**: `max()` global function이 `Collection.max()` instance method와 이름 충돌. `Swift.max(a, b)` 로 모듈 지정 필수
46. **Watch `isReachable`은 cached state 대신 computed property**: `WCSession.default.isReachable` 직접 조회로 stale state 방지. `sessionReachabilityDidChange`에서 캐시 업데이트 불필요
47. **`.onChange(of: array)` 대신 `.onChange(of: array.count)`**: 전체 배열 비교는 O(n). 변경 감지가 count 레벨로 충분하면 count 사용으로 비용 감소

### 2026-02-17: Wellness 탭 통합 리뷰 교정

48. **`.navigationDestination(for:)`은 조건 블록 밖에 배치**: `if hasData { ... .navigationDestination(for:) }` 패턴은 조건이 false일 때 navigation routing 불가. `body` 최상위에 배치 필수
49. **Push 자식 뷰의 sheet은 자체 `@State` 사용**: 부모 ViewModel의 `isShowingEditSheet`을 자식에서도 bind하면 back navigation 시 양쪽에서 sheet 표시 시도. 자식은 독립 `@State` 사용
50. **CloudKit 삭제는 반드시 확인 다이얼로그**: `modelContext.delete()` 전에 `.alert()` 또는 `.confirmationDialog()` 필수. 전 디바이스 전파되므로 실수 복구 불가
51. **비교 데이터(change indicator)에 유효 기간 threshold**: 7일 전 비교 데이터가 실제로 90일 전이면 오해 유발. `comparisonWindowDays` 상수로 최대 허용 범위 제한
52. **computed property가 merge 로직 포함 시 `@State` 캐싱**: `bodyItems`처럼 두 데이터 소스를 합치는 computed property는 렌더마다 재계산. `@State` + `onChange(of: count)` 무효화 패턴 사용
53. **탭 통합 시 dead code 즉시 삭제**: 기존 뷰 파일을 "참고용"으로 남기면 유지보수 비용만 증가. 통합 완료 후 리뷰 단계에서 삭제

### 2026-02-17: 세션 회고 교정 (프로세스)

54. **`/ship`에서 머지 전략은 `--merge` 기본**: squash는 커밋 이력을 소실시킴. 사용자가 명시적으로 요청하지 않는 한 `--merge` 사용
55. **리뷰 수정 시 dead code 삭제를 별도 단계로 분리하지 않음**: 리뷰에서 발견된 dead code는 같은 fix 커밋에서 삭제. 별도 TODO로 미루면 잊혀짐
56. **BodyCompositionViewModel에 `errorMessage` 없음 확인 후 코딩**: 기존 VM의 프로퍼티 존재 여부를 빌드 전에 grep으로 확인. 빌드 실패 후 수정보다 사전 확인이 효율적

### 2026-02-18: Watch Navigation 상태 전환 교정

57. **`NavigationStack(path:)` 필수 — 외부 상태로 root 전환 시**: `if/else`로 root view를 바꿔도 push된 child view는 stack에 남음. `NavigationPath`를 명시적으로 초기화해야 pop
58. **`sheet(item:)` 바인딩 타입에 `Hashable` 필수**: `Identifiable`만으로 부족. SwiftUI 값 변경 감지에 `Equatable`(`Hashable` 포함) 필요
59. **`@State` 데이터 보호 — `onDisappear` safety net**: 비정상 dismiss 시 `@State` 데이터 유실은 silent failure. `onDisappear`에서 미저장 데이터 전송, 정상 경로에서 데이터 비워 중복 방지
60. **`onChange` 감시 범위 최소화**: `nil → non-nil` 등 특정 전환만 트리거. 모든 변경에 반응하면 운동 종료 시 불필요한 navigation 리셋 등 side effect 유발
61. **Navigation routing은 enum 사용**: `NavigationLink(value: String)` 금지. `WatchRoute` enum으로 type-safe routing. 단일 destination이라도 enum으로 시작

### 2026-02-18: HealthKit Dedup 리뷰 교정

62. **Domain 모델에 인프라 문자열 금지**: `sourceBundleIdentifier: String?`처럼 HealthKit/시스템 문자열을 Domain에 노출하지 않음. Data 레이어에서 의미 있는 타입(`isFromThisApp: Bool`)으로 해소 후 Domain에 전달
63. **Dedup 필터에서 빈 문자열 ID 방어**: `compactMap`으로 ID를 수집할 때 `!id.isEmpty` 검증 필수. `healthKitWorkoutID = ""`인 corrupted record가 모든 빈 ID 워크아웃과 false-positive 매칭
64. **ViewModifier 추출은 복잡도 높으면 2곳부터**: 기존 규칙(#37)은 3곳부터 추출이지만, `modelContext.save()` + stale reference guard 등 복잡한 로직은 2곳 중복에서도 ViewModifier로 추출. 복잡도가 높을수록 DRY threshold를 낮춤

### 2026-02-18: Exercise 탭 리뷰 + 크래시 교정

65. **`modelContext.delete()`는 반드시 `withAnimation {}` 래핑**: `@Query` + `List`/`ForEach` 조합에서 delete가 `UICollectionView` 내부 item count와 불일치하면 `NSInternalInconsistencyException` crash. `withAnimation { modelContext.delete(record) }`로 SwiftUI가 diff를 올바르게 처리하도록 보장
66. **`.swipeActions`의 `Button(role: .destructive)` 금지 (확인 필요 시)**: `role: .destructive`를 사용하면 SwiftUI가 자동으로 row 제거 애니메이션 실행 — alert 표시 전에 아이템이 사라짐. 삭제 확인 dialog가 필요한 경우 `Button { ... }.tint(.red)` 사용
67. **HK ID 캡처 → SwiftData 삭제 → HK 삭제 순서**: `modelContext.delete(record)` 이후 record 프로퍼티 접근 불가. `let hkWorkoutID = record.healthKitWorkoutID`로 사전 캡처 후 삭제 실행, HK cleanup은 fire-and-forget `Task`
68. **ForEach 내 O(N) lookup 금지**: `manualRecords.first(where:)`은 ForEach body에서 매 row마다 O(N) 탐색. `@State private var recordsByID: [UUID: Record] = [:]` Dictionary 캐시 + `rebuildRecordIndex()` 패턴으로 O(1) 접근
69. **Watch DTO 필드 추가 시 양쪽 target 동기화**: `WatchExerciseInfo`가 iOS(`WatchSessionManager`)와 Watch(`WatchConnectivityManager`)에 중복 존재. 필드 추가 시 양쪽 모두 동일하게 반영. 향후 shared package 통합 필요
70. **Swift Charts `.clipped()` 필수**: `AreaMark` gradient가 chart frame 바깥으로 overflow 가능. `.frame(height:)` 다음에 `.clipped()` 항상 추가
71. **`modelContext.save()` 명시적 호출 지양**: SwiftData auto-save가 기본 동작. 명시적 `save()`는 `@Query` 타이밍과 충돌 가능. `withAnimation { delete }` 후 auto-save에 위임

### 2026-02-18: Watch/iOS 리뷰 P1~P3 일괄 수정 교정

72. **Watch 입력도 iOS와 동일 수준 검증**: `WorkoutManager.completeSet()`에서 weight 0-500, reps 0-1000 범위 검증 필수. WatchConnectivity 전송 전 마지막 방어선
73. **Cross-VM static 프로퍼티 참조 금지**: `ViewModelA.defaultX`를 다른 View에서 참조하면 불필요한 ViewModel 의존. 공유 상수는 `WorkoutDefaults` 같은 중립 enum으로 추출
74. **SwiftUI sheet 이중 트리거 방지**: `showSheet = true`가 여러 경로(onAppear + completion handler)에서 동시 호출 가능하면 `pendingSheet` @State + `onChange(of:)` 패턴으로 한 프레임 지연
75. **UserDefaults ID 캐시는 garbage collection 필수**: 삭제된 엔티티의 ID가 UserDefaults에 남으면 maxEntries를 점유. 읽기 시점에 현재 유효 ID와 대조하여 stale 키 정리
76. **UserDefaults key에 bundle identifier prefix**: 테스트/프로덕션 환경 격리를 위해 `Bundle.main.bundleIdentifier`를 key prefix로 사용

### 2026-02-19: Enhanced Workout Display 리뷰 교정

77. **`throws` 함수에서 silent `guard...return` 금지**: Service 레이어의 `throws` 함수가 `guard ... else { return }` 으로 실패를 삼키면 caller가 성공/실패 구분 불가. `throw TypedError` 사용 필수
78. **`onAppear` + `onChange` 동일 로직은 `.task(id:)` 통합**: 동일 코드가 `onAppear`와 `onChange(of:)`에 중복되면 `.task(id: "\(dep1)-\(dep2)")` 하나로 통합. 초기 실행 + 의존값 변경 시 자동 재실행
79. **HealthKit 거리 값 상한 500km**: `extractDistance()`에서 `d < 500_000` (미터) 검증. 센서 오류로 비현실적 거리가 PR/통계를 왜곡하는 것 방지

### 2026-02-19: Training Volume 리뷰 수정 교정

80. **Formatter 객체는 static let 캐싱 필수**: `NumberFormatter`, `DateFormatter` 등 `NSObject` 기반 formatter를 hot path(차트 렌더링 등)에서 매번 생성 금지. `private enum Cache { static let formatter = ... }` 패턴 사용
81. **새 기능 구현 후 관련 Correction 항목 재검증**: `/review` 전에 새 코드가 기존 Correction Log 항목(특히 #17 Task.isCancelled, #70 .clipped(), #79 거리 상한)을 위반하지 않는지 사전 점검. `/work` 단계에서 관련 항목을 구현 체크리스트에 포함

### 2026-02-19: Train Dashboard 리뷰 교정

82. **`Shape.path(in:)` 내 무거운 연산 금지**: SwiftUI는 body 평가마다 `path(in:)`을 호출함. 문자열 파싱, JSON 디코딩, 정규식 등은 init-time에 수행하고 `path(in:)`에서는 `Path.applying(transform)`만 적용. `MuscleBodyShape` 패턴 참조

### 2026-02-19: Muscle Fatigue 10-Level 리뷰 교정

83. **Color 인스턴스는 static 배열로 캐싱**: `Color(hue:saturation:brightness:)` 등 초기화가 ForEach 내에서 반복 호출되면 `private enum Cache { static let colors = build() }` 패턴 사용. enum rawValue를 인덱스로 O(1) 접근
84. **Recovery modifier 입력에 물리적 상한 필수**: sleep minutes ≤ 1440 (24h), sleep ratio ≤ 1.0. Domain 서비스가 caller의 검증을 신뢰하지 않는 원칙(#42) 확장
85. **Snapshot 생성 시 aggregate 값에도 상한 적용**: `totalWeight`, `totalReps` 등 reduce 합산 결과는 개별 값의 합이므로 예상 외로 커질 수 있음. 세션 단위 물리적 상한 설정 (weight ≤ 50k, reps ≤ 10k, duration ≤ 480min)

### 2026-02-19: Unified Workout Row 리뷰 교정

86. **공유 DTO는 `Presentation/Shared/Models/`에 배치**: ViewModel 내부 struct로 정의된 DTO가 2곳 이상에서 사용되면 static factory method와 함께 Shared/Models/로 추출. ViewModel 간 import 의존 방지
87. **`.task(id:)` key는 content-aware Hasher 사용**: count 기반 String key는 삭제+추가 동시 발생 시 변경 감지 실패. `Hasher`로 모든 ID를 combine한 Int 사용
88. **관련 `@State` 변수는 원자적 업데이트**: 2개 이상의 `@State`를 순차 할당하면 중간 상태가 렌더에 노출됨. tuple return + `Task.isCancelled` guard 후 동시 할당
89. **문자열 키워드 매칭은 false-positive 테스트 필수**: 4자 미만 키워드("row", "run")는 실제 운동명과 충돌 가능. 키워드 추가 시 `noFalsePositive*` 테스트 작성 필수

### 2026-02-20: Review Agent + Wellness 리뷰 교정

90. **`Sendable` struct 내 튜플 사용 금지**: `(value: Double, date: Date)?` 대신 `VitalSample`처럼 명시적 `Sendable` struct 사용. 기존에 동일 구조의 Sendable 타입이 있으면 재활용
91. **리뷰 에이전트 output 크기 제어 필수**: 에이전트 `.md`에 "tool call 최소화, findings만 출력" 지시. `max_turns: 6` 설정. diff 2000줄 이상이면 에이전트 대신 직접 리뷰
92. **TaskGroup catch 블록에 에러 식별 로그 필수**: `print("[모듈명] {key} fetch failed: \(error)")` 패턴으로 어떤 쿼리가 실패했는지 식별 가능하게. silent catch 금지

### 2026-02-21: Wellness Section Split 리뷰 교정

93. **분류 switch에 `default:` 금지**: `CardSection.section(for:)` 등 enum case를 분류하는 switch에는 exhaustive case 나열 필수. `default:` 사용 시 새 case 추가가 컴파일 타임에 감지되지 않음
94. **새 `HealthMetric.Category` 추가 시 10+ 파일 수정 필수**: 추가 시 체크리스트 — `HealthMetric+View.swift` (5개 switch), `MetricSummaryHeader`, `MetricHighlightsView`, `AllDataView`, `AllDataViewModel`, `MetricDetailView`, `MetricDetailViewModel`, `VitalCardData`, `WellnessViewModel`. `docs/solutions/architecture/2026-02-21-wellness-section-split-patterns.md` 참조

### 2026-02-22: Build 검증 워크플로우 교정

95. **빌드 검증은 `scripts/build-ios.sh` 단일 경로 사용**: `xcodegen generate --spec Dailve/project.yml` + `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`를 스크립트로 표준화. 임의 `generic/platform=iOS` 사용 금지
96. **Swift/Xcode 변경 커밋 전 iOS 빌드 자동 검증**: `scripts/hooks/pre-commit.sh`에서 Swift/Xcode 관련 staged 변경 감지 시 `scripts/build-ios.sh` 실행. 긴급 시 `DAILVE_SKIP_PRECOMMIT_BUILD=1`로 1회 스킵 가능

### 2026-02-22: 숫자 표기 일관성 교정

97. **화면 숫자 표기는 `formattedWithSeparator` 경유 필수**: UI 라벨에서 `String(format: "%.0f")`, `"\(Int(...))"` 직접 렌더링 금지. `Int.formattedWithSeparator` 또는 `Double.formattedWithSeparator(fractionDigits:)`를 사용해 `1,000` 단위 구분을 기본값으로 유지

### 2026-02-23: Today Tab UX 통일 교정

98. **`changeFractionDigits` 단일 소스 필수**: 카테고리별 소수점 자릿수는 `HealthMetric+View.changeFractionDigits`만 수정. ViewModel에 inline switch로 중복 구현 금지
99. **UI 컴포넌트 삭제 시 기능 이관 체크리스트**: `.contextMenu`, `.hoverEffect`, `.accessibilityReduceMotion` 등 부가 기능이 삭제 대상 View에만 있으면 대체 View로 이관 필수
100. **`TodayPinnedMetricsStore` 빈 배열 fallback 주의**: `save([])` → `load()` 시 `[.hrv, .rhr, .sleep]` fallback 반환. 테스트에서 "피닝 없음"이 필요하면 비충돌 카테고리(`[.weight]`) 저장

### 2026-02-23: Activity Detail Views 리뷰 교정

101. **`compactMap` 후 분모는 필터링된 count 사용**: `compactMap(\.weight).reduce(0, +) / Double(allSets.count)` 패턴은 nil 값이 분모에 포함됨. 반드시 `weights.count`를 분모로 사용
102. **body에서 호출되는 Calendar 연산 캐싱 필수**: `calendarDays()`, `firstWeekdayOffset()` 같은 Date/Calendar 함수는 ViewModel의 `loadData`에서 1회 계산 후 프로퍼티 저장. body 내 함수 호출은 매 렌더마다 실행됨

### 2026-02-23: Activity Detail View v2 리뷰 교정

103. **Detail View는 parent ViewModel 참조 금지**: 필요한 데이터만 개별 프로퍼티(`let readiness: TrainingReadiness?`, `let hrvData: [DailySample]`)로 전달. 테스트 용이성, 프리뷰, 재사용성 확보
104. **`Dictionary(uniqueKeysWithValues:)` 사용 금지**: 날짜 기반 그룹핑에서 중복 키 가능성 항상 존재. `Dictionary(_:uniquingKeysWith: { _, last in last })` 필수 사용
105. **Chart body 내 gradient/color allocation 금지**: constant color → `private enum Gradients { static let }`, dynamic color → `private var gradient` computed property로 호이스트. Chart closure는 데이터 포인트마다 실행되므로 allocation-free 원칙
106. **iPad HStack layout은 섹션을 computed property로 추출**: `if isRegular { HStack { sectionA; sectionB } } else { sectionA; sectionB }` 패턴에서 섹션 중복 방지. `private var recoveryMapSection: some View { ... }` 패턴 사용

### 2026-02-24: Sleep Dedup + Watch 소스 감지 교정

107. **HealthKit Watch 소스 감지에 `bundleIdentifier` 단독 사용 금지**: Apple Watch 동기화 데이터는 `com.apple.health.{UUID}` 번들 ID 사용. `sourceRevision.productType.hasPrefix("Watch")`를 우선 체크
108. **Sleep dedup에서 동일 소스 overlap은 유지**: 같은 소스의 다른 수면 단계가 전환기에 겹치는 것은 정상 동작. 삭제하면 수면 시간 과소 집계
109. **동일 소스 `asleepUnspecified` + 구체적 stage overlap 시 unspecified skip**: 3rd-party 앱이 부모(unspecified)+자식(core/deep/rem) span을 겹쳐 쓸 때 과다 집계 방지
110. **Display와 Score 계산의 stage 분류 일관성 필수**: 차트에서 `.unspecified`를 `.core`로 병합하면서 점수에서 `.core`로 안 세면 사용자 혼란. 동일 정책 적용 (#23 확장)
111. **ViewModel computed property가 UseCase를 호출하면 캐싱 필수**: `todayOutput` 같은 UseCase 실행 결과를 3개 computed property가 각각 호출하면 렌더당 3회 실행. `loadData()`에서 1회 계산 후 stored property에 저장

### 2026-02-25: Condition Score 0점 수정 교정

112. **RHR fallback을 condition input의 "today" 파라미터로 전달 금지**: `todayRHR ?? latestRHR?.value` 패턴은 비인접일 비교를 유발하여 거짓 패널티 발생. `todayRHR`이 nil이면 RHR 보정을 스킵하는 것이 올바른 동작
113. **z-score 기반 점수 알고리즘에 ConditionScoreDetail 패턴 적용**: 중간 계산값(todayHRV, baselineHRV, zScore, stdDev, rawScore)을 Domain 모델에 포함하여 UI에서 디버깅 가능하게. 점수가 비정상일 때 원인 추적 가능
114. **통계 파라미터(minimumStdDev, zScoreMultiplier) 변경 시 실데이터 시나리오 검증**: 야간 미착용(주간 전용 HRV), 운동 직후, 컨디션 저하 등 3개 이상 시나리오에서 산출 점수가 0-100 범위 내 합리적 분포인지 확인

### 2026-02-25: Body Score "--" 수정 + Calculation Card 교정

115. **Fetch window는 필터 threshold의 2배 이상**: `dateComponents([.day]) >= N` 필터 사용 시 fetch range는 최소 `2N일`. `dateComponents`의 시간 truncation으로 "7일 전"이 `.day = 5`로 계산될 수 있음
116. **Score 추가 시 `{Type}ScoreDetail` + `{Type}CalculationCard` 세트 구현**: 새 score 컴포넌트는 중간 계산값 노출 모델 + breakdown UI를 함께 만들어 디버깅 가능하게
117. **분류 threshold는 Domain 단일 소스**: weight "stable/losing/gaining" 같은 분류 기준이 Domain과 Presentation에 중복되면 enum으로 Domain에서 산출 후 Presentation은 rawValue만 표시
118. **Correction #80 적용 범위 한정**: `NSObject` 기반 formatter(`DateFormatter`, `NumberFormatter`)만 static 캐싱 대상. `String(format:)`은 value operation이므로 init pre-cache 불필요

### 2026-02-26: App Icon + Launch Screen 통합 교정

119. **xcassets 색상은 `Colors/` 하위에 배치**: root에 `.colorset` 생성 금지. `AccentColor` 포함 모든 named color는 `Assets.xcassets/Colors/`에 위치
120. **light/dark 동일 색상은 universal만 유지**: dark appearance 항목이 universal과 동일 값이면 삭제. Xcode가 자동으로 universal을 dark에 적용
121. **xcodegen 후 objectVersion/compatibilityVersion 후처리 필수**: xcodegen이 Xcode 16.3 포맷(objectVersion 90)을 미지원. 생성 후 `sed`로 교체. `xcodeVersion`(IDE 버전)과 `compatibilityVersion`(파일 포맷)은 별개 개념
122. **UILaunchScreen 이미지 크기는 universal 단일 파일**: scale factor(@1x/@2x/@3x) 미지정 시 px = pt. 디바이스별 반응형 크기 조절 불가하므로 iPhone~iPad 공통 적정 크기(500px) 선택
123. **watchOS 타겟에 `INFOPLIST_KEY_CFBundleIconName` 명시 필수**: `ASSETCATALOG_COMPILER_APPICON_NAME`만으로 부족. `GENERATE_INFOPLIST_FILE: true` 사용 시 watchOS validation은 `CFBundleIconName` Info.plist 키를 명시적으로 요구. iOS는 관대하지만 watchOS는 엄격
124. **Asset catalog `platform` 값은 반드시 소문자**: `"watchOS"` → `"watchos"`, `"iOS"` → `"ios"`. 대소문자 틀리면 Xcode가 "Unassigned" 처리 → `Assets.car`에 아이콘 미포함 → Archive validation "Missing Icons". 빌드는 성공하므로 발견이 늦음
125. **watchOS AppIcon Contents.json 최종 포맷**: `"idiom": "universal"` + `"platform": "watchos"` + `"size": "1024x1024"` (scale 없음). 레거시 `"idiom": "watch"` + `"scale": "2x"` 금지
126. **validation 에러는 Xcode asset catalog 에디터에서 "Unassigned" 먼저 확인**: 빌드 설정/Info.plist 수정보다 리소스 파일 자체를 먼저 검증. Archive 산출물에 `Assets.car` 존재 여부 확인이 확실한 진단법

### 2026-02-26: Visual Overhaul — Warm Tone 전환 교정

127. **다크 모드 배경 gradient opacity 최소 0.06**: 0.03 이하는 사실상 투명하여 디자인 의도가 전달되지 않음. 시각적 효과가 필요한 배경은 0.06~0.14 범위 사용
128. **반복 UnitPoint/opacity는 DS 토큰으로 추출**: 3곳 이상 동일 `UnitPoint(x:y:)` 사용 시 `DS.Gradient.*` 상수로 추출. 매직넘버 제거 + 일괄 조정 가능
129. **비주얼 변경은 v1(보수적) → v2(강화) 2단계 접근**: 먼저 안전한 값으로 커밋+확인 후 강도 조절. 한 번에 강하게 가면 롤백 범위가 넓어짐

### 2026-02-26: Watch Workout Dedup False-Positive 교정

130. **`isFromThisApp` 단독 필터 조건 사용 금지**: Watch companion 앱은 parent iOS 앱의 bundle ID(`com.raftel.dailve`)를 HealthKit `sourceRevision`에 공유. `isFromThisApp=true`만으로 dedup 필터링하면 ExerciseRecord 없는 Watch 워크아웃이 완전히 사라짐. 반드시 type+date proximity(±2분) 매칭 조건을 병행
131. **Dedup fallback은 보수적(inclusive)이어야 함**: "중복 표시"보다 "보이지 않음"이 사용자 경험에 훨씬 치명적. 확신 없는 경우 보여주고, 확실히 중복인 경우만 필터링
132. **Correction #39 적용 범위 명확화 — Void async 함수는 `defer` 사용 필수**: #39(`defer`로 isSaving 리셋 금지)는 반환값이 있는 함수(`-> Record?`)에만 적용. Void async 함수(`loadActivityData()`)에서는 `defer { isLoading = false }`가 모든 exit path(Task cancellation 포함)를 커버하는 유일한 안전 수단
133. **Dead code(선언만 있고 미할당 프로퍼티)는 리뷰 시 즉시 제거**: `private var loadTask: Task<Void, Never>?`처럼 선언 후 한 번도 할당되지 않는 프로퍼티는 `loadTask?.cancel()`이 항상 no-op. Optional chaining이 실패를 삼키므로 dead code가 잠복 버그를 은폐
134. **버그 수정 후 사용자 확인 전 "해결됨" 판정 금지**: 첫 가설(`isLoading` stuck)만 수정하고 검증 없이 다음 단계 진행하면 실제 원인(dedup false-positive)을 놓침. 수정 → 빌드 → 사용자 확인 → 다음 단계 순서 필수
135. **진단 로그는 핵심 결정 지점에 집중**: `print("[DEBUG] count=\(items.count)")`보다 `print("[DEBUG] workout: \(type) | isFromThisApp=\(flag) | filtered=\(result)")`처럼 판정 로직의 입출력을 로깅. 데이터 흐름의 "어디서 사라졌는지"를 즉시 파악 가능

### 2026-02-26: AccentColor Fallback 교정

136. **브랜드 컬러에 `.accentColor` 직접 사용 금지**: xcodegen 환경에서 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 미설정 시 시스템 기본 파란색 반환. `Color("AccentColor")` 또는 `DS.Color.warmGlow` 경유 필수. **예외**: ProgressRingView, HeroScoreCard의 gradient에서는 system blue blending이 "사막 느낌"을 만들어 의도적으로 `Color.accentColor` 유지

### 2026-02-27: Design System Consistency Integration 교정

137. **AccentColor dark variant 추가 시 ring gradient 시각 테스트 필수**: 밝은 dark variant가 opacity 0.6에서 적용되면 warm glow가 사실상 투명해져 ring의 multi-tonal 효과 소실. universal-only 유지가 기본 원칙 (Correction #120)
138. **Watch DS 토큰 추가 시 iOS DS와 동기 확인**: `DUNEWatch/DesignSystem.swift`는 iOS DS의 부분 집합. 새 토큰 추가 시 양쪽 파일 모두 업데이트 필수. 향후 shared Swift package 통합 필요
139. **DS.Opacity 토큰은 용도 기반 네이밍**: `emphasis`(강도) 대신 `border`(용도)처럼 실제 사용처를 반영하는 이름 사용. `DS.Animation.emphasize` 등 기존 토큰과의 이름 충돌 방지
140. **심장 아이콘에 `DS.Color.heartRate` 사용**: `DS.Color.negative`(에러/실패 피드백)를 심장 박동 아이콘에 사용하면 시맨틱 오용. 전용 metric 색상 토큰이 있으면 그것을 사용

### 2026-02-27: Launch Splash 최소 노출 안정화 교정

141. **최소 노출 타이머는 `CancellationError` 명시 처리 필수**: `try? await Task.sleep(...)`는 취소 시 즉시 반환하며 에러를 삼켜 요구사항(예: 최소 1초 노출)을 깨뜨릴 수 있음. `do/catch`로 취소를 분기하고, 취소 시 UI 상태를 변경하지 않는 것이 안전
142. **Launch→Custom Splash 연속 전환에서는 로고 고정 frame 금지**: 시스템 Launch Screen과 커스텀 스플래시의 렌더링 규칙이 다를 수 있으므로 `.frame(width:height:)` 하드코딩은 점프(축소/확대) 체감을 유발. 동일 에셋 사용 시 크기 강제보다 기본 렌더링을 우선

### 2026-02-27: Wave Expansion 전면 적용 교정

143. **List/Form + 웨이브 배경은 `.scrollContentBackground(.hidden)` 필수**: SwiftUI `List`/`Form`의 기본 불투명 배경이 웨이브를 가림. `.background { WaveBackground() }` 추가 시 반드시 `.scrollContentBackground(.hidden)` 세트로 적용
144. **웨이브 색상 오버라이드는 Environment 전용**: `DetailWaveBackground(overrideColor:)` 같은 init 파라미터 패턴 금지. `.environment(\.waveColor, color)` 패턴으로 3-tier(Tab/Detail/Sheet) 모두 동일 API 유지
145. **WavePreset에 소비자 없는 case 추가 금지**: `.injury`, `.watch` 등 실제 environment setter가 없는 case는 모든 switch에 dead 분기를 추가함. consumer가 생길 때 case를 추가할 것
146. **새 View 추가 시 웨이브 배경 적용 체크**: Tab root → `TabWaveBackground`, Push detail → `DetailWaveBackground`, Sheet/Modal → `SheetWaveBackground`. 누락 시 디자인 일관성 파괴

### 2026-02-27: Muscle Map Volume Mode 통합 교정

147. **SVG body diagram 위 DragGesture 금지**: ForEach 내 Button 수십 개가 렌더되는 영역에서 DragGesture는 탭 이벤트를 소비함. 모드 전환은 diagram 영역 밖(header의 Segmented Picker 등)에 배치할 것
148. **모드별 dispatch 함수보다 튜플 반환 단일 함수**: `fillColor(for:)` + `strokeColor(for:)` 각각 switch하면 4개 함수로 팽창. `muscleColors(for:) -> (fill: Color, stroke: Color)` 패턴으로 switch 1회로 통합
149. **3개+ 파일에서 참조되는 enum은 전용 파일 즉시 분리**: `VolumeIntensity`처럼 View 파일 하단에 정의된 enum이 다른 View에서도 사용되면 `{Type}.swift`로 분리. description extension도 동일 파일에 위치
