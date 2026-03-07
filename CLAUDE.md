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

> 안정화된 패턴은 `.claude/rules/`로 졸업합니다.
> 전체 이력(#1~#204)은 `docs/corrections-archive.md`에 보존됩니다.
> 프로젝트 특화 교정 사항은 `docs/corrections-active.md`에 있습니다.
> `/plan`, `/review` 시 자동으로 참조됩니다.

### Rules 졸업 현황

| Rule 파일 | 졸업 교정 번호 |
|-----------|---------------|
| swiftui-patterns.md | #28-31, #47-49, #52, #65-66, #70-71, #74, #93, #106, #143-146, #150, #179-183 |
| performance-patterns.md | #8, #16-17, #35, #80, #83, #102, #105, #111, #118, #132, #152-153, #165, #169, #174, #184 |
| swift-layer-boundaries.md | #1, #2, #7, #20, #36, #62, #73, #86, #103, #117, #155 |
| input-validation.md | #3, #4, #6, #11, #18, #21, #22, #38-39, #41-42, #84-85, #101 |
| healthkit-patterns.md | #5, #107-110, #130-131 |
| swiftdata-cloudkit.md | #32-33, #40, #50, #65, #71, #164, #188 |
| watch-navigation.md | #57-61 |
| build-pipeline.md | #95-96, #185 |
| watch-ios-parity.md | #46, #69, #72, #138, #147, #154, #170-171, #189-195, #197-200 |
| design-system-rules.md | #119-120, #127-129, #136-137, #139-140, #163, #176-178 |
| asset-catalog.md | #121, #123-126, #159-162, #166, #201, #203 |
| localization.md | #36 |
