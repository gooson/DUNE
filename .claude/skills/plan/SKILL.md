---
name: plan
description: "구현 계획을 생성합니다. 코드베이스를 분석하고, 과거 해결책을 참조하여 구조화된 계획을 만듭니다."
---

# Plan: 구현 계획 생성

$ARGUMENTS 에 대한 구조화된 구현 계획을 생성합니다.

## Process

### Phase 1: Research (조사)

1. **과거 해결책 검색**: docs/solutions/ 에서 관련 문서를 검색합니다
2. **코드베이스 분석**: 기존 패턴, 컨벤션, 유틸리티를 파악합니다
3. **관련 brainstorm 확인**: docs/brainstorms/ 에서 관련 문서가 있는지 확인합니다
4. **TODO 확인**: todos/ 에서 관련 작업이 있는지 확인합니다

3개의 병렬 리서치를 수행합니다:
- **Repo Research**: 기존 코드베이스의 패턴, 유틸리티, 관련 파일 분석
- **Solution Research**: docs/solutions/ 에서 관련 과거 해결책 검색
- **Best Practices**: 해당 기술/프레임워크의 최신 모범 사례 조사

### MCP 도구 활용

리서치 단계에서 MCP 도구를 적극 활용합니다:

| 도구 | 활용 시점 | 예시 |
|------|----------|------|
| **Context7** | Swift/SwiftUI/HealthKit API 동작 확인 | `resolve-library-id` → `get-library-docs` 로 공식 문서 참조 |
| **Serena** | 심볼 의존 관계 파악 | `find_symbol` + `find_referencing_symbols`로 영향 범위 분석 |
| **Sequential Thinking** | 복잡한 설계 결정 분해 | 대안 비교 시 단계적 사고로 trade-off 분석 |

**활용 우선순위**: Serena(코드 구조) → Context7(API 확인) → Sequential Thinking(설계 결정)

### Phase 2: Design (설계)

분석 결과를 바탕으로 다음을 설계합니다:
- 영향받는 파일 목록
- 단계별 구현 방법
- 테스트 전략
- 엣지 케이스 처리
- 대안 비교 (선택한 접근법의 근거)

### Phase 3: Plan Document (계획서 작성)

**출력 경로**: `docs/plans/YYYY-MM-DD-{topic-slug}.md`

`.claude/skills/plan/templates/plan-template.md` 형식을 따라 계획서를 작성합니다.

### Phase 4: Validation (검증)

계획서를 검증합니다:
- [ ] 모든 영향받는 파일이 식별되었는가?
- [ ] 각 단계가 독립적으로 테스트 가능한가?
- [ ] 위험 요소가 식별되었는가?
- [ ] 기존 패턴을 최대한 활용하는가?
- [ ] Edge case가 고려되었는가?

## 완료 후 안내

- `/work` 으로 구현을 시작할 수 있습니다
- 계획서 경로와 요약을 사용자에게 반환합니다
- 사용자의 계획 승인을 요청합니다
