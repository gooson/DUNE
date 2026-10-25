---
tags: [today, ui, review, run, validation]
date: 2026-10-25
status: validation-blocked
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

미해결 P1/P2=0이다. SwiftUI·Apple UX 전문 검토를 Work에서 수행하고 후속 변경의 관련 관점만 재검토했다. 대량 데이터 처리가 없어 perf-optimizer는 제외했다. 종합 app-quality는 iPhone 증거를 확인했지만 기기별 캡처 게이트는 열어 뒀다.

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

## Remaining gates

1.14d37e32에서 `TodayReadingUITests/testCurrentDeviceReadingCards`와 `testNotificationDigestUsesSameExpandableCard`의 최종 delta 검증 및 T10 새 PNG가 필요하다.
2. iPad·Duo 접힘·펼침의 T03/T10 새 캡처와 육안 확인이 필요하다. 첫 iPad 시도와 재시도 모두 같은 잠금 원인으로 실패하여 해당 자동 실행 경로를 중단했다. 저장소 점유가 해제되고 사용자가 재개를 지시한 뒤, 등록된 소유 기기와 상태를 확인해 재개한다.
3. 기기별 디자인맵 품질 게이트가 열린 상태에서는 merge 완료로 표시하지 않는다. 원본 워크트리와 전용 기기는 유지한다.

## Change Verification Guide

수면·컨디션·걸음 기록이 있는 Today에서 아래로 스크롤한다. 회복·수면의 큰 지난 수면과 수면 부족이 분리되고 기간·시간 단위가 있는 그래프가 보인다. 수면 상세가 기존 수면 화면을 연다. 장기 스트레스에서 분석 근거는 현재 화면에 펼쳐지고 스트레스 상세는 별개 화면을 연다. 오늘 요약은 컨디션·걸음 수를 먼저 보여 주고 전체 요약을 펼친다. 알림의 일간 요약에서는 두 지표가 중복되지 않아야 한다. 큰 글씨는 지표를 세로로 배치하며 원문은 스크롤로 읽는다.

HealthKit 실제 기록 없는 상태는 seeded 수치로 대체하지 않는다. UI캡처는 debug fixture다. 기존 요약 생성기의 운동 시간·휴식일 추론과 스트레스 대리 지표의 정확도를 새로 인증한 작업이 아니다.
