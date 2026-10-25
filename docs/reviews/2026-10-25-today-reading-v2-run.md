---
tags: [today, ui, review, run, validation]
date: 2026-10-25
status: verified-feature-scope
---

# Today 읽기 위계 V2 실행 기록

구현 소스는14d37e32다. 기존 워크트리의 미완료 Today·Watch 작업은 보존하고 main f4d56f63에서 별도 `codex/today-reading-v2`를 만들었다. [계획](../plans/2026-10-25-today-reading-v2.md), [방향 시안](../design/theme-map/themes/dune-today-reading.html), [실제 화면](../design/full-redesign-map/review/today-reading-v2-2026-10-25/index.html), [해결책](../solutions/general/2026-10-25-today-reading-hierarchy.md)을 구분한다.

## Review findings

보안·성능·구조·데이터 일관성·단순성5개 에이전트를 실제 실행했다. AI지침 변경이 없어 Agent-Native는 제외했다. 초기 P1=0, P2=2, P3=2였다.

| 발견사항 | 최종 상태 |
|---|---|
| 공유 요약 카드와 T10 지표 grid의 컨디션·걸음 중복(P2) |14d37e32 해결. T10은 수면만 보충. 구조 에이전트 delta 재검토 통과 |
| 불충분 수면 분석의 부채0이 기록 유무 판정을 통과(P2) |14d37e32 해결. 파생 부채와 단독 변화량 제외, 수면은 finite positive. 데이터 에이전트 재검토 통과 |
| 이미 검증한 부채의 max clamp(P3) |제거 |
| date-range helper의 first/last 방어적 optional 검사(P3) |안전한 helper 계약을 보존하는 tradeoff로 수용. 차단 사항 없음 |

미해결 P1/P2=0이다. SwiftUI·Apple UX 전문 검토를 Work에서 수행하고 후속 변경의 관련 관점만 재검토했다. 대량 데이터 처리가 없어 perf-optimizer는 제외했다. 기존 종합 app-quality의 기기별 캡처 보류 사항은 아래 재개 검증으로 해소하고 최종 증거 재검토에서 PASS WITH NOTES, 미해결P1/P2/P3=0을 받았다.

새 문자열10개는 en/ko/ja 모두 확인했다. Text/Label은 LocalizedStringKey, 시간·수치는 기존 formatter를 사용한다. `swift scripts/format-xcstrings.swift --check`를 실행했다.

## Executed verification

| 검증 | 실제 결과·범위 |
|---|---|
| `scripts/build-ios.sh --no-regen` |14d37e32 통과. Xcode27.1 / iOS27.1 SDK, generic iOS Simulator |
| `TodayReadingUITests` |44018fcc, iPhone18Pro iOS27.0,7실행/7통과/0실패/0누락 |
| 초기 Today+공통 smoke |726f05eb,36실행/34통과/2실패. Today6건은 모두 통과 |
| 초기 smoke 실패 분류 |`testNavigateToNotificationHub`, `testNotificationHubSummaryAtMaximumAccessibilitySize`. 변경되지 않은 자동 Morning Briefing 시트가 알림함을 가린 native PNG 확인. 해당 앱/테스트 파일 diff 없음 |
| iPad 영향 화면2건 |기기 부팅·테스트 시작 전 저장소 잠금60초 대기 실패2회. 테스트0건, 통과로 처리하지 않음 |
| Duo 접힘·펼침 |동일 자원 점유로 미실행·미캡처 |
| V2 HTML |375/402/466/768px 기본·큰 글씨 가로 overflow 없음, V1/V2·밝음/어두움·기록 없음·근거/원문·목적지 대화상자·JS오류0 확인 |
| 테마 맵 |`build-theme-map.py --check` 통과 |

`plan-ui-tests.py --base main`은 Shared카탈로그·프로젝트·UI테스트·시안 자산에 full fallback을 반환했다. 실제 앱 변경은 iOS Today3카드와 T10소비자이며, 프로젝트 변경은 새 UI테스트 등록, Shared변경은 추가 문자열뿐이다. Watch/Domain/Data/HealthKit에는 diff가 없다. 전체 UI는 요청되지 않았으므로 adapter에 따라 변경 기능과 공통 진입으로 좁혔다. targeted 성공을 full 성공으로 보고하지 않는다. 공통 알림 실패는 범위를 넓혀 수정하지 않았다.

로컬 로그와 결과 JSON은 `.codex-checks/today-reading-final-iphone.log{,.result.json}`, `.codex-checks/today-reading-ipad.log`, `.codex-checks/pipeline/`에 보존한다. 캡처 출처·크기·SHA256은 갤러리 인덱스에 커밋한다. 문서 추가로 전체 fingerprint receipt가 stale이 돼도 이전 자동 테스트를 새 성공으로 갱신하지 않는다. 변경 소스별 리비전과 실제 실행 범위를 위 표로 유지한다.

## Explicitly authorized resumption

사용자의 “허용” 후 저장소 잠금이 풀린 것을 실제 획득으로 확인하고3개 소유 기기를 대조했다. 기존 iPad2회 실패 이력은 보존했다. CLI의 고정 retry한도를 수정하지 않고 명시적 재개 실행을 별도 ID로 기록해 이전 이력과 연결했다.

| 최종 관련 실행 | 결과 |
|---|---|
| iPhone 최종 delta |2실행/2통과, T10지표 중복 방지·수면 한국어 시간 확인 |
| iPad 재개 |2실행/2통과 |
| Duo 접힘 |2실행/2통과, nativecheckpoint11/11정상 |
| Duo 펼침 첫 실행 |2실행/1통과/1실패. T10통과, 카드 검사의 장식 Image선택·지나침 문제 |
| Duo 펼침 실패건 수정 후 |실패한 카드1실행/1통과, nativecheckpoint8/8정상. 제품 코드는 그대로, test local helper만a8fa79b8에서 수정 |
| 병합 후 표준 build |origin/main a5e9052c를fc05f89c에 병합 후 통과. 충돌은 실제맵 링크만 양쪽 보존. Today제품·문구에는14d37e32이후 diff없음 |

최종 관련8개 method/device조건은 각각 성공 증거가 있다. 최초 펼침 실패를 포함하면9실행/8통과/1실패 후 해당 실패 해결이며, 동일 실행8/8로 바꿔 보고하지 않는다. 실제 PNG38장을 [갤러리](../design/full-redesign-map/review/today-reading-v2-2026-10-25/index.html)에 등록했다. source_commit과 app_source_commit, case와 bundle상태를 분리했다. 원본 결과 JSON과 읽기값도evidence/에 보존한다.

Duo의 이전 devicectl motion조회는 현 도구에 없어 public UIKit.UIHingeInteraction을 붙인 보조 앱으로 실제0°/닫힘과180°/완전펼침을 읽었다. 검토한 pinned HID setter만 자세 설정에 사용했다. 외부LCD 및 내부LCD-1 활성 상태와 native·AX를 대조했다. 실제 창은 접힘466×678pt, 펼침951×669pt다. 직후 방향 요청값과 앱 재활성 뒤 방향값이 달라 펼침은 실제 가로창으로 기록한다. 펼침 세로·회전 전환의 합격으로 확대하지 않는다.

최종검증 로그는 `.codex-checks/today-reading-resolve-iphone.log`, `today-reading-ipad-resume.log`, `today-reading-duo-closed.log`, `today-reading-duo-open.log`, `today-reading-duo-open-retry.log`와 각result.json이다. 세 카드의 밝음/어두움/최대글씨는 앞선 iPhone증거, 다른 기기들은 기본 밝음만 확인했다. 실제 기록 없음 native상태·실기기권한·다른테마·전체회귀는 미검증이다.

공유 catalog가 수정 중인 원본 main워크트리는 그대로 보존한다. 원격 머지 후 전용 체크아웃을 병합된 main내용에 맞춰 동기화·재생성하고, 원본의 미커밋 파일을 덮어쓰거나 stash하지 않는다. PR은 [#837](https://github.com/gooson/DUNE/pull/837)을 사용한다.

## Change Verification Guide

수면·컨디션·걸음 기록이 있는 Today에서 아래로 스크롤한다. 회복·수면의 큰 지난 수면과 수면 부족이 분리되고 기간·시간 단위가 있는 그래프가 보인다. 수면 상세가 기존 수면 화면을 연다. 장기 스트레스에서 분석 근거는 현재 화면에 펼쳐지고 스트레스 상세는 별개 화면을 연다. 오늘 요약은 컨디션·걸음 수를 먼저 보여 주고 전체 요약을 펼친다. 알림의 일간 요약에서는 두 지표가 중복되지 않아야 한다. 큰 글씨는 지표를 세로로 배치하며 원문은 스크롤로 읽는다.

HealthKit 실제 기록 없는 상태는 seeded 수치로 대체하지 않는다. UI캡처는 debug fixture다. 기존 요약 생성기의 운동 시간·휴식일 추론과 스트레스 대리 지표의 정확도를 새로 인증한 작업이 아니다.
