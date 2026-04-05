---
tags: [watchos, posture, wearability, empty-state, watchconnectivity, backward-compatible]
date: 2026-04-05
category: general
status: implemented
related_files: [DUNE/Domain/Models/WatchConnectivityModels.swift, DUNEWatch/Managers/WatchPostureMonitor.swift, DUNE/Presentation/Wellness/Components/WatchPostureSummaryCard.swift, DUNE/Data/WatchConnectivity/WatchSessionManager.swift]
---

# Solution: Watch 자세 모니터링 미착용 시 안내 개선

## Problem

Watch 자세 모니터링 카드(iOS 웰니스탭)에서 워치 미착용 시 "No posture data yet"이라는 모호한 메시지만 표시되어, 사용자가 왜 데이터가 없는지 알 수 없었다.

### Root Cause

`DailyPostureSummary` DTO에 모니터링 활성화 상태 필드가 없어, iOS 측에서 "모니터링 꺼짐" vs "착용 안 함" vs "데이터 아직 없음"을 구분할 수 없었다.

## Solution

### 1. DTO 확장 (backward-compatible)

`DailyPostureSummary`에 `isMonitoringEnabled: Bool` 필드를 추가하고, custom `init(from:)` 디코더에서 `decodeIfPresent ?? true`로 기존 payload와 호환성을 유지.

`hasNoActivityData` computed property로 모든 카운터가 0인 상태(미착용 추정)를 감지.

### 2. Watch → iOS 상태 전송

`WatchPostureMonitor`가 모니터링 비활성화 시에도 summary를 전송하여 iOS가 상태를 알 수 있도록 함.

### 3. iOS 카드 4단계 empty state

`WatchPostureSummaryCard`에 `CardState` enum을 도입하여 4가지 상태를 명확히 분기:
- `.watchNotInstalled` → "Apple Watch required"
- `.monitoringDisabled` → "Posture monitoring disabled" + 활성화 안내
- `.notWorn` → "Wear your Apple Watch" + 착용 안내
- `.hasData` → 메트릭 표시

## Prevention

- WC DTO에 새 필드 추가 시 `decodeIfPresent + default` 패턴으로 backward compatibility 보장
- 빈 상태 카드는 가능한 원인별로 구체적 안내를 제공
- 카드 상태 분기는 enum으로 exhaustive하게 처리

## Lessons Learned

1. **WC DTO backward compatibility**: `init(from:)` custom decoder + `decodeIfPresent`로 기존 페이로드 호환. WatchSessionManager에서 summary 재구성 시에도 새 필드를 pass-through 해야 함.
2. **SwiftUI computed property 캐싱**: 같은 computed를 body에서 여러 번 호출하면 불필요한 재계산. `let state = cardState`로 캐싱 후 parameter threading이 효과적.
3. **worktree 경로 주의**: Edit/Write 도구 사용 시 worktree 경로(`/.claude/worktrees/{name}/`)를 정확히 지정해야 함. 메인 레포 경로로 편집하면 worktree에 반영 안 됨.
