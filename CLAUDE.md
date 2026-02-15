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
