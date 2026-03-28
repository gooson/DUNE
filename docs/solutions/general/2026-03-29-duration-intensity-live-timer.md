---
tags: [durationIntensity, plank, timer, watch, ios, ux]
date: 2026-03-29
category: general
status: implemented
---

# durationIntensity 운동 세트별 라이브 타이머

## Problem

플랭크 등 `durationIntensity` inputType 운동이 수동 ±1분 picker를 사용하여
실제 운동 흐름과 맞지 않았음. 러닝처럼 CardioSession을 쓰면 실내/아웃도어
선택과 걸음수/거리 등 불필요한 메트릭이 표시됨.

## Solution

**strength flow(세트 구조)를 유지**하면서 수동 분 입력만 라이브 카운트업 타이머로 교체.

### 핵심 설계

- `@State var setTimerStart: Date?` (Watch) / `var setTimerStarts: [UUID: Date]` (iOS ViewModel)
- `TimelineView(.periodic(from: .now, by: 1))` 로 매초 갱신
- "세트 완료" 탭 시 `Date().timeIntervalSince(start)` → 경과 초를 duration으로 기록
- 세트 전환 시 타이머 자동 리셋

### iOS/Watch 단위 통일

- 둘 다 **초(seconds)** 단위로 저장
- `durationDistance`(러닝)는 기존대로 분(minutes) 단위 유지
- `createValidatedRecord()`에서 inputType별 분기하여 변환

### 주의사항

1. **Timer start date는 유효한 duration 확인 전까지 삭제하지 않음** — double-tap 방지
2. **`prefillFromEntry()` 시작 시 `setTimerStart = nil`** — 운동 전환 시 stale timer 방지
3. **상한 7200초(2시간)** — 실수로 타이머를 놔두고 잤을 때 방지
4. **startDate를 TimelineView 외부에서 캡처** — ViewModel dict 관찰 의존성 제거

## Prevention

- `durationIntensity` 운동에 새 UI 추가 시 CardioSession이 아닌 strength flow 내 타이머 패턴 사용
- iOS/Watch 간 duration 저장 단위 불일치 주의 (durationIntensity=초, durationDistance=분)
