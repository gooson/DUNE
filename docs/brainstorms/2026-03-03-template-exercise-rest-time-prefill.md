---
tags: [rest-time, template, prefill, workout, previous-session]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Template Exercise Rest Time Prefill

## Problem Statement

현재 운동 세션에서 weight/reps는 이전 세션 기록을 자동으로 prefill하지만(`PreviousSetInfo` → `previousSets`), **휴식시간은 항상 글로벌 설정값 또는 하드코딩 값을 사용**한다.

사용자가 특정 운동에서 실제로 사용한 휴식시간은 `WorkoutSet.restDuration` 필드가 있지만 **항상 nil**로 저장되어 이전 기록을 참조할 수 없다.

**원하는 동작**:
- **처음 수행하는 운동**: `TemplateEntry.restDuration` → 글로벌 설정값 순서로 fallback
- **이전 기록이 있는 운동**: 마지막 세션에서 실제 사용한 휴식시간을 prefill

이는 weight/reps의 기존 prefill 패턴과 동일한 패턴을 rest time에도 확장하는 것이다.

## Target Users

- iOS + Watch 모든 사용자
- 특히 운동별로 다른 휴식시간이 필요한 사용자 (예: 벤치프레스 3분, 바이셉 컬 1분)

## Success Criteria

- [ ] 세트 완료 후 rest timer가 끝나거나 skip되면 실제 사용한 시간이 `WorkoutSet.restDuration`에 저장
- [ ] `PreviousSetInfo`에 `restDuration` 필드 추가
- [ ] 다음 세션에서 이전 기록의 rest time이 prefill되어 타이머에 반영
- [ ] 이전 기록이 없으면 `TemplateEntry.restDuration` → 글로벌 설정값 순서로 fallback
- [ ] iOS와 Watch 모두 동일 로직 적용

## Proposed Approach

### 1. WorkoutSet.restDuration 저장 (현재 항상 nil)

**iOS** (`WorkoutSessionView`):
- 세트 완료 → rest timer 시작 → timer 완료/skip 시 실제 경과 시간을 캡처
- `createValidatedRecord()` 시 각 set의 `restDuration`에 캡처한 값 할당

**Watch** (`MetricsView`):
- 동일 패턴: rest timer 완료/skip 시 실제 경과 시간 캡처 → `CompletedSetData`에 포함

### 2. PreviousSetInfo 확장

```swift
struct PreviousSetInfo: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    let restDuration: TimeInterval?  // NEW
}
```

`loadPreviousSession()` 에서 `WorkoutSet.restDuration` 매핑 추가.

### 3. Rest Time Prefill 우선순위

```
1. 이전 세션의 실제 rest time (previousSets[index].restDuration)
2. TemplateEntry.restDuration (운동별 override)
3. WorkoutDefaults.restSeconds (글로벌 설정)
```

### 4. 적용 지점

**iOS**:
- `WorkoutSessionView.startRest()`: prefill된 rest time으로 타이머 시작
- `RestTimerViewModel`: 외부에서 duration 주입 받도록 이미 `start(seconds:)` 지원

**Watch**:
- `MetricsView.currentRestDuration`: previousSets → template → global fallback 체인

## Constraints

- `WorkoutSet`은 `@Model` (SwiftData) → CloudKit 동기화 대상, nil → 값 변경은 안전
- Watch DTO `CompletedSetData`에도 `restDuration` 필드 추가 필요 (양쪽 target 동기화, Correction #69, #138)
- 기존 brainstorm의 30초 하드코딩 수정은 이 범위에 포함하지 않음 (별도 작업)

## Edge Cases

1. **rest timer를 사용하지 않고 바로 다음 세트 진행**: restDuration = nil 유지 → 다음 세션 prefill 시 fallback 체인 사용
2. **마지막 세트 이후 rest**: 마지막 세트 뒤 rest는 기록하지 않음 (다음 세트가 없으므로)
3. **세트 삭제/재정렬**: restDuration은 세트에 바인딩, 세트 삭제 시 함께 제거
4. **이전 세션의 세트 수가 다른 경우**: 현재 세트 인덱스에 대응하는 이전 세트가 없으면 fallback
5. **+30초 추가한 경우**: 타이머에 설정된 최종 duration(예: 90+30=120초)이 아닌, 실제 경과 시간 저장

## Scope

### MVP (Must-have)
- [ ] `WorkoutSet.restDuration`에 실제 사용 시간 저장 (iOS)
- [ ] `PreviousSetInfo`에 `restDuration` 추가
- [ ] iOS 다음 세션에서 rest time prefill
- [ ] Watch `CompletedSetData`에 `restDuration` 추가
- [ ] Watch 다음 세션에서 rest time prefill

### Nice-to-have (Future)
- [ ] 30초 하드코딩 수정 (별도 brainstorm에서 다룸)
- [ ] rest time 통계/분석 (운동별 평균 휴식시간 등)
- [ ] rest time 트렌드 차트

## Open Questions

1. ~~이전 기록 범위~~ → 같은 운동 기준 (exerciseDefinitionID 매칭)
2. ~~저장 시점~~ → 타이머 완료/스킵 시 자동 저장
3. ~~플랫폼 범위~~ → iOS + Watch 모두
4. ~~기능 범위~~ → rest time prefill만 (30초 하드코딩 수정 별도)

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] 구현 후 기존 `WorkoutSessionViewModelTests`에 rest time prefill 테스트 추가
