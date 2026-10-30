---
topic: live-activity-workout-icons
tags: [activitykit, watchos, workout, sf-symbols]
date: 2026-10-30
category: plan
status: approved
confidence: high
related_solutions:
  - architecture/2026-10-24-watch-workout-live-activity.md
  - general/2026-10-25-watch-workout-ended-live-activity-cleanup.md
related_brainstorms: []
---

# Implementation Plan: 운동별 Live Activity 아이콘

## Context

Running 운동에도 공통 `figure`가 표시된다. snapshot에는 운동명만 있고 종류가 없어 기존 구현이 이름을 추측하지 않고 중립 기호를 사용했다. Watch의 기존 `WorkoutActivityType.iconName`을 전송해 동일한 기호를 재사용한다.

## Requirements

- 진행 중 러닝·걷기·사이클·수영·근력 등 실제 운동에 맞는 SF Symbol을 표시한다.
- 잠금 화면, small, Island compact/minimal/expanded에서 같은 정책을 적용한다.
- paused/ended/stale 기호와 타이머·수치·미러링 lifecycle은 유지한다.
- 구버전 payload에 아이콘 필드가 없어도 decode하며 기존 공통 기호로 대체한다.

## Approach

optional `exerciseIconName`을 snapshot 끝에 추가하고 Watch에서 canonical iconName을 설정한다. iPhone 초기 미러도 세션의 HealthKit configuration에서 종류를 얻어 같은 매핑을 사용한다. Shared snapshot의 작은 phase symbol helper를 Widget이 소비한다. 새로운 enum 매핑이나 Widget의 Domain 의존성은 추가하지 않는다.

| Alternative | Decision |
|---|---|
| 운동명 키워드 추측 | 번역·사용자 이름·오탐 위험으로 제외 |
| Widget에 WorkoutActivityType 및 종속 모델 전체 추가 | 불필요한 target 의존성 증가로 제외 |
| canonical SF Symbol 문자열 전송 | 기존 iOS/Watch 매핑 재사용, 추가 payload 최소화 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| Shared/WatchWorkoutSnapshot.swift | 수정 | optional 기호 및 상태별 선택 |
| DUNEWatch/Managers/WorkoutManager.swift | 수정 | 실제 workoutMode의 iconName 전송 |
| DUNE/Presentation/Exercise/WatchWorkoutMirrorManager.swift | 수정 | 첫 snapshot에 HealthKit 종류 반영 |
| DUNEWidget/WatchWorkoutLiveActivity.swift | 수정 | 공통 기호 선택 소비 및 접근성 식별 |
| DUNE/Presentation/Exercise/WatchWorkoutActivityPreview.swift | 수정 | DEBUG fixture의 명시적 운동 종류 |
| DUNETests/WatchWorkoutSnapshotTests.swift | 수정 | JSON 호환·상태 우선순위·변경 전달 |
| DUNEUITests/Full/WatchWorkoutLiveActivityUITests.swift | 수정 | 시스템 표시의 종류별 아이콘 회귀 |
| docs/design/layout-map/watch-workout-live-activity.md | 부분 수정 | 아이콘 계약 추가, 기존 dirty hunk 제외 |
| docs/design/phone-design-map/actual/live-activity/* | 수정 | 새 캡처 또는 미갱신 범위 명시 |

## Implementation Steps

1. 레이아웃 계약에 운동별 기호 및 상태 우선순위를 기록한다.
2. snapshot·Watch producer·iPhone 초기 producer·Widget을 연결하고 단위 테스트를 추가해 커밋한다.
3. UI 전문가가 명시적 fixture·아이콘 검사를 추가한다. 파싱 및 빌드·관련 단위 테스트를 수행한다.
4. 시스템 표면 UI 검증 및 WLA01 캡처를 수집한다. 실패하면 원인·미검증 상태를 기록한다.
5. 5관점 리뷰·SwiftUI/UX/테스트 품질 점검·해결책 문서 후 검증 게이트 충족 시 Ship한다.

## Edge Cases

| Case | Handling |
|---|---|
| 구버전 payload | nil로 decode, figure fallback |
| 빈 기호·과도한 길이 | figure fallback, 운동 수치 업데이트 유지 |
| 일시 정지·종료·stale | pause.fill / checkmark / wifi.slash 우선 |
| 운동 종류 변경 | 매 snapshot에서 현재 workoutMode를 확인 |
| 근력 루틴의 종목 전환 | traditionalStrengthTraining.iconName 사용 |
| 첫 Watch 패킷 이전 | 미러 세션 configuration의 canonical 종류 사용 |

## Testing Strategy

- Swift Testing: 새 필드 roundtrip, legacy JSON, unknown 추가 키 호환, 기호 fallback 및 phase/stale 우선순위.
- `scripts/build-ios.sh`: iOS·embedded Watch·Widget 통합 빌드.
- `scripts/test-unit.sh`: 관련 snapshot/activity 테스트만 선택한다.
- UI 범위: Shared payload 변경으로 기본 full 판정. iOS/Watch 표준 runner·전용 기기·deadline을 준수한다. Watch UI 자체는 바꾸지 않으나 전송 모델 변경을 명시한다.
- 시스템 UI: 운동별 fixture, 접근성 식별자·실제 SF Symbol 값·제목/시간/수치 포함 프레임을 확인한다.
- WLA01: 새 iPhone 시스템 PNG를 우선 수집하고 iPad·Duo·Watch small·Island의 미갱신 상태를 구분한다.

## Risks

| Risk | Mitigation |
|---|---|
| 디스크 잔여 약 0.6GB로 작업트리 생성 실패 | 기존 dirty 변경을 보존하고 파일 단위 커밋. 빌드/시뮬레이터가 막히면 통과·머지하지 않는다 |
| 기존 stale UI fixture·Xcode 결과 정리 실패 이력 | 현 실행 근거를 확인하며 같은 원인 무변경 재시도 금지 |
| 실제 Watch↔iPhone 미러링은 simulator 한계 | 시드 시스템 UI와 실기기 연동 증거를 구분 |
| 사용자 디자인 시안 변경과 파일 공유 | index에 이번 추가 hunk만 반영하고 baseline diff 보존 |

## Research / Confidence

관련 solutions·brainstorms·todos를 실제 검색했다. 동일 아이콘 TODO나 계획은 없었다. 기존 아이콘 매핑·snapshot producer/consumer 및 WLA01 맵을 확인했다. Apple [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)와 [ActivityKit 표시 문서](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)를 확인했다. 코드 구조는 rg/Read를 사용했다(Serena 없음). 확신 high, 실행 환경은 공간 확보 전 미확정이다.
