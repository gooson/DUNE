---
tags: [activitykit, watchos, workout-mirroring, sf-symbols, backward-compatibility, recovery]
category: architecture
date: 2026-10-30
status: reviewed
severity: minor
related_files:
  - Shared/WatchWorkoutSnapshot.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNE/Presentation/Exercise/WatchWorkoutMirrorManager.swift
  - DUNEWidget/WatchWorkoutLiveActivity.swift
  - DUNETests/WatchWorkoutSnapshotTests.swift
  - DUNEUITests/Full/WatchWorkoutLiveActivityUITests.swift
related_solutions:
  - architecture/2026-10-24-watch-workout-live-activity.md
---

# Solution: 실제 운동 종류에 맞는 Live Activity 아이콘

## Problem

Running 운동이 진행 중인데도 라이브 액티비티에 공통 `figure` 아이콘이 표시됐다. 기존 `WatchWorkoutSnapshot`은 운동명만 전송했으며, Widget이 이름을 추측하지 않고 중립 기호를 사용하는 의도적인 제약이었다.

## Solution

| File | Change | Reason |
|---|---|---|
| Shared snapshot | optional `exerciseIconName`, `phaseIconName(isStale:)` | 구버전 JSON 호환과 모든 표면의 공통 상태 정책 |
| Watch WorkoutManager | live HK 세션의 종류 → canonical `.iconName` | 복구 메타데이터가 없어도 실제 유산소 운동의 아이콘 유지 |
| iPhone mirror manager | 초기 HK configuration에서 canonical 기호 설정 | 첫 Watch 패킷 전부터 운동 종류 반영 |
| Widget | 공통 선택 함수·시스템 기호 존재 검사 | 잠금 화면·small·Island에서 같은 동작, 없는 기호는 figure로 대체 |
| DEBUG fixture / UI tests | 명시적 running/cycling/strength 종류와 시스템 캡처 | 사용자 지정 이름으로 종류를 추측하지 않는 검증 |

`exerciseIconName: String? = nil`은 기존 init 호출을 유지하고, synthesized Codable의 `decodeIfPresent`로 누락된 옛 payload를 허용한다. 옛 수신기는 추가 JSON 키를 무시한다. 운동명·locale·기록 이름은 종류 판정에 사용하지 않는다.

진행 중에는 러닝 `figure.run`, 걷기 `figure.walk`, 사이클 `figure.outdoor.cycle`, 수영 `figure.pool.swim`, 근력 `dumbbell.fill` 등 기존 매핑을 재사용한다. stale은 `wifi.slash`, paused는 `pause.fill`, ended는 `checkmark`를 우선한다. 누락·빈 문자열·과도한 길이는 공통 기호로 처리하며 운동 수치를 버리지 않는다. 실제 존재 여부는 UIKit을 쓸 수 있는 Widget의 View init에서 확인하므로 Shared 모델은 Foundation-only를 유지한다.

복구 시 로컬 `workoutMode`는 데이터 누락이나 옛 스키마 때문에 `.strength`로 남을 수 있다. 라이브 HealthKit 세션이 있으면 그 configuration을 우선한다. 이 수정은 복구 모드나 거리 계산을 바꾸지 않고 표시 종류만 바로잡는다.

헤더의 아이콘은 옆 상태 텍스트와 중복해 읽히지 않게 `accessibilityHidden(true)`를 유지한다. compact/minimal의 독립 아이콘에는 기존 현지화 레이블을 유지하며 SF Symbol 이름은 음성 값으로 노출하지 않는다. 의미가 생긴 운동 기호에도 `privacySensitive()`를 적용한다. 헤더의 실제 기호는 캡처 육안 검사 대상이며, 존재하지 않는 접근성 요소를 노출하도록 제품 UX를 변경하지 않는다.

## Verification

- 최종 Widget UIKit fallback·접근성 복원 후 `scripts/build-ios.sh --no-regen` 통합 빌드 통과. iOS·embedded Watch·Widget을 확인했다. 로컬 로그: `.codex-checks/live-activity-icons/ios-build-final.log`.
- 변경 Swift 파일 구문 검사 및 `git diff --check` 통과.
- 실제 `Shared/WatchWorkoutSnapshot.swift`를 macOS에서 컴파일한 호스트 검사 39개 단언 통과: JSON 양방향 호환, 운동별 기호, identity, 빈/누락/과도한 메타데이터, paused/ended/stale 우선순위. Xcode 단위 테스트나 UI suite의 통과로 해석하지 않는다.
- 실제 저장소의 Swift Testing 파일과 4개 production 파일을 symlink한 임시 macOS SwiftPM 타깃에서 `WatchWorkoutSnapshotTests` 15개가 통과했다. 모델 stub이나 수정한 테스트 복제본은 사용하지 않았다. Xcode iOS/Watch 테스트 실행과는 구분한다.
- 5관점 리뷰 및 SwiftUI·Apple UX·종합 품질 검토를 수행했다. 복구 종류·중복 VoiceOver·미지원 기호 P2를 수정하고 담당 검토자가 해소를 확인했다. 소스상 미해결 P1/P2는 없으며 실행 검증은 별도 게이트다.
- [WLA01 실제 화면맵](../../design/phone-design-map/actual/live-activity/index.html)에 새 캡처 대기와 기기별 미확인 범위를 명시한다. 기존 PNG는 이번 아이콘 변경의 증거가 아니다. 실제 Watch↔iPhone 전송 검증은 DEBUG 시드 시스템 UI와 구분한다.

## Prevention

- 표시 정보가 payload에 없으면 이름으로 역추론하지 않고 실제 producer의 canonical 메타데이터를 전송한다.
- 복구 가능한 세션에서 파생된 UI는 live session과 로컬 복구 데이터의 신뢰 순서를 확인한다.
- optional wire field 추가 시 옛 sender와 옛 receiver 두 방향의 JSON 호환을 테스트한다.
- 장식 아이콘을 자동 테스트에 노출하려고 VoiceOver에 중복 상태를 추가하지 않는다.
- 시스템 기호 유효성 검사는 UI 경계에서 수행하고 플랫폼 의존성을 Shared Domain에 추가하지 않는다.

## Lessons Learned

운동 종류의 단일 매핑을 재사용하면 Widget에 전체 Domain 의존성을 넣거나 별도 switch를 복제할 필요가 없다. 테스트의 식별자 존재와 실제 기호 렌더링·실제 Watch 미러링은 서로 다른 증거다. 반복된 절차 오류가 아니므로 CLAUDE.md/교정사항/새 공통 규칙은 추가하지 않았다. 연계 TODO는 검색 결과 없었다. 테마 방향 시안을 변경하지 않아 테마맵은 수정하지 않는다.


## 최종 실행 결과 · 2026-10-30

시스템 UI 재시도 로그는 `** BUILD INTERRUPTED **`로 끝났다. XCTest case 시작 기록은 0개이며 최종 `.result.json`이 없어 실행 건수·종료 코드를 확정할 수 없다. 테스트 통과나 UI 게이트 완료로 처리하지 않는다. 새 WLA01 PNG는 없고 기존 캡처는 이번 운동별 아이콘의 증거가 아니다.

구현·최종 통합 빌드·실제 Snapshot Swift Testing 15개·5관점 및 전문 코드 리뷰는 완료했다. [Draft PR #864](https://github.com/gooson/DUNE/pull/864)에 보존했으며 UI 검증 미완료로 머지하지 않았다. 재개 조건은 빌드 실행 환경 정상화 후 전용 iPhone의 WLA01+smoke 실행이 최종 receipt와 새 캡처를 생성하는 것이다. 다른 작업의 미커밋 소스·문서는 커밋하거나 정리하지 않았다.
