---
source: review/agent-native, review/architecture, review/data-integrity
priority: p3
status: done
created: 2026-02-16
updated: 2026-02-22
---

# P3 Review Follow-ups (2026-02-16)

## 1. Agent anti-patterns에 코드 예시 추가 (#16) — DONE

**File:** `.claude/skills/ui-testing/SKILL.md` Anti-Patterns 섹션
**Action:** 각 anti-pattern에 BAD/GOOD 코드 예시 추가 완료

## 2. Agent output format 상세화 (#17) — DONE

**File:** `.claude/agents/ui-test-expert.md`
**Action:** Output 포맷을 priority/카테고리/증거/패치 스니펫/커버리지 평점 구조로 상세화 완료

## 3. ~~AdaptiveNavigation 사용법 문서화~~ (RESOLVED)

**Note:** AdaptiveNavigation 삭제됨 (TabView(.sidebarAdaptable)로 교체). 더 이상 해당 없음.

## 4. CloudKit date precision/timezone roundtrip 검증 (#20) — AUTOMATED GUARD ADDED

**Actions Completed:**
- `DailveTests/CloudKitDateRoundtripTests.swift` 추가 (Date roundtrip drift guard)
- `docs/solutions/architecture/2026-02-22-cloudkit-date-roundtrip-validation.md` 추가 (실기기 CloudKit 검증 프로토콜)

**Note:** 실제 CloudKit transport 검증은 실기기 2대(iPhone/Watch)에서 별도 실행 필요
