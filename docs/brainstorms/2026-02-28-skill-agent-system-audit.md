---
tags: [skills, agents, automation, context-optimization, mcp]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: 스킬/에이전트 시스템 전체 감사 및 개선

## Problem Statement

Compound Engineering 시스템이 2주간 성장하면서 다음 문제가 누적됨:
1. **Correction Log 비대화**: 182항목 → 매 세션 컨텍스트 비용 과다
2. **스킬 실효성 격차**: 19개 중 2개 미구현, 일부 사용 빈도 낮음
3. **자동화 부재**: 규칙 위반이 빌드/커밋 시점에 자동 감지되지 않음
4. **워크플로우 마찰**: /run 파이프라인이 무겁고, MCP 활용도 불투명

## Current Inventory

### Skills (19개)

| 스킬 | 상태 | 사용 빈도 | 비고 |
|------|------|-----------|------|
| brainstorm | 구현 | 중 | 요구사항 명확화 |
| plan | 구현 | 높음 | 핵심 워크플로우 |
| work | 구현 | 높음 | 핵심 워크플로우 |
| review | 구현 | 높음 | 6-에이전트 병렬 리뷰 |
| triage | 구현 | 중 | review 후속 |
| compound | 구현 | 높음 | 문서화 |
| retrospective | 구현 | 낮음 | 세션 종료 시 |
| debug | 구현 | 중 | 버그 발생 시 |
| ship | 구현 | 높음 | PR/머지 자동화 |
| run | 구현 | 중 | 전체 파이프라인 |
| onboard | 구현 | 낮음 | 새 세션 시 |
| changelog | 구현 | 낮음 | 릴리스 시 |
| **code-style** | **미구현** | - | 대부분 "To be defined" |
| **copy-voice** | **미구현** | - | 대부분 "To be defined" |
| design-system | 구현 | 중 | DS 토큰 참조 |
| testing-patterns | 구현 | 중 | 테스트 패턴 참조 |
| ui-testing | 구현 | 낮음 | UI 테스트 참조 |
| xcode-project | 구현 | 높음 | 빌드/프로젝트 관리 |
| agent-architecture | 구현 | 낮음 | 메타 가이드 |

### Rules (10개)

| 규칙 파일 | Correction Log 중복 |
|-----------|-------------------|
| swift-layer-boundaries | #1, #2, #7, #20, #62 |
| swiftdata-cloudkit | #32, #33, #40, #65, #71 |
| healthkit-patterns | #5, #22, #107, #108, #109, #130 |
| input-validation | #3, #4, #6, #22, #38, #39, #41 |
| watch-navigation | #57, #58, #59, #60, #61 |
| navigation-ownership | #48 |
| testing-required | - |
| compound-workflow | - |
| documentation-standards | - |
| todo-conventions | - |

### Correction Log 분석 (182항목)

**카테고리 분포**:
- SwiftUI/레이아웃: ~30항목 (#28-31, #47, #65, #70, #143-146, #179-182 등)
- HealthKit: ~15항목 (#5, #22, #107-111, #130-131 등)
- 성능(캐싱/static let): ~20항목 (#8, #80, #83, #102, #105, #152-153 등)
- CloudKit/SwiftData: ~10항목 (#32-33, #40, #65, #71 등)
- 입력 검증: ~10항목 (#3, #4, #38, #41-42, #72, #84-85 등)
- Watch: ~15항목 (#46, #57-61, #69, #72, #107, #167 등)
- 리뷰/워크플로우: ~10항목 (#13-15, #27, #54-55, #91, #134 등)
- 디자인 시스템: ~15항목 (#119-129, #136-140, #159-166 등)
- 기타(DRY, naming 등): ~57항목

**Rules로 졸업 가능한 항목**: ~60개 (기존 rules 파일에 병합)
**이미 rules에 있는 중복 항목**: ~30개 (삭제 가능)
**프로젝트 특화(유지 필요)**: ~90개

### MCP Servers (7개)

| 서버 | 용도 | 활용 잠재력 |
|------|------|------------|
| Serena | 심볼릭 코드 분석 | 높음 — find_symbol, find_referencing_symbols |
| Context7 | 라이브러리 문서 검색 | 중 — Swift/SwiftUI API 참조 |
| Chrome | 브라우저 자동화 | 낮음 (iOS 앱이므로) |
| Claude Preview | 웹 미리보기 | 낮음 (iOS 앱이므로) |
| Sequential Thinking | 복잡 문제 분해 | 중 — 디버깅/설계 시 |
| mcp-registry | 커넥터 검색 | 낮음 |
| deepwiki | 레포 문서 조회 | 중 — 외부 라이브러리 참조 |

## Proposed Improvements

### 1. Correction Log 압축 (예상 효과: 430줄 → ~200줄)

**전략**: 3단계 졸업 시스템
- **A. Rules 졸업**: 반복 패턴 → .claude/rules/{topic}.md에 병합 후 Correction에서 삭제
- **B. 테마 병합**: 동일 주제 항목을 1개로 통합 (예: 캐싱 관련 #8, #80, #83, #102, #105 → 1항목)
- **C. 완전 내재화 삭제**: rules에 이미 있고 Correction에서도 중복인 항목 제거

**신규 Rules 파일 후보**:
- `swiftui-layout.md`: 차트 레이아웃, 조건부 VStack, .id() 전환 패턴
- `performance-caching.md`: static let, Formatter 캐싱, computed property 캐싱
- `design-system-tokens.md`: DS 토큰 사용 규칙, xcassets 패턴
- `watch-ios-parity.md`: Watch DTO 동기화, 검증 수준 동등

### 2. 스킬 정리

**제거/보류 후보**:
- `code-style`: 미구현. Swift 규칙은 이미 rules/에 분산. 필요 시 향후 구현
- `copy-voice`: 미구현. 앱 voice가 확립되면 그때 작성
- `agent-architecture`: 메타 가이드. Serena memory에 이관 가능

**강화 후보**:
- `review`: diff 2000줄 초과 시 자동 파일 분할 리뷰
- `ship`: changelog 자동 생성 연계
- `run`: 단계별 조기 종료 옵션 (P1 없으면 triage 스킵)

### 3. 자동화 확대

**Hook 추가**:
- `PostToolUse(Write|Edit)`: Swift 파일 변경 시 layer boundary import 체크
- `PreToolUse(Bash(git commit))`: Correction Log 중 관련 항목 체크리스트 출력

**스킬 자동 트리거**:
- `/review` 후 P1이 0개면 자동으로 `/ship` 제안
- 새 UseCase/ViewModel 파일 생성 시 테스트 파일 scaffolding 자동 생성

### 4. MCP 활용 최적화

**Serena**: 코드 탐색의 기본 도구로 승격. `find_symbol` + `find_referencing_symbols`를 /plan, /review에서 적극 활용
**Context7**: /plan의 research 단계에서 Swift/SwiftUI API 확인에 사용
**Sequential Thinking**: /debug, /brainstorm에서 복잡 문제 분해에 활용
**Chrome/Preview**: iOS 앱이므로 활용도 제한적. 웹 문서 참조 시에만 사용

### 5. 워크플로우 개선

- `/run`에 `--fast` 모드: Plan → Work → Quick Review (에이전트 3개만) → Ship
- `/review`에 `--focused` 모드: 변경 파일 관련 에이전트만 실행
- `/triage` 자동 모드: P1 → 자동 Fix, P2 → Fix, P3 → Skip (확인 없이)

## Success Criteria

- [ ] CLAUDE.md 줄 수 < 250줄
- [ ] 미구현 스킬 0개 (제거 또는 구현)
- [ ] Correction Log 항목 < 100개
- [ ] 신규 Rules 파일 2개 이상 추가

## Scope

### 즉시 실행 (이번 세션)
1. Correction Log → Rules 졸업 (중복 제거 + 테마 병합)
2. 미구현 스킬 제거 (code-style, copy-voice → 존재하되 "향후 구현" 명시)
3. CLAUDE.md 압축

### 향후 (별도 세션)
- Hook 자동화 추가
- /run --fast 모드 구현
- MCP 활용 가이드를 onboard 스킬에 통합
- Serena memory에 프로젝트 패턴 저장

## Next Steps

- 즉시 Correction Log 졸업 시작
- 테마별 신규 Rules 파일 생성
- CLAUDE.md 압축 후 줄 수 확인
