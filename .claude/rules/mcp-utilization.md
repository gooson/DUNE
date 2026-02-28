# MCP Tool Utilization Guide

## 사용 가능한 MCP 서버

| 서버 | 주요 도구 | 활용 시점 |
|------|----------|----------|
| **Serena** | `find_symbol`, `find_referencing_symbols` | 코드 구조 분석, 영향 범위 파악 |
| **Context7** | `resolve-library-id`, `get-library-docs` | Swift/SwiftUI/HealthKit API 동작 확인 |
| **Sequential Thinking** | `sequentialthinking` | 복잡한 설계 결정, 다중 가설 분석 |
| **DeepWiki** | `read_wiki_structure`, `read_wiki_contents` | 외부 라이브러리 문서 참조 |

## 활용 원칙

1. **필요할 때만 호출**: MCP는 보조 도구. 기본 도구(Grep, Glob, Read)로 충분하면 MCP 불필요
2. **Serena 우선**: 코드 구조 질문 → Serena → 결과 부족 시 Grep/Glob fallback
3. **Context7 = API 의문**: "이 API가 정확히 어떻게 동작하지?" 시점에서 사용
4. **Sequential Thinking = 복잡한 결정**: 가설 3개+, 대안 비교, 아키텍처 결정

## 스킬별 MCP 활용 매핑

### /plan
- **Serena**: `find_symbol` → 영향받는 파일 자동 식별, `find_referencing_symbols` → 의존 관계 파악
- **Context7**: 새 API 도입 시 공식 문서 확인
- **Sequential Thinking**: 대안 비교 시 trade-off 체계적 분석

### /review
- **Serena**: 변경 함수의 호출자 파악 → 리뷰 범위 누락 방지
- 단순 diff 리뷰에는 MCP 불필요

### /debug
- **Serena**: 문제 함수의 호출 체인 추적, 관련 심볼 격리
- **Sequential Thinking**: 가설 3개+ 시 체계적 분해/반증
- **Context7**: API 예상 동작 vs 실제 동작 비교

### /brainstorm
- **Sequential Thinking**: 모호한 요구사항의 단계적 구체화
- **DeepWiki**: 참고할 외부 라이브러리 패턴 조사

## 금지 패턴

- MCP 결과를 검증 없이 신뢰하지 않음 (항상 코드베이스와 교차 확인)
- 단순 파일 검색에 Serena 사용 금지 → Glob/Grep이 빠름
- Context7로 프로젝트 내부 코드 검색 금지 → 외부 라이브러리 문서 전용
