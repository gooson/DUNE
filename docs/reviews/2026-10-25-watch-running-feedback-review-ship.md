# Code Review Report

> Date: 2026-10-25
> Scope: Watch running distance-first screen, split/target-pace voice cues and settings only
> Base: a5e9052c76f9278bda8bd2cf54422d28a8a1a8fe (`origin/main`)
> Branch: `codex/watch-running-feedback`

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 - Critical | 0 | None |
| P2 - Important | 1 | Resolved |
| P3 - Minor | 2 | Resolved |

2759줄의 전체 변경(미추적 파일 포함)을 보안·성능·아키텍처·데이터 무결성·단순성 관점에서 parent가 직접 검토했다. review 스킬의 2000줄 이상 직접 검토 규칙을 적용했다. Agent-Native는 설정·프롬프트 변경이 없어 생략했다. UI/음성의 품질 게이트도 별도로 확인했다.

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Data Integrity Guardian] data-001 · 무음 해제 후 페이스 경고 비활성 상태 유지

- **File**: DUNEWatch/Managers/RunningVoiceFeedback.swift:44
- **Category**: data
- **Issue**: 음성이 꺼지거나 볼륨이0인 동안에도 tracker가 경고를 소비해 disarm한다. 다시 들을 수 있는 상태가 되어도 같은 방향의 경고가 돌아오지 않는다.
- **Suggestion**: 들을 수 있는 상태로 돌아올 때 페이스 준비 상태만 갱신하고 부분 구간은 보존한다. 음성 토글·볼륨 복귀를 실제 서비스 테스트로 재현한다.
- **Status**: Resolved

## P3 Findings (Consider)

### [Code Simplicity Reviewer] simp-001 · 이전 kilometer 이벤트가 테스트에만 남음

- **File**: DUNEWatch/Managers/RunningVoiceFeedback.swift:19
- **Category**: simplicity
- **Issue**: 실제 안내는 split 이벤트를 사용하는데 평균 페이스 kilometer 분기와 번역 키가 테스트 때문에 남아 있다.
- **Suggestion**: 미사용 이벤트와 키를 제거하고 테스트를 split 경로로 전환한다.
- **Status**: Resolved

### [Code Simplicity Reviewer] simp-002 · 추가 코드의 폐기된 Watch API

- **File**: DUNEWatch/Managers/WorkoutManager.swift:657
- **Category**: simplicity
- **Issue**: 새 종료 분기에 watchOS9.2 이후 폐기된 WKExtension API가 사용됐다.
- **Resolution**: 현재 SDK의 WKApplication.shared().applicationState로 교체했다. 기존 다른 파일의 폐기 경고는 이번 범위에 포함하지 않는다.
- **Status**: Resolved

## Resolve Evidence

- data-001: 음성 토글/볼륨 무음 해제 시 페이스 준비 상태만 초기화하고 진행 구간을 유지한다. 두 인자의 실제 서비스 회귀를 확인했다.
- simp-001: 이전 kilometer 이벤트·번역 키를 제거하고 기존 대기열·잘못된 값 테스트를 실제 split 이벤트로 전환했다. 참조 검색에서 잔여 코드가 없다.
- 초기 호스트 실행에서 영어 숫자 그룹 구분 기대값 3개가 실패했다. 고정 en locale의 실제 결과(1,000/2,000/3,000)를 반영해 해당 서비스 suite11개를 재검증했고 모두 통과했다. 정책·설정13개는 첫 실행에서 통과했으며 이후 해당 코드/테스트는 변하지 않았다.
- WKApplication 교체 후 새 작업트리의 최종 앱 빌드가 통과했다(`.xcodebuild/watch-running-ship-final-build.log`, exit 0). 추가 API의 폐기 경고가 사라졌고 AppIntents 메타데이터 생략 안내만 남았다.

## Localization Verification

SwiftUI 문구는 LocalizedStringKey, 프로그램 음성 문구는 String(localized:)를 사용한다. 새 레이블·음성 키의 en/ko/ja를 확인했다. 숫자/단위 포맷과 식별자는 번역 대상에서 구분했다. helper의 레이블 타입과 enum rawValue 누출을 확인했다.

## Positive Observations

- 음성 출력 어댑터·검증 가능한 정책·화면을 분리했다.
- 활성 시간 기반 구간 계산과 지연 표본·일시 정지·설정 변경의 기존 회귀 테스트가 있다.
- 기존 Today 커밋과 Live Activity/테마 미커밋 변경을 원래 작업트리에 보존하고 최신 main 기준 별도 작업트리로 러닝 범위만 분리했다.

## Checks and Ship Gate

- 단위: 실제 소스와 테스트를 연결한 호스트 package에서 정책·설정 13건이 통과했다. 영어 숫자 기대값 수정 후 영향받은 음성 서비스 suite 11건을 재실행해 모두 통과했다. 합계 24개 테스트이며 Watch 오디오 어댑터 실행 증거는 아니다.
- 빌드: 표준 `scripts/build-ios.sh`가 최종 소스에서 통과했다. 카탈로그 포맷, 신규 키 23개의 en/ko/ja, `git diff --check`도 확인했다.
- Watch UI: 표준 실행기에서 아래 4개 selector를 선택했으나 저장소 잠금을 60초 내 확보하지 못해 exit 2로 종료했다(`.xcodebuild/watch-running-ship-ui.log`). 실행된 테스트는 0개다. 최종 빌드 이후 비차단 잠금 확인도 busy였으므로 추가 실행하지 않았다.
- 범위: Watch 화면·설정·실제 캡처에 직접 영향을 받는 4건만 선택했다. 프로젝트 파일은 새 Watch 소스 참조 추가뿐이며 iOS 동작은 바뀌지 않았다. 자동 판정기의 full은 실행하지 않았고 targeted 결과를 full 통과로 표시하지 않는다.
- Ship: 필수 UI와 C14–C18 새 캡처를 확인할 수 없어 PR 생성·push·머지·작업트리 정리를 보류했다. 원래 작업트리의 변경은 보존한다.

### 재개 절차

저장소 시뮬레이터 잠금을 실제로 확보할 수 있고 소유권 metadata 호출이 정상인 상태에서, 이 작업트리의 전용 Watch를 표준 실행기로 사용한다. 다른 작업의 기기나 실행을 중단하지 않는다. 기존 실패와 재시도 횟수는 새 turn에서도 유지한다.

```sh
DUNE_UI_TEST_WALL_TIMEOUT=600 DUNE_UI_TEST_IDLE_TIMEOUT=180 \
DUNE_WATCH_SIM_NAME='Apple Watch SE 3 (40mm)' \
bash .codex-checks/running-review-ship/run-with-metadata-fd.sh scripts/test-watch-ui.sh \
  --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testRunningDistanceMetricsAndPausedDesignMap \
  --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testRunningVoiceFeedbackTogglePersistsAcrossNavigationAndRelaunch \
  --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testRunningFeedbackSettingsPersistAcrossSheetAndRelaunch \
  --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testCaptureRunningDesignMap \
  --log-file .xcodebuild/watch-running-ship-ui-resume.log
```

metadata 보정 wrapper는 기존 실행기 소스를 변경하지 않고 registry 자식에만 닫힌 상위 FD 환경값을 전달하지 않는다. 저장소 잠금은 상위 실행기가 계속 보유한다. 통과한 xcresult를 `python3 docs/design/watch-workout/collect-actual-captures.py <xcresult>`에 전달해 C14–C18의 새 PNG·출처·갤러리를 갱신하고 직접 확인한 후 최종 PR 검토와 ship을 재개한다. 실제 발음·이어폰 경로·음악 복원은 실기기에서 별도 확인한다.

## Next Steps

- [x] data-001 수정·회귀 검증
- [x] simp-001 안전한 제거·관련 검증
- [x] simp-002 현재 API 교체·최종 빌드
- [ ] Watch UI와 실제 캡처
- [ ] 최종 PR 검토·원격 머지·소유 기기/작업트리 정리
