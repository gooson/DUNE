---
source: review/security+agent
priority: p3
status: done
created: 2026-02-15
updated: 2026-02-22
---

# OSLog 에러 로깅 추가

## Issue
에러가 UI 표시만 되고 로그가 없음. HK 권한 거부, 쿼리 실패 등 감사 추적 불가.

## Fix
`Logger(subsystem: "com.dailve.health", category:)` 사용하여 주요 에러/이벤트 로깅.
