---
source: review/agent-native, review/architecture, review/data-integrity
priority: p3
status: ready
created: 2026-02-16
updated: 2026-02-16
---

# P3 Review Follow-ups (2026-02-16)

## 1. Agent anti-patterns에 코드 예시 추가 (#16)

**File:** `.claude/skills/ui-testing/SKILL.md` Anti-Patterns 섹션
**Action:** 각 anti-pattern에 BAD/GOOD 코드 예시 추가

## 2. Agent output format 상세화 (#17)

**File:** `.claude/agents/ui-test-expert.md`
**Action:** Output 포맷을 다른 리뷰어(security, performance 등)와 동일한 수준으로 상세화

## 3. AdaptiveNavigation 사용법 문서화 (#18)

**File:** `AdaptiveNavigation.swift` 또는 `.claude/rules/`
**Action:** 새 View 생성 시 `adaptiveNavigation(title:)` 사용 규칙 문서화
**Note:** TODO #009 (NavigationStack 중앙화)와 함께 처리

## 4. CloudKit date precision/timezone roundtrip 검증 (#20)

**Action:** SwiftData + CloudKit 환경에서 Date의 시간대/정밀도가 디바이스 간 동일하게 전달되는지 검증
**Note:** 실기기 테스트 필요
