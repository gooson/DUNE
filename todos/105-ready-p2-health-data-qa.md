---
source: brainstorm/apple-on-device-ml-sdk-research
priority: p2
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# 건강 데이터 Q&A (Foundation Models)

## 설명

사용자가 자연어로 건강 데이터에 대해 질문하면 Foundation Models가 HealthKit 데이터를 분석하여 답변합니다.

## 구현 범위

- Tool Calling 프로토콜로 HealthKit 데이터 접근 도구 정의
- `LanguageModelSession`으로 멀티턴 대화 지원
- 사전 집계된 건강 요약 데이터를 컨텍스트로 제공 (4096 토큰 제한 고려)
- 질문 예시: "이번 주 수면 패턴이 어때?", "심박수가 높아진 이유가 뭘까?"

## 참고

- `docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md` Section 7.2
- Foundation Models Tool Calling: `Tool` protocol 준수
- 4096 토큰 컨텍스트 윈도우 제한 주의
