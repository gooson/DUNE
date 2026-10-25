---
tags: [watchos, running, voice-feedback, avspeechsynthesizer, distance, accessibility]
category: architecture
date: 2026-10-25
severity: important
status: implemented-ui-validation-pending
related_files:
  - DUNEWatch/Managers/RunningVoiceFeedback.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/Cardio/CardioDistanceMetricsPage.swift
  - DUNEWatch/Views/ControlsView.swift
  - DUNEWatch/Views/SessionPagingView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-22-voice-coaching-pipeline.md
---

# Solution: Watch 러닝 거리 우선 화면과 짧은 음성 안내

## Problem

러닝 중 누적 km를 읽으려면 시간 중심 화면의 작은 거리 카드를 봐야 했고, 1km 통과는 진동·배너만 제공했다. 사용자는 Apple 기본 운동 앱과 같은 간결한 읽기 안내와 거리 우선 화면을 요청했다.

### Root Cause

기존 메인 화면은 다양한 유산소 운동을 공통으로 다뤘으며 시간에 가장 큰 글씨를 배정했다. 거리 경계 이벤트는 WorkoutManager에 있었지만 별도 음성 소비자가 없었다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| CardioDistanceMetricsPage.swift | 누적 km → 활성 시간·평균 페이스 → 심박 | 러닝 중 한눈에 거리 확인 |
| SessionPagingView.swift | running에서 거리 페이지가 기본, 기존 시간 페이지 유지 | 오른쪽 한 번에 제어·왼쪽 한 번에 시간 |
| RunningVoiceFeedback.swift | 짧은 TTS, 최근 거리 안내 하나만 대기, 상태 변화 우선 | 발화 누적·오래된 안내 방지 |
| WorkoutManager.swift | 기존 운동 상태와 km 경계에서 이벤트 전달 | View 생명주기와 발화 분리 |
| ControlsView.swift | 러닝 전용 음성 토글과 설정 유지 | 사용자가 운동 중 즉시 제어 |
| Watch Info.plist | Audio background mode | 활성 HKWorkoutSession의 백그라운드 안내 |
| Watch xcstrings | en/ko/ja 신규 키 23개 | 앱 언어와 발화 언어 일치 |

### 구간·목표 페이스 후속 확장

사용자의 후속 요청으로 `RunningFeedbackSettings`와 `RunningFeedbackTracker`, `RunningFeedbackSettingsView`를 추가한다. 설정 시트는 C17 안내 거리·볼륨과 C18 목표 페이스·허용 범위를 다루며, C16 제어 화면에서 진입한다.

- 안내 거리는 500m·1km·2km, 발화 볼륨은 0~100%다. 볼륨은 TTS utterance에 적용하며 시스템 음악 음량을 변경하지 않는다.
- 누적 거리와 활성 시간으로 해당 구간의 시간·페이스를 계산한다. 거리 경계가 두 표본 사이에 있으면 시간을 보간한다. 전체 평균인 기존 `currentPace`를 구간 또는 현재 페이스로 재사용하지 않는다.
- 목표 안내는 기본 비활성이며 사용자가 목표 페이스와 허용 범위를 정해 켠다. 최근 약 30초의 거리·활성 시간 창에서 페이스를 계산하고, 준비 30초·범위 이탈 지속 10초·공통 대기 60초를 적용한다. 같은 방향 안내는 목표 근처로 복귀해야 재활성화하고 반대 방향은 대기 후 허용한다.
- 센서 갱신이 늦어도 단조 증가하는 누적 거리의 구간은 계산한다. 오래된 표본으로 목표 코칭을 만들지 않도록 페이스 창만 초기화한다.
- 일시 정지 시간은 제외하고 거리 보정이 없는 재개에서는 부분 구간을 유지한다. 복구나 안내 간격 변경은 현재 위치부터 새 구간을 측정한다.
- 설정을 바꾸면 그 설정으로 더 이상 유효하지 않은 대기 안내를 폐기한다. 볼륨 변경만으로 진행 구간을 초기화하지 않는다.
- 실제 오디오 어댑터 `AVRunningVoiceSpeaker`를 별도 파일에 두고 계산·음성 정책 서비스는 기존 프로토콜을 통해 주입받는다. 이 구분으로 같은 실제 소스·기존 테스트를 macOS 호스트에서도 실행하고, Watch 오디오와 UI 실행 증거는 별도로 관리한다.

오디오는 `.playback`·`.voicePrompt`와 duck/다른 spoken audio 중단 옵션을 사용하며, 완료·취소·비활성화 때 세션을 해제해 다른 앱 오디오를 복원한다. 안내 실패는 로그로 남긴다. 출력은 Watch의 현재 오디오 경로를 사용하며 iPhone 이어폰으로 전달하는 별도 relay는 구현하지 않는다.

`currentPace`는 이름과 달리 기존 코드에서 전체 활성 시간 / 총 거리로 계산하므로 거리 화면에는 **평균 페이스**로 표시한다. 구간 음성은 tracker가 별도로 계산한 해당 구간 페이스를 사용한다. 일시 정지 중 늦게 도착한 HealthKit 거리 보정은 유지한다.

수동 종료는 전경에서만 짧게 말한다. 백그라운드 자동 종료는 HK 세션 종료 직후 운동 오디오 런타임이 사라지므로 발화를 생략한다. 운동 데이터 저장을 지연해 발화를 보장하지 않는다. 종료된 세션 복구에서도 종료 발화를 재생하지 않는다.

## Verification

- 최종 표준 앱 빌드가 통과했다: `.xcodebuild/watch-running-ship-final-build.log`, exit 0, `BUILD SUCCEEDED`. Watch의 전경 상태 조회는 현재 `WKApplication` API를 사용한다.
- 실제 생산 소스와 기존 테스트를 symlink로 연결한 호스트 Swift package에서 정책·설정 13개와 음성 서비스 11개, 합계 24개 테스트를 확인했다. 초기 영어 숫자 그룹 구분 기대값 실패는 실제 고정 en locale 결과에 맞춰 수정하고 해당 suite를 재검증했다.
- 이 증거는 구간·목표 계산, 정규화·저장, 음성 대기열과 주입한 mock speaker의 볼륨 전달에 적용된다. Watch 오디오 어댑터, 이어폰 경로·실제 음량의 실행 증거로 확대하지 않는다.
- 리뷰에서 무음 해제 후 목표 경고가 계속 비활성인 P2를 수정했다. 들을 수 있는 상태로 돌아오면 페이스 준비 상태만 재설정하고 진행 구간은 유지한다. 음성 토글·볼륨 해제 두 경우의 회귀 테스트가 통과했다. 미사용 kilometer 이벤트·번역 키와 폐기된 API도 정리했다. 남은 P1/P2는 없다.
- Watch 신규 키 23개의 en/ko/ja, 카탈로그 포맷과 diff 공백 검사를 확인했다.
- 표준 Watch UI 실행기는 관련 4개 selector를 선택했지만 저장소 시뮬레이터 잠금을 60초 내 확보하지 못해 exit 2로 종료했다. 테스트는 0개 실행됐고, 이후 비차단 잠금 확인도 busy였다. C14 거리·C15 정지·C16 제어·C17 설정·C18 목표의 새 실제 PNG는 없다.
- 이전 구현 단계에서 simulator metadata 자식에 닫힌 상위 FD 환경값이 전달되는 문제도 확인했다. 실행기 소스는 변경하지 않았고, 상위 잠금을 유지하면서 해당 metadata 자식에만 환경값을 제거하는 로컬 wrapper를 준비했다. 새 작업트리는 소유 기기를 아직 만들지 않았다.
- 필수 UI·실제 캡처가 미완료이므로 review-ship은 PR 생성·push·머지 전에 중단했다. 정확한 selector·로그·재개 조건은 [리뷰 보고서](../../reviews/2026-10-25-watch-running-feedback-review-ship.md)에 기록했다. 실제 발음·이어폰 출력·음악 복원은 실기기에서 별도 확인한다.

## Prevention

- 운동 음성 이벤트는 View의 onAppear/onChange가 아닌 세션 상태 전환에서 발생시킨다.
- 수동 pause/resume과 HealthKit delegate가 같은 전환을 반복 통지해도 한 번만 말한다.
- 1km 경계는 복구·일시정지·센서 흔들림에서 재생하지 않는 기존 정책을 유지한다.
- 평균 페이스와 최근 구간 페이스를 구분한다.
- 화면이 바뀌면 상태 ID와 캡처 테스트를 함께 추가하고 새로운 실제 PNG를 확인한다.

## Lessons Learned

Apple 스타일의 음성 UX는 필요한 순간의 짧은 안내와 음악 복원에 달려 있다. Siri 명령 통합과 TTS 읽기 안내는 별개다. 종료 이벤트는 호출 시점뿐 아니라 활성 운동 오디오 런타임이 언제 사라지는지도 고려해야 한다.

시작 시점에 Today 커밋과 Live Activity·테마의 미커밋 변경이 함께 있었다. 원래 작업트리는 보존하고 최신 main 기준의 별도 관리 작업트리와 `codex/watch-running-feedback` 브랜치에 러닝 변경만 옮겼다. 공유 파일은 기준 diff를 대조해 이번 수정만 반영했다.
