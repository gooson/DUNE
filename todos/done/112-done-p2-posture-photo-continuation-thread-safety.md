---
source: review/swift-ui-expert, review/pr-reviewer
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-15
---

# photoContinuation 스레드 안전성 확보

## 문제

`PostureCaptureService`가 `@unchecked Sendable`이지만 `photoContinuation`에 동기화 없음.
- async 컨텍스트에서 write
- AVFoundation delegate 콜백 큐에서 read/clear
- 데이터 레이스 가능성

## 해결 방향

- serial DispatchQueue lock으로 보호
- 또는 actor-isolated wrapper로 변환
- 최소한 현재 안전한 이유를 주석으로 명시

## 영향 파일

- `DUNE/Data/Services/PostureCaptureService.swift`
