---
source: brainstorm/apple-on-device-ml-sdk-research
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# AI 코칭 메시지 (Foundation Models)

## 설명

기존 rule-based CoachingEngine을 Foundation Models 프레임워크로 강화하여 개인화된 자연어 코칭 메시지를 생성합니다.

## 구현 범위

- `@Generable` 구조체로 코칭 메시지 스키마 정의
- 기존 `CoachingInput` 데이터를 Foundation Models 프롬프트에 전달
- A17 Pro+ 디바이스에서만 활성화, 미지원 디바이스는 기존 template 유지
- `CoachingEngine` 내부에서 Foundation Models 호출 → `CoachingInsight` 변환

## 참고

- `docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md` Section 7.1
- 기존: `DUNE/Domain/UseCases/CoachingEngine.swift`
- Foundation Models: iOS 26+, A17 Pro+ 전용
