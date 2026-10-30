---
tags: [life, scroll, inspector, navigation, review]
date: 2026-10-30
category: solution
status: reviewed
---

# Life 제목·배경·기록 패널 정렬 리뷰

- Scope: LifeView·ContentView의 제목/배경 강제 설정 제거와 inspector 소유권 이동, 관련 디자인 문서, 복귀 회귀 검사.
- Branch: `codex/life-navigation-scroll-alignment`
- Base: `origin/main` (`ce541a409c9977d61c8f65c570363cb2531164da`). 현재 HEAD `9a21f364908c346205b70957f16d8883ecf0e84a`는 6개 커밋 뒤에 있다. 원격 main에 통합한 결과의 검증은 아직 아니다.
- 초기 상태: main에서 앱 2개·디자인 문서 2개만 미커밋 변경. 이번 작업용 브랜치를 만들었고 무관한 파일은 포함하지 않았다.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | Open 없음 |
| P2 | 0 | Open 없음 |
| P3 | 0 | Open 없음 |

## Findings

Security·Data Integrity, Architecture·Simplicity, Performance·SwiftUI·정적 App Quality를 분리해 read-only 검토했다. 구체적인 도입 결함은 발견하지 못했다. Agent-Native는 지침 변경이 없어 제외했다. L10N은 새 사용자 대면 문자열이 없고 기존 영어 내비게이션 제목을 유지함을 확인했다. 해결·stale 처리할 기존 finding은 없다.

## Checks and Limits

- `git diff origin/main --check`: 통과.
- `scripts/plan-ui-tests.py --base origin/main`: 계획만 생성. App 경로의 full 경고를 실제 소비자와 대조했다. 영향은 iOS Life 탭이며 Watch·visionOS는 별도 화면을 사용하므로 이번 변경의 전체 테스트 대상이 아니다.
- 라이프 복귀 검사는 히어로가 화면 밖으로 나간 뒤 최초 Y ±12pt로 복귀하고 반복 스와이프 후 유지되는지 검사한다. XCTest attachment에 최초·복귀 화면을 남긴다. 아직 실행하지 않았다.
- 최소 실행 범위: `DUNEUITests/LifeRegressionTests/testScrollReturnKeepsLifeHeroAtOriginalPosition`, `DUNEUITests/LifeRegressionTests/testHabitHistoryShowsSeededEntriesAndDismisses`. iPhone에서 두 경로, iPad에서 기록 패널 적응을 확인한다. 과거 기록 추가 전환은 별도 실행 증거가 없다.
- 실행 전 repository lock probe가 `repository simulator test lock remained busy for 1s` / exit 2로 종료했다. 다른 worktree의 활성 UI runner가 존재하며 새 build/unit/UI/capture를 시작하지 않았다. Mac 화면 잠금 때문이라고 판단하지 않는다.
- 빌드·UI 통과 증거 없음. L01 및 기록 패널의 iPhone·iPad·Duo 접힘/펼침 새 PNG도 미갱신이다. 기존 PNG를 새 증거로 쓰지 않는다.
- SSH fetch는 publickey 인증 오류였다. 승인된 gh 인증 경로에서 정상 로그인 및 HTTPS fetch를 확인했다. 인증 정보는 문서에 보존하지 않는다.

최종 PR 정적 재검토에서도 추가된 복귀 검사에 P1/P2/P3 지적은 없었다. 기존 Today 회귀 기준과 같은 시퀀스이며 실행 통과 증거로 해석하지 않는다.

## Next Steps

실행권 반환 후 현재 변경을 최신 main에 통합하고 재검토한다. 해당 worktree 소유 기기와 표준 실행기·deadline을 사용해 위 selector만 실행하고 새 실제 캡처를 확인한다. UI/빌드 결과를 확인하기 전 PR 생성·머지·브랜치/캐시/기기 정리는 수행하지 않는다. 전체 회귀는 요청되지 않았으며 필수 게이트로 남기지 않는다.

## 사용자 지정 Ship 예외

후속 사용자 지시로 추가 실행 검증 없이 PR 생성·머지를 진행한다. 위 검증 대기/중단은 당시 상태이며 이 명시적 지시가 이번 Ship 게이트를 대체한다. 빌드·UI·실제 캡처 미수행 사실은 그대로 유지하고 통과로 표시하지 않는다. 정적 리뷰와 diff 검사는 완료했다.
