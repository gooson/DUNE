---
source: review/security
priority: p2
status: done
created: 2026-02-15
updated: 2026-02-22
---

# HealthKit 권한 상태 확인 후 쿼리 실행

## Issue
HK 쿼리 실행 전 `authorizationStatus(for:)` 확인이 없음. 권한 거부 시 silent failure 발생.

## Files
- `Dailve/Data/HealthKit/HealthKitManager.swift`
- 각 QueryService 파일

## Fix
`execute()` 내에서 권한 상태 확인 또는 각 서비스에서 사전 검증 추가.
