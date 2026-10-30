---
topic: live-activity-gold-preferences
date: 2026-10-30
status: approved
confidence: medium
related_solutions:
  - architecture/2026-10-24-watch-workout-live-activity.md
  - architecture/2026-10-30-live-activity-workout-icons.md
---

# Implementation Plan: Gold Impact Live Activity와 종목별 지표 선택

## Context

사용자가 선택한 골드 임팩트 시안과 유산소 거리·웨이트 현재 세트 중량 선택을 실제 앱에 적용한다. 기존 운동 아이콘 수정 e5fc1d00을 기준으로 격리한다. 원래 워크트리의 Siri 등 무관한 변경은 보존한다.

## Requirements

- 유산소는 시간/거리/심박, 웨이트는 시간/현재 세트 중량/심박을 각각 저장한다.
- 기존 사용자의 기본 표시는 시간으로 유지하고 명시적 선택을 우선한다.
- 거리 지원 여부·현재 입력 중량은 producer 메타데이터로 전달한다. 이름이나 과거 세트로 추측하지 않는다.
- 미수신은 시간 fallback, 실제 0은 0 표시, paused/stale/ended 우선순위 유지.
- 골드 수치와 입체 운동 심벌·잠금 화면 능선을 적용한다. Island의 시스템 검은 표면과 제한 폭을 유지한다.
- 실제 상태는 작은 시안과 구분한다. 위험한 반복 애니메이션·가짜 진행률을 추가하지 않는다.

## Approach

Foundation-only Shared 모델에서 선택·검증을 통합하고 iPhone의 preference를 App Group에 기록한다. Watch snapshot은 optional 새 필드로 옛 JSON과 호환한다. SwiftUI Widget은 이 단일 선택 정책으로 모든 표면을 렌더링한다. 설정 변경 시 활성 Live Activity를 갱신해 재시작 없이 반영한다.

| Alternative | Decision |
|---|---|
| 운동명으로 종목 판단 | locale·커스텀 이름 때문에 제외 |
| 마지막 완료 세트 중량 재사용 | 편집 중 현재 입력과 달라 제외 |
| per-second Watch transport | 시스템 타이머 사용, 추가 전송 제외 |

## Affected Files

| File | Change | Purpose |
|---|---|---|
| Shared/WatchWorkoutSnapshot.swift | modify | 종류·거리 가용성·현재 입력 중량 optional metadata |
| Shared/WorkoutLiveActivityPreferences.swift | add | 종목별 선택·유효 값 fallback·공유 저장 |
| DUNEWatch/Managers/WorkoutManager.swift | modify | 현재 입력과 snapshot 연결·전환 시 초기화 |
| DUNEWatch/Views/MetricsView.swift | modify | 현재 중량 prefill/편집 게시 |
| DUNE/Presentation/Settings/SettingsView.swift | modify | 종목별 picker와 외형 선택 |
| DUNE/Presentation/Exercise/WatchWorkoutActivity.swift | modify | 설정 변경 활성 카드 갱신 |
| DUNEWidget/WatchWorkoutLiveActivity.swift | modify | 선택한 주 지표·골드 표현·제한 폭 |
| Shared/Resources/Localizable.xcstrings | modify | en/ko/ja |
| DUNETests / DUNEWatchTests / DUNEUITests | modify/add | 호환·정책·현재 값·설정과 시스템 표면 |
| docs/design, docs/solutions | modify/add | 시안·현재 계약·실제 캡처와 검증 범위 |

## Implementation Steps

1. Shared wire metadata·지표 선택 정책·preferences와 호환/숫자 경계 테스트를 구현한다.
2. Watch 현재 입력 중량을 게시하고 transition/reset·미러 전송을 연결한다.
3. iPhone 설정과 활성 Live Activity 갱신, 번역·설정 UI 검사를 구현한다.
4. Widget 전체 표면에 주 지표와 골드 임팩트 표현을 적용한다. 제한 폭은 상태 기호 또는 짧은 값과 단위를 유지한다.
5. 프로젝트 표준 빌드·영향 단위/UI 검사, 전용 시뮬레이터 캡처·디자인맵 갱신, 관점별 리뷰 후 해결·문서화·ship을 진행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 옛 Watch payload | optional 필드 누락 허용, 시간 fallback |
| 거리 없는 유산소 | 거리 선택은 저장하되 현재 운동은 시간 fallback |
| 0 / nil / 비정상 값 | 0 보존, nil fallback, 음수·NaN·무한대 거부 |
| 세트/종목 전환 | 이전 입력을 새 현재 세트로 보내지 않고 초기화 |
| stale/paused/ended | 오래된 수치 숨김·정지 시간 고정·기존 즉시 제거 |
| 긴 이름·큰 글씨·장시간 | 심벌 축소/생략·지표 줄 분리·시스템 폭 준수 |

## Testing Strategy

- 관련 Shared snapshot/선택/저장 단위 테스트와 Watch 입력 경계 테스트만 실행한다.
- 표준 scripts/build-ios.sh 통합 빌드로 iOS/Widget/embedded Watch를 확인한다.
- scripts/plan-ui-tests.py의 판정과 호출부 분석 후 Settings·WatchWorkoutLiveActivity 관련 selector를 표준 실행기로 실행한다. 전체 회귀는 자동 확대하지 않는다.
- 전용 기기의 새 PNG와 실제 상태를 확인한다. iPad/Duo/Watch small 및 Island 미수행은 개별 명시한다.
- 이전 브라우저 실패는 환경 정상화 증거 없이 반복하지 않는다. 네이티브 검증과 별개다.

## Risks

현재 중량의 소유권·전환 순서, App Group 설정 갱신, 구버전 wire 호환이 핵심 위험이다. 제한 폭에서는 실시간 타이머를 임의 문자열로 고정하지 않는다. 실행 환경 실패는 앱 실패나 검증 통과로 숨기지 않으며 실패 원인에 대한 변화가 확인된 경우에만 1회 재시도한다.

## 실행 결과

네이티브 구현·소스 수정·일반 빌드·UI 테스트 앱 빌드와 관련 단위51개, Settings 저장·재실행 검증을 완료했다. 최종 시스템 UI는 환경 조회 단계에서 testcase0건으로 중단돼 UI/Pre-Ship/Ship은 통과하지 않았다. 초안 PR로 코드를 보존하며 실제 캡처가 없는 화면을 완료로 표시하지 않는다. 상세 상태는 [검증 기록](../reviews/2026-10-30-live-activity-gold-preferences.md)을 따른다.
