---
source: review/security
priority: p2
status: done
created: 2026-02-15
updated: 2026-02-22
---

# iCloud 동기화 사용자 동의 UI

## Issue
건강 데이터가 사용자 동의 없이 자동으로 CloudKit에 동기화됨.

## Files
- `Dailve/App/DailveApp.swift`
- 새 파일: `Presentation/Shared/CloudSyncConsentView.swift`

## Fix
첫 실행 시 iCloud 동기화 동의 화면 표시. 거부 시 로컬 전용 모드.
