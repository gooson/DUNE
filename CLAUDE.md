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
| /run | 전체 파이프라인 자동 실행 | 기능 전체 구현 |
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
- PR은 /run 또는 /work 를 통해 생성

## Compounding Mechanisms

시스템이 스스로 개선되는 5가지 경로:
1. **Agent Memory**: 리뷰 에이전트가 `memory: project`로 프로젝트별 패턴을 학습
2. **Solution Docs**: `/compound`로 해결된 문제가 `docs/solutions/`에 축적
3. **Correction Log**: `/retrospective`가 이 파일에 교정사항 추가
4. **Rules 축적**: 반복 패턴이 `.claude/rules/`로 승격
5. **Domain Skills 성장**: 프로젝트 진행에 따라 skills가 구체화

## Correction Log

> 안정화된 패턴은 `.claude/rules/`로 졸업되었습니다.
> 전체 이력(#1~#184)은 `docs/corrections-archive.md`에 보존됩니다.
> 아래는 rules로 졸업하지 않은 **프로젝트 특화** 교정 사항입니다.

<!-- Rules 졸업 현황:
  - swiftui-patterns.md: #28-31, #47-49, #52, #65-66, #70-71, #74, #143-146, #150, #179-183
  - performance-patterns.md: #8, #16-17, #35, #80, #83, #102, #105, #111, #118, #132, #152-153, #165, #169, #184
  - swift-layer-boundaries.md: #1, #2, #7, #20, #36, #62, #73, #86, #103, #117, #155
  - input-validation.md: #3, #4, #6, #11, #18, #21, #22, #38-39, #41-42, #84-85, #101
  - healthkit-patterns.md: #5, #107-110, #130-131
  - swiftdata-cloudkit.md: #32-33, #40, #50, #65, #71, #164
  - watch-navigation.md: #57-61
-->

### Data & Score 로직

- **historical fallback 시 change=nil**: 비인접일 비교는 의미 없음 (#24, #51)
- **partial failure 보고 필수**: async let 4+개 시 "N of M sources" 형태 (#25, #92)
- **Hashable: == 와 hash 프로퍼티 일치**: content-aware Hasher 사용 (#26, #87, #175)
- **RHR fallback을 condition "today"로 전달 금지**: nil이면 보정 스킵 (#112)
- **Score 추가 시 `{Type}ScoreDetail` + `{Type}CalculationCard` 세트**: 중간 계산값 디버깅 (#113, #116)
- **통계 파라미터 변경 시 3+개 실데이터 시나리오 검증** (#114)
- **Fetch window >= 필터 threshold x 2**: dateComponents 시간 truncation 보상 (#115)
- **Sleep stage 분류: Display와 Score 일관성 필수** (#110)
- **시계열 regression 입력은 oldest-first 정렬** (#156)
- **Dedup 필터 빈 문자열 ID 방어**: `!id.isEmpty` 검증 (#63)
- **HK ID 캡처 -> SwiftData 삭제 -> HK 삭제 순서** (#67)

### DRY & 구조

- **동일 로직 3곳+ 즉시 추출** / 복잡하면 2곳부터 / 같은 파일이면 file-scope (#37, #64, #167, #173)
- **공유 DTO -> `Presentation/Shared/Models/`** / VM 내부 struct 2곳+ 사용 시 추출 (#86, #155)
- **3개+ 파일 참조 enum은 전용 파일 분리** (#149)
- **Popover/inline 중복은 `isInline: Bool` 파라미터로 통합** (#151)
- **카테고리->색상 매핑은 enum extension 단일 소스** (#176)
- **모드별 dispatch 함수보다 튜플 반환 단일 함수** (#148)
- **`Dictionary(uniqueKeysWithValues:)` 사용 금지 -> `uniquingKeysWith`** (#104)
- **iPad HStack layout은 섹션을 computed property로 추출** (#106)

### Watch/iOS Parity

- **Watch DTO 필드 추가 시 양쪽 target 동기화** (#69, #138)
- **Watch 입력도 iOS 동일 수준 검증** (#72)
- **Watch `isReachable`은 computed property** (#46)
- **bodyweight volume=0에서 "0kg" 표시 금지** (#170)
- **검색<->브라우징 모드 전환 시 반대편 캐시 초기화** (#171)
- **SVG body diagram 위 DragGesture 금지** (#147)
- **undertrained 리스트는 비즈니스 필터 후 prefix/suffix** (#154)

### Design System

- **xcassets 색상은 `Colors/` 하위 배치** / `Color(red:green:blue:)` 인라인 금지 (#119, #177)
- **light/dark 동일이면 universal만** (#120, #137)
- **DS.Opacity 용도 기반 네이밍** / 심장 아이콘에 `DS.Color.heartRate` (#139, #140)
- **DS 토큰 통일 시 용도별 시맨틱 크기 보존** (#163)
- **브랜드 컬러에 `.accentColor` 직접 사용 금지** (예외: ring gradient) (#136)
- **다크 모드 배경 gradient opacity >= 0.06** (#127, #128)
- **비주얼 변경은 v1->v2 2단계** (#129)
- **정적 색상 배열은 `CaseIterable`에서 파생** (#178)

### Asset Catalog & Xcode

- **xcodegen 후 objectVersion/compatibilityVersion 후처리** (#121)
- **watchOS: `INFOPLIST_KEY_CFBundleIconName` 명시 + platform 소문자** (#123-125)
- **Asset catalog 폴더에 `"provides-namespace": true`** (#159)
- **AI 생성 아이콘 투명 배경 확인** / 제네릭 장비는 SF Symbol (#160, #161)
- **Equipment.other -> nil ("없음" vs "미인식" 구분)** (#166)
- **Icon switch dispatch는 View init에서 pre-resolve** (#162)
- **validation 에러는 asset catalog "Unassigned" 먼저 확인** (#126)

### UI 표시 규칙

- **화면 숫자 표기는 `formattedWithSeparator` 경유** (#97)
- **`changeFractionDigits` 단일 소스: `HealthMetric+View`** (#98)
- **rawValue UI 직접 표시 금지 -> `displayName` computed** (#36)
- **`HealthMetric.Category` 추가 시 10+ 파일 수정 체크리스트** (#94)
- **UI 컴포넌트 삭제 시 기능 이관 체크리스트** (#99)
- **`TodayPinnedMetricsStore` 빈 배열 fallback 주의** (#100)
- **`Sendable` struct 내 튜플 사용 금지** (#90)
- **분류 switch에 `default:` 금지 -> exhaustive case** (#93)

### 프로세스

- **빌드 검증은 `scripts/build-ios.sh` 단일 경로** (#95-96)
- **CI 스크립트 xcodegen 로직은 `scripts/lib/regen-project.sh` 단일 소스** (#185)
- **workflow paths에 `scripts/**` 대신 개별 스크립트 경로 지정** (#186)
- **새 UI 테스트 파일은 `BaseUITestCase` 상속** (#187)
- **`/ship` 머지 전략은 `--merge` 기본** (#54)
- **리뷰 적용은 파일별 batch, dead code는 같은 커밋에서 삭제** (#27, #55, #133)
- **리뷰 에이전트 output 크기 제어: max_turns 6, diff 2000줄+은 직접 리뷰** (#91)
- **에이전트 리서치 3개 이하, 80% 품질 + 빠른 전달** (#13-15)
- **버그 수정 -> 빌드 -> 사용자 확인 -> 다음 단계** (#134, #135)
- **효과 확인된 수정은 즉시 커밋** (#180)
- **새 기능 구현 후 관련 Correction 항목 재검증** (#81)
- **UI 구조 변경 시 UI 테스트 동시 갱신** (#158)
- **문자열 키워드 매칭 false-positive 테스트 필수** (#89, #157)
- **Launch Splash 최소 노출: CancellationError 명시 처리** (#141-142)
- **`throws` 함수에서 silent `guard...return` 금지** (#77)
- **새 필드 추가 시 전체 파이프라인 점검** (#34)
- **방어 코드도 비즈니스 로직 고려 + 테스트 검증** (#44)
- **`Swift.max()` 명시적 호출 (Collection.max 충돌)** (#45)
- **Deprecated API 즉시 교체 (Xcode warning 0)** (#19)
- **`isSaving` 리셋은 View에서 insert 완료 후** (#43)
- **Cross-VM static 프로퍼티 참조 금지 -> 중립 enum** (#73)
- **UserDefaults: bundle prefix + garbage collection** (#75-76)
- **`personalizedPopular(limit:)`에 실제 필요 수량 전달** (#174)
- **`@Query` fetchLimit → `Query(FetchDescriptor)` init 사용** (매크로 직접 파라미터 미지원) (#183)
- **Swift 6 `@MainActor` + `withThrowingTaskGroup` 내 `@MainActor addTask` 금지** → continuation 내부 Task timeout 패턴 (#184)
