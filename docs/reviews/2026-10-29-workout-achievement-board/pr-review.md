# PR reviewer · workout achievement board

2026-10-29 · `codex/workout-achievement-board` · base `origin/main`

## Findings

| Priority | Open | Result |
|---|---:|---|
| P1 | 0 | 새 크래시·데이터 손실·보안 위험을 찾지 못함 |
| P2 | 0 | 새 기능/규칙 위반을 찾지 못함 |
| P3 | 0 | 이전 리뷰의 표시·접근성 항목은 수정 또는 명시적 배치 계약으로 해소 |

**코드 리뷰 판정: 해당 앱 변경 범위에서 병합 준비 완료. 출하 판정: 보류.** Duo 내부 화면의 필수 실제 검증과 디자인맵 갱신은 아직 끝나지 않았다. 이 문서는 테스트를 재실행하거나 미검증 화면을 승인하지 않는다.

## Reviewed scope

- `origin/main...HEAD`의 앱, DEBUG fixture, Xcode 프로젝트 참조, 단위/UI 테스트, 공용 색상 4개와 문자열 카탈로그. 최종 앱 소스 `e7867868`, 캡처 helper `72365af1` 이후 앱 파일의 작업트리 변경 없음.
- 현재 작업트리의 계획·해결책·레이아웃/테마맵·실제 화면 갤러리·실행 보고 delta. 브라우저 시안과 실제 캡처가 구분되고, 갤러리 활성 이미지 참조 34개는 모두 존재한다. manifest는 40개 원본 중 Duo 내부를 pending으로 표기한다. 테마맵 `--check` 통과. `git diff --check origin/main...HEAD` 통과.
- 앞선 [리뷰](review.md)의 P2/P3 lifecycle과 SwiftUI·Apple UX·최종 품질 보고를 대조했다. 새 앱 delta에서 해당 문제가 재발한 근거는 없다.

## Integration and crash-risk judgment

- `LifeView.swift:836-846`은 기존 목표 메뉴와 context menu closure를 새 표시 뷰에 넘긴다. 내비게이션·저장 소유권, 목표 action 경로는 기존 부모에 남아 있다. 새 보드는 SwiftUI Presentation 코드이며 Domain/Data/Watch 경계를 변경하지 않는다.
- `WorkoutAchievementBoard.swift:23-34`는 존재하는 규칙만 그룹화하고 빈 그룹을 걸러낸다. 따라서 같은 파일 `353`, `438`의 `[0]` 접근은 해당 호출 경로에서 비어 있지 않은 그룹에 한정된다. 다른 force cast/unwrap, 새 비동기·unowned 참조를 찾지 못했다.
- `WorkoutAchievementBoard.swift:40-55`는 비유한 값과 음수 목표를 먼저 제거하고 `Int` 변환 전에 3으로 제한한다. 0·음수·NaN·무한대·극단값 회귀 테스트가 포함된다. 13개 목표는 실제 분모를 사용한다.
- HealthKit 쿼리·권한·dedup, SwiftData `@Model`·스키마·CloudKit·영속 저장 변경 없음. `TestDataSeeder.swift:268-281`의 목표 fixture는 명시적 UI launch argument에만 반응한다. 새 영속화 또는 외부 전송 경로가 없다.
- 새 문자열 3개와 재사용 키의 en/ko/ja 및 `String(localized:)` 경로는 기존 리뷰에서 확인됐다. 이 sandbox에서는 `swift scripts/format-xcstrings.swift --check`가 홈 Clang module cache 쓰기 권한으로 시작 전 실패했으므로 이번 재확인 결과로 주장하지 않는다. 이전 실행 보고의 포맷 통과를 사용한다.

## Evidence and pending ship gate

최종 iOS 빌드 성공, 관련 단위 52/52, 최종 iPhone 3/3와 추가 보드 4/4, iPad 1/1, Duo 외부 1/1은 [실행 보고](README.md)의 보존 로그/receipt 범위다. 공통 실행 **31/34**의 Today 3건은 이전 기준 실행에도 실패했고 해당 앱/테스트 소스가 변경되지 않았다. 전체 회귀는 실행되지 않았으며 성공으로 표시하지 않는다.

**필수 미완료:** Duo 내부 전환 CLI가 exit 0을 반환했지만 공식 readback의 활성 LCD는 닫힌 상태였고 Mac 잠금으로 GUI 전환도 차단됐다. Duo 내부 L01 새 테스트·원본 PNG·갤러리 출처가 확보되기 전에는 `/run`의 실제 화면 게이트를 통과시키거나 PR을 merge하지 않는다. Mac 잠금 해제 후 현재 worktree 전용 Duo에서 내부 활성 화면 readback, 해당 L01 테스트와 새 캡처, 디자인맵·manifest 갱신을 확인해야 한다.

## Final delta addendum · Duo 내부 게이트 해소

위 미완료 기록은 당시 판단으로 보존한다. Mac 잠금 해제 뒤 해당 전용 Duo `DB1B9B76-36A1-47DA-AFAD-1DD7C380F3CF`를 GUI Open으로 전환했다. 보존된 공식 `devicectl` 검사 전후의 활성 화면은 **LCD-1 active / LCD inactive**, 방향은 `landscapeRight`다. 정확한 `LifeFlowUITests/testHostCaptureWorkoutBoardLight` receipt는 **1/1 passed**, host audit는 8개 checkpoint·runner exit 0·cleanup error 없음이다. 최종 app-quality agent는 새 내부 화면의 요약, 근력 6항목, 러닝 및 출처 원본을 확인하고 feature finding **P1/P2/P3 = 0/0/0**을 유지했다.

`e6550815` 이후 재검토에서 `DUNE/`, `DUNETests/`, `DUNEUITests/` 변경은 없다. 갤러리 manifest는 새 Duo 내부를 포함한 **52 원본(활성 40, 비활성 짝패널 12)**을 가리키며 pending 항목이 없다. 모든 manifest 파일 존재와 SHA-256 일치를 확인했고, 실제 화면 인덱스·README·검증 보고가 내부 완료 및 이전 CLI 실패를 구분해 기술한다. `git diff --check e6550815` 통과. 이후 `main` 통합으로 들어온 formatter/build guard 및 catalog의 extraction metadata는 별도 pipeline 검증 대상이며 이 보드 UI 판정에 새 앱 기능 변경을 만들지 않는다.

**최종 보드 판정: PASS WITH NOTES, 병합을 막던 Duo 내부 화면 게이트는 해소.** 이전 Today 3건으로 broader selected 실행은 여전히 31/34이고 전체 회귀는 미실행이다. 이 addendum은 새 formatter/build guard 검증의 결과나 원격 PR merge 상태를 승인하지 않는다.
