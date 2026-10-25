---
topic: watch-running-feedback
date: 2026-10-25
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-22-voice-coaching-pipeline.md
---

# Implementation Plan: Watch 러닝 음성 안내와 거리 우선 화면

## Context

사용자는 Apple 기본 운동 앱처럼 간결한 음성 안내와 러닝 중 km를 우선 읽는 화면을 요청했다. 기존 거리 통과 이벤트와 운동 상태 전환을 재사용한다.

## Requirements

- 실제 running 활동의 기본 페이지에 누적 km를 크게 표시하고 시간·평균 페이스·심박을 보조 표시한다.
- 기존 시간 중심 페이지를 유지하고 오른쪽 스와이프 한 번으로 제어에 접근한다.
- 러닝 시작·일시정지·재개·매 1km와 전경에서 조작한 종료에 짧게 읽으며 워치 제어 화면에서 끄거나 켤 수 있다. 백그라운드 자동 종료 시 활성 운동 오디오 런타임을 잃으므로 종료 발화는 생략한다.
- 영어·한국어·일본어, 일시정지·중복 delegate·세션 복구·센서 흔들림을 처리한다.
- 기존 dirty 변경은 보존하고 자동 커밋 범위에서 제외한다.
- 후속 요청: 500m·1km·2km마다 해당 구간 시간과 페이스를 읽고, 최근 페이스가 설정한 목표 범위를 벗어나면 빠름/느림을 안내한다.
- Watch 설정 시트에서 음성 간격·음량(앱 발화 볼륨)·목표 페이스·허용 범위·페이스 안내 활성화를 설정하고 재실행에도 유지한다.

## Approach

RunningVoiceFeedback가 TTS와 잠깐의 오디오 세션을 관리하고 WorkoutManager가 이벤트를 전달한다. 화면의 생명주기와 음성을 분리해 손목을 내리거나 페이지를 바꿔도 안내한다. Siri 명령이나 생성형 코칭은 추가하지 않는다. 기존 currentPace는 전체 평균이므로 구간 페이스로 표현하지 않는다.

후속 확장에서는 별도 RunningFeedbackTracker가 누적 거리와 활성 시간 표본을 받아 구간 경계를 보간하고 실제 구간 시간·페이스를 계산한다. 목표 비교에는 최근 30초 페이스를 사용하며 30초 준비 구간, 범위 이탈 10초 지속과 안내 간격 60초를 적용한다. 오래된/잘못된 표본이나 일시 정지·복구로 생긴 값은 코칭 근거로 사용하지 않는다. 안내 거리 변경은 현재 위치에서 새 구간을 시작하고, 볼륨 변경은 진행 중 구간을 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 기존 메인 화면 교체 | 페이지 수 감소 | 다른 운동과 기존 시간 화면 변경 | 별도 러닝 페이지만 추가 |
| Workout Buddy 의존 | 개인화 코칭 | 언어·기기·앱 통합 제약 | 로컬 TTS 사용 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| DUNEWatch/Managers/RunningVoiceFeedback.swift | 추가 | 음성 서비스·문구·오디오 자원 |
| DUNEWatch/Managers/RunningFeedbackSettings.swift | 추가 | 검증된 음성·목표 설정 |
| DUNEWatch/Managers/RunningFeedbackTracker.swift | 추가 | 구간·최근 페이스·안내 정책 |
| DUNEWatch/Managers/WorkoutManager.swift | 부분 수정 | 러닝 상태·거리 이벤트 연결 |
| DUNEWatch/Views/Cardio/CardioDistanceMetricsPage.swift | 추가 | 누적 거리 우선 화면 |
| DUNEWatch/Views/SessionPagingView.swift | 수정 | 러닝 초기 페이지 |
| DUNEWatch/Views/ControlsView.swift | 수정 | 음성 토글 |
| DUNEWatch/Views/Cardio/RunningFeedbackSettingsView.swift | 추가 | 워치 음성·페이스 설정 시트 |
| DUNEWatch/Resources/Localizable.xcstrings | 수정 | 3개 언어 |
| DUNE/project.yml | 필요 시 수정 | Audio background mode |
| DUNEWatchTests·DUNEWatchUITests | 추가·수정 | 음성 정책 및 화면 회귀 |
| docs/design/layout-map·phone-design-map | 추가·수정 | 설계·실제 캡처 동기화 |

## Implementation Steps

1. 레이아웃 맵과 테마 기준을 확인하고 거리 페이지·가로 페이지 순서를 구현한다.
2. 음성 서비스와 상태/거리 이벤트, 음성 설정을 연결한다.
3. 음성 정책 단위 테스트와 러닝 화면 UI 테스트를 실행한다.
4. 전용 Watch에서 영향 화면 C14·C15·C16을 캡처하고 실제 화면맵을 갱신한다.
5. 후속 요청의 구간 계산·목표 안내·설정 저장과 경계 조건 단위 테스트를 추가한다.
6. C16의 새 설정 진입과 C17 설정·C18 목표 페이스를 관련 UI 테스트와 새 실제 캡처로 확인한다.

## Edge Cases

| Case | Handling |
|---|---|
| 일시정지 후 종료 | 불필요한 재개 음성을 내지 않는다 |
| HealthKit 중복 상태 통지 | 실제 상태가 바뀔 때 한 번만 안내 |
| 세션 복구 | 이전 km 재안내 없이 이후 경계부터 안내 |
| 거리/페이스 NaN·무한대 | 기존 거리 검증과 음성 문구 검증 |
| 음성 끄기·재설정 | 발화 중지와 오디오 세션 해제 |
| 이어폰·음악 | 발화 동안만 duck, 출력 경로는 watchOS 사용 |
| 구간 경계가 두 표본 사이에 있음 | 활성 시간을 거리 비율로 보간한다 |
| 목표 근처 흔들림 | 준비·지속 시간과 공통 대기 시간으로 반복 억제 |
| 안내 거리 변경 | 현재 위치부터 새 구간 시작, 지난 구간 재생 없음 |
| 볼륨 0·설정 NaN·범위 밖 값 | 발화/duck 생략·정규화된 설정 사용 |

## Testing Strategy

- 새 음성 서비스의 문구·설정·중복/잘못된 값 정책 단위 검증.
- Watch 전용 표준 실행기와 소유 시뮬레이터에서 관련 UI selector만 실행.
- C14 거리 진행·C15 정지·C16 음성 제어의 실제 PNG 확인.
- 실제 이어폰 음량·발음은 실기기 검증 항목으로 별도 명시한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| watchOS 오디오 API 제약 | 중간 | 높음 | SDK 가용성 확인·실기기 확인 항목 구분 |
| 기존 작업과 파일 중첩 | 높음 | 중간 | 기준 diff 보존·이번 변경만 부분 적용 |
| 시뮬레이터/결과 정체 | 중간 | 중간 | 표준 deadline·원인 변경 없는 반복 금지 |

## Confidence Assessment

후속 확장과 리뷰 수정까지 구현했고 최종 앱 빌드, 호스트 단위 24건, 서로 다른 Watch UI 4건을 확인했다. 40mm 거리 화면의 심박 줄 개선은 영향 1건을 추가 재검증했다. C14–C18 새 캡처를 실제 화면맵에 등록했다. 원래 Today·Live Activity·테마 변경은 보존하고 최신 main 기준의 별도 브랜치로 분리했다. [최종 리뷰와 제한](../reviews/2026-10-25-watch-running-feedback-review-ship.md)을 따른다.

기존 1km 경계·활성 시간·페이지 구조를 재사용하므로 높음. 실기기 오디오 출력은 시뮬레이터 테스트와 구분한다.
