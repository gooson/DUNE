---
date: 2026-10-30
status: verified
tags: [swiftui, habit-templates, native-redesign, ui-verification]
---

# L03 네이티브 개편 검증

## Scope / Source

브랜치 codex/l03-habit-template-redesign, 구현4f052fa7, base25ebca1b. 원본 da96의 시안/서버는 보존했다. 이 화면만 실제 앱에 구현한다. 159개 시안/106개 화면 전체 구현 완료가 아니다.

## Phase Evidence

- Init: clean 별도 native worktree와 codex 브랜치, origin/main fetch 확인.
- Plan: docs/plans/2026-10-30-l03-habit-template-redesign.md; repo/solution2·Apple UX1 조사.
- Work: 4f052fa7; 표준 scripts/build-ios.sh 성공 및 pre-commit 빌드 성공. 선택/prefill 저장 경로 유지.
- UI: iPhone 정상/접근성XXXL 2/2, iPad 기본1/1 통과. logs .xcodebuild/l03-iphone-ui.log, l03-ipad-ui.log와 각 result.json/xcresult. 타깃은 DuoLifeStarterTemplateTests/testEmptyStarterTemplateCreatesHabitAndRendersHabitsSection, LifeStarterTemplateRegularTextTests/testWaterTemplateCardPrefillsCountGoal.
- Duo: 소유 기기3338816C-353E-4B92-99BE-A40166FA2A88, LCD 활성/LCD-1 비활성을 공식 devicectl로 확인. 첫 준비 셸은 Python/ROOT_DIR 구성 오류로 실제 부팅하지 못했다. 직접 소유권 확인/제한 시간 boot 명령으로 전환했다. 새 runtime의 initial migration은 terminal Data Migration Failed를 보고했으므로 정상 부팅 완료로 간주하지 않는다. 접힘 테스트 첫 실행은 repository lock60초로0개 실행. 실제 non-blocking lock 검사에서 해제를 확인한 근거(.codex-checks/l03-duo-lock-state.json) 후1회 조건부 재시도했다. 결과는 exit65/실행수unknown으로, 테스트 시작 전 runner bootstrap/stalled waiter 종료였다. 통과 증거가 없다.
- Duo 펼침: Device Hub는 Mac 잠금으로 접근하지 못했다. 이후 자동화 메모를 다시 확인해 기존 검토 도구 `/private/tmp/life-hinge-20261029`의 pinned commit `7acb090dd7d28fb0aea8e1907211ceff15aa450e`와 clean checkout을 확인하고, HID helper 및 실행·조회 스크립트를 읽었다. Mac 잠금 해제 요청은 우선 보류한다고 안내했다. setter exit만으로 펼침 통과를 판단하지 않으며 소유 기기의 활성 디스플레이와 새 화면으로 검증한다. 아직 펼침 UI·새 캡처 미완료.

## Verification Scope Decision

판정기의 full fallback에는 docs HTML/JSON/JPEG와 UI 테스트 파일 변경이 포함된다. 실제 앱 변경은 HabitTemplateSheet와 파일 내부 private 카드뿐이고 모델/공통 DS/Watch 소비자는 변경하지 않았다. HabitTemplateSheet의 앱 호출부는 LifeView다. 사용자 지정 범위 기반 adapter에 따라 영향 Life의 두 selector와 각 영향 기기 캡처로 제한한다. 전체 UI/Watch 통과로 보고하지 않는다.

## Read-only Reviews

439줄 implementation diff(origin/main...4f052fa7)를 실제 수집해5개 일반 관점과2개 UI 품질 관점에 전달했다. 실제 캡처의 게시 범위/문서는 후속 delta로 검토하며 UI 게이트를 통과시킨 의미가 아니다.

| 관점 | 담당 | 결과 |
|---|---|---|
| Security | l03_review_security | P1/P2/P3=0 |
| Performance | l03_review_performance | P1/P2/P3=0 |
| Architecture | l03_review_architecture | P1/P2/P3=0 |
| Data Integrity | l03_review_data | P1/P2/P3=0; 미완료 캡처 승인 아님 |
| Simplicity | l03_review_simplicity | P1/P2/P3=0 |
| SwiftUI | l03_swift_quality | 조치할 정적 문제 없음; 실제 기기 별도 |
| Apple UX | l03_apple_quality | P1/P2=0; 기존 category heading trait 개선P3 |
| Agent-Native | 적용 안 함 | .claude/.codex/prompt 변경 없음 |

P3 heading trait는 원래도 없던 보조 개선으로 이번 시각/prefill 회귀와 별도다. 기존 접근성 구조를 보존하는 범위로 두며 후속 접근성 작업으로 남긴다. P1/P2=0이며 새 기능/데이터 처리 변경은 없다. perf-optimizer의 대량 데이터 처리 조건은 정적20개 카드에 해당하지 않는다.

## Captures / Provenance

새 iPhone/iPad L03 PNG의 제목·목표·시간대·줄바꿈을 직접 확인했다. 수집기가 L01/L02도 선택했으므로 해당 PNG와 captured 항목은 이 브랜치 baseline으로 복원하고 L03만 남겼다. 기존 index의 전체 출처는 유지하며 L03 항목에 구현 revision과 소유 UDID를 명시했다. 다른 화면/기기 PNG를 이번 L03의 새 증거로 재사용하지 않는다. 펼침 UI/캡처가 완료되기 전 전체 native UI 승인을 내리지 않는다.

## Preflight follow-up

pr-reviewer는 수집기의 portal 재생성으로 기존 Life Flow·업적·Cardio Atlas 링크가 사라진 P2를 발견했다. 실제 portal/compare 원본을 HEAD로 복구하고 L03 검증 링크만 추가했다. 앱 source finding은 없으며 이 P2는 최종 링크 보존 대조 후 Resolved로 기록한다.

## Current recovery / Draft

드래프트 PR: https://github.com/gooson/DUNE/pull/858 (머지하지 않음). 연결 GitHub 앱은403이어서 인증된 gh CLI로 생성했다. fresh Duo의 migration/runner 실패 이후, 원본이 Shutdown임을 확인해 원본 상태를 바꾸지 않고 초기화된 전용 clone을 만들었다. 소유권 접미사 오류는 새 clone 이름만 바로잡아 등록했다. 새 UDID F8804553-93D0-4ACF-9A72-DC466957BCC4. 새로운 환경 변화 근거 후 bootstrap 원인에 대한1회 재시도를 준비한다. 기존 실패 로그와 실행 영수증은 보존한다.

P2 portal 링크 누락은 실제 delta를 pr-reviewer가 다시 확인하여 Resolved다. 새 iPhone/iPad PNG도 Apple UX가 직접 확인해 보이는 텍스트의 잘림/겹침/가독성 문제 없음으로 보고했다. Duo/다크/다른언어 승인은 아니다.

초기화된 전용 clone은 bootstatus `Finished`로 정상 부팅했다. 복구 실행도 처음에는 공용 잠금 때문에 테스트가 시작되지 않았다. 호스트의 실제 lock inode와 점유 `bash`/`xcodebuild` PID를 확인했고, 해당 실행이 종료된 후 표준 잠금을 원자적으로 확보했다. wall 600초·idle 300초 상한의 조건부 bootstrap 재검증을 시작했다. 기존 migration 실패 기기의 결과를 통과로 재해석하지 않는다.

## Final scoped verification

복구된 소유 Duo에서 접힘1/1과 펼침1/1이 각각 실제 실행·통과했다. Closed는 LCD 활성과1398×2034 PNG, Open은 LCD-1 활성과2006×2852 PNG를 확인했다. 조회 API가 수치 angle을 반환하지 않았으므로 각도를 측정했다고 기록하지 않는다. Mac 잠금 해제는 필요하지 않았다. 위의 실패/대기 기록은 복구 전 경과이며 최신 결과는 이 절과 각 result.json이다.

| 기기·상태 | UI | 새 L03 PNG | 범위 |
|---|---|---|---|
| 일반 iPhone | 2/2 | regular/images/L03.png | 기본 및 접근성XXXL; 캡처는 기본 |
| iPad | 1/1 | ipad/images/L03.png | 기본 글씨 |
| Duo 접힘 | 1/1 | duo/images/L03.png | 기본 글씨·외부 패널 |
| Duo 펼침 | 1/1 | duo-open/images/L03.png | 기본 글씨·내부 패널 |

밝음·영어 실제 이미지 네 장의 보이는 영역을 parent와 Apple UX가 직접 확인했고 조치할 잘림·겹침은 없었다. 앱·테스트 소스는4f052fa7 이후 바뀌지 않아 동결 구현의 일반 리뷰 결과를 재사용한다. 새 캡처/문서 delta는 최종 pr-reviewer가 별도로 확인한다. 일반5개 관점과 SwiftUI 정적 검토는 새 코드 발견0, Apple UX의 기존 heading-trait P3는 사전 존재 항목으로 범위 밖이다. 게시 delta의 portal-link P2는 수정과 재검토로 Resolved다.

Duo 수집은 기존 수집기의 pair_attachments/priority/render_gallery/render_boards 함수로 L03만 추출했다. 다른 화면 항목·이미지와 actual portal/compare는 이 단계에서 재생성하지 않았다. 실패 기기의 영수증도 남겨 성공 실행과 구분한다. UI/Quality/Resolve/Compound의 범위별 근거는 완료했으며 PR의 최종 머지 결과는 GitHub 상태를 따른다.
