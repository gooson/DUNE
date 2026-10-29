# Life 성과 보드 실행·검증 보고

2026-10-29 · branch `codex/workout-achievement-board` · 사용자 요청: 선택한 성과 보드 시안을 `/run`으로 적용.

범위는 L01의 이번 주 운동 업적이다. 큰 완료 수·골드 메달/능선·횟수 분절·근력 6항목·러닝 거리 곡선을 적용하고 목표 메뉴와 도전 접기/펼치기를 보존했다. Domain/HealthKit/SwiftData 집계·저장·Watch는 변경하지 않았다.

- [계획](../../plans/2026-10-29-workout-achievement-board.md)
- [네이티브 배치 계약](../../design/layout-map/workout-achievements-proposal.md)
- [새 실제 원본 갤러리](../../design/full-redesign-map/review/workout-achievement-board-2026-10-29/index.html)
- [해결책](../../solutions/general/2026-10-29-workout-achievement-board.md)
- [코드 리뷰](review.md) · [최종 품질](final-quality.md) · [PR 리뷰](pr-review.md)
- [/run 체크포인트·변경 확인 가이드](execution-summary.md) · [PR #856](https://github.com/gooson/DUNE/pull/856)

## 검증 결과

| 검사 | 결과 | 출처 |
|---|---|---|
| 최종 iOS Simulator build | 성공 | `build-ios-final-ax.log.gz` / 앱 e7867868 |
| 관련 unit | **52/52**, 3 suites | BoardModel + LifeAutoAchievementService + LifeViewModel, `unit-targeted.log.gz` |
| 최종 iPhone light/MaxAX/seeded 접기 | **3/3** | `ui-phone-post-ax.log.result.json`, UI helper72365af1 |
| 추가 iPhone dark/한국어/목표 History/MaxAX | **4/4** | 아래 broader selected 실행 내 해당4case |
| 공통 smoke를 포함한 broader selected 실행 | **31/34**, 기존 Today3실패 | `ui-phone-rest.log.result.json`·원본로그, exit65 보존 |
| iPad light | **1/1** | `ui-ipad.log.result.json`, d86210fc 일반 글씨 배치는 최종과 동일 |
| Duo 외부 light | **1/1**, host8checkpoints 정상 | `ui-duo-closed.log.result.json`, 공식 active LCD + 새 AX/양쪽PNG |
| Duo 내부 light | **1/1**, host8checkpoints 정상 | `ui-duo-open.log.result.json`, GUI Open 후 공식 LCD-1 active/LCD inactive·landscapeRight·새 AX/양쪽PNG |
| 문자열 | 포맷 검사 통과 | 새3개키 en/ko/ja, 기존 키 재사용 |

전역 자동 UI planner는 seed/Shared catalog/project/docs 때문에 iOS/Watch full fallback을 출력했다. 실제 소비자 검색 결과 새 Board·색·키는 Life 전용이고 seeder는 DEBUG opt-in이다. 생성 프로젝트는 새 view/unit 참조만 추가한다. Watch 소비자가 없어 제외했다. 사용자 요청 없이 full 회귀를 확장하지 않는 `.codex/skill-compat.md`에 따라 관련 Life + 공통 smoke 합집합과 영향 L01 기기 캡처를 선택했다. 전체 회귀는 **미실행**이다.

`scripts/test-unit.sh`가 selector를 지원하지 않아 저장소 simulator lock과 기존 boot helper 아래 bounded targeted `xcodebuild test` fallback을 사용했다. UI는 모두 `scripts/test-ui.sh` 표준 실행기, Duo는 `scripts/duo-visual-audit.py` host handshake를 사용했다. 한 번에 전용 기기 한 대만 실행했다.

## 기존 실패와 범위 재확정

공통 실행의 아래3case는 `docs/reviews/2026-10-28-life-flow/ui-phone-initial.log.gz`에도 동일하게 실패했다.

- `DashboardSmokeTests/testConditionTrendAndHeroDetailRoute`
- `DashboardSmokeTests/testNavigateToNotificationHub`
- `DashboardSmokeTests/testNotificationHubSummaryAtMaximumAccessibilitySize`

Dashboard/Notifications/해당 테스트의 `git diff main...HEAD`는 비어 있다. 신규 opt-in 운동목표 seed flag도 해당 case에는 없다. [대조 기록](baseline-common-smoke-failures.json)을 보존한다. 이3건은 범위 밖 기존 이슈로 분리했고 완료 조건을 맞추려고 해당 앱/테스트를 수정하거나 재실행하지 않았다. broader 실행 전체를 성공으로 보고하지 않는다. Life8개 smoke 및 새 보드6개 고유 selector는 모두 통과했다.

## 실패와 수정 이력

1. 생성 프로젝트 참조 누락, fixture의 필수 `goalUnit` 누락을 수정하고 표준 빌드 성공을 확인했다.
2. unit wrapper의 `ROOT_DIR` 누락은 테스트 시작 전 실패했다. 기존 boot helper 입력을 수정한 뒤51개, 최종 안전 변환 회귀 추가 후52개가 통과했다.
3. routine caption에 큰 metric과 같은20pt 최소 높이를 요구하던 assertion이14.3pt caption을 잘못 실패시켰다. 큰 타일에만 최소 높이 검사를 적용하고2/2통과했다.
4. 초기 MaxAX screenshot은 일부만 hittable이어도 캡처해 요약이 잘렸다. native를 보고 큰 글씨의 제목 폭과 그룹 세로 배치를 개선하고 viewport 정렬을 추가했다. 최종3/3통과 및 전체 요약/러닝 출처 PNG를 확인했다.
5. Duo CLI open setter 성공만으로 펼침을 주장하지 않는다. 실제 active display를 읽고 GUI 대체 경로를 사용한다. 수치 hinge angle getter는 현재 SDK에서 지원되지 않아 측정했다고 보고하지 않는다.

Mac 잠금 해제 후 정확한 전용 Duo를 Device Hub에서 Open으로 전환했다. 공식 검사 전후 readback 모두 LCD-1 active/LCD inactive, landscapeRight였다. 표준 DuoAudit의 관련1case·8host checkpoint·exit0을 확인했고 요약/근력6항목/러닝/출처 새 PNG를 부모와 품질 agent가 검토했다. 이전 CLI 전환 실패 기록은 갤러리 evidence에 별도로 보존한다. 갤러리의 총52원본은 활성40장+비활성 짝패널12장이며 과거 다른 작업 PNG를 새 캡처로 재사용하지 않았다.

## 출처와 제한

최종 앱 소스 e7867868, UI 캡처 helper72365af1. d86210fc의 dark/KO/iPad는 마지막 앱 delta가 AX 전용 제목과 비정상 target 방어라 일반 글씨 정상 값의 배치가 동일하다. 이미지마다 당시 실제 commit을 유지한다. 캡처 이후 문서/갤러리만 추가되므로 이전 자동 receipt를 현재 fingerprint 성공으로 갱신하지 않는다. 해당 소스·환경·실제 결과를 보존하고 범위별 동등성을 명시한다.

실기기 VoiceOver 제스처/rotor, 정량 대비 측정, 모든 테마·일본어·모든 기록 상태·실기기 HealthKit 권한은 실행하지 않았다. AX 계층과 최대 글씨 캡처가 이 범위의 대체 합격을 뜻하지 않는다. Watch 화면은 영향이 없어 갱신하지 않았다.

## 수동 확인

Life → 이번 주 운동 업적에서 큰 완료 수와 메달을 확인한다. 운동 도전을 접었다 펼쳐 루틴 7분절·0회를 포함한 근력6항목·러닝 거리/남은 거리를 확인한다. 자동 연동 운동 목표가 있으면 더보기 → 이력을 열고 닫는다. 설정의 글씨를 최대로 키우면 메달이 숨겨지고 제목/근력 타일이 줄바꿈되는지 확인한다. 실제 수치는 해당 주의 운동과 등록한 자동 연동 목표에 따라 다르다.

## 최신 main 통합 검증

PR #855의 문자열 카탈로그 수동 추출/빌드 전후 guard를 충돌 없이 통합했다. `git diff e6550815 -- DUNE DUNETests DUNEUITests`는 비어 있고 Shared catalog를 `extractionState`만 제거해 비교한 JSON은 동일했다. 런타임 문자열/번역과 앱·테스트 Swift 코드는 그대로다. 새 `swift scripts/format-xcstrings.swift --check --check-manual`과 `python3 -B -m unittest scripts.tests.test_format_xcstrings`가 성공했고 관련 Python9개가 통과했다. [통합 검사 원본](catalog-integration.log)은 앱 전체 재빌드/회귀 성공을 의미하지 않는다. 앱 소스가 같고 카탈로그 차이는 메타데이터여서 기존 기기 검증을 중복 실행하지 않았다.
