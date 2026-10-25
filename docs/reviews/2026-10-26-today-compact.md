---
date: 2026-10-26
category: review
tags: [today, compact, dynamic-type, swiftui, native-capture]
status: reviewed-with-coverage-limits
---

# Today Compact 검토·실행 기록

기본 DUNE / Desert Warm 테마를 유지한 Today 전체의 Compact 적용이다. 링은104pt·획7pt, 접근성 글씨에서는 외부 점수, 카드 내부14–16pt, 아이콘–값4–6pt를 사용한다. 회복·수면, 스트레스, 진행, 브리프, 인사이트, 고정·활동·신체 지표와 종목별 운동 요약을 함께 조정했다. 다른 세 탭의 공유 링·VitalCard 기본값은 변경하지 않았다.

- 계획: [구현 계획](../plans/2026-10-26-today-compact-layout-and-ring.md)
- 상태 계약: [Today 전체 상태](../design/layout-map/today-case-matrix.md)
- 실제 화면: [원본 PNG·출처·해시](../design/full-redesign-map/review/today-compact-2026-10-26/index.html)
- 브라우저 시안: [Compact·Metrics·Editorial 비교](../design/theme-map/themes/dune-today-comparison.html)
- native 최초 검토 기준: `8ab0e29e...56f62fec`. 최종 육안 검토에서 발견한 최대 글씨 캡션만 `19cf57c9`로 추가 수정했다. 표준 글씨 HStack은 그대로이며 해당 delta도 PR reviewer가 확인했다.

## Summary

| Priority | Open | 최종 상태 |
|---|---|---|
| P1 | 0 | 새로 확인된 blocker 없음 |
| P2 | 0 | 좁은 폭 진행 타일, 고정 편집/홀수 배치 수정 |
| P3 | 0 | 상대 날짜 문맥·최대 글씨 캡션 보강 |

## 검토 범위

전체 diff가 생성된 HTML을 포함해2,000줄 이상이므로 review skill의 큰 diff 예외에 따라 parent가 폴더별로 직접5관점을 검토했다. native UI는 별도 SwiftUI·Apple UX·app-quality 전문가가 검토했다. `.claude/**`·agent prompt 변경이 없어 Agent-Native는 생략했다.

| 관점 | 확인한 내용 | 결과 |
|---|---|---|
| Security | 새 신뢰 경계·권한·네트워크·비밀 정보 없음. DEBUG fixture는 명시적 seeded launch에 한정, 점수 범위 검증. 로컬 HTML 입력은 숫자 검증·textContent 사용 | 추가 finding 없음 |
| Performance | 새 HealthKit/저장 조회 없음. 최근7일·종목별 기존 배열을 제한해 표시. 고정 grid와 ViewThatFits 범위 확인 | 추가 finding 없음 |
| Architecture | Today 전용 링·지표, compact opt-in의 기본false, 공유 링과 다른 소비자의 기본 동작 유지. 기존 상세/context menu 경로 확인 | 추가 finding 없음 |
| Data Integrity | 점수·저장 schema 변경 없음. 측정0/누락 구분, 유효 날짜·현재 점수와 추세 일치, 종목 집계를 개별 세션 이력으로 오인하지 않도록 제목 표시 | 추가 finding 없음 |
| Simplicity | 기존 surface·helper 재사용. 새 범용 framework 없이 presentation component에 한정 | 추가 finding 없음 |
| Localization | 새6키 en/ko/ja, LocalizedStringKey/String(localized:) 경로, enum displayName 확인. 카탈로그 formatter 별도 검사 | 누락 없음 |

SwiftUI 전문가: 링 고정 기하·자연 높이 레이블·전체 폭 singleton·row contentShape 확인. Apple UX 전문가: 큰 글씨 전환·44pt 행동·접근성 의미·Reduce Motion 확인. app-quality: 최종56f62fec에서 새 P1/P2/P3 없음. 대량 처리·파싱 변경이 없어 perf-optimizer 추가 실행은 해당 없음이다. 최종 PR 통합 리뷰도18개 native/test/resource 경로를 확인했고 새 P1/P2/P3 발견 사항은 없었다.

## 해결한 발견사항

1. **P2 · 좁은 폭 진행 타일**: xxLarge 이전에도 폭이 부족하면 ViewThatFits의 최소150pt 조건으로 세로 전환한다. 숫자·단위를 축소하지 않는다.
2. **P2 · 고정 편집과 홀수 마지막 행**: 운영 fallback은 HRV·RHR·수면 세 개지만 UI seed는 HRV·RHR 두 개를 명시한다. 실제 녹화에서 수면 행 가운데 tap이 Spacer에 떨어져 선택되지 않았다. HStack 전체 폭·최소44pt·contentShape(Rectangle)와 선택 AX trait을 추가했다. 저장 전에 selected 상태를 검사한다. singleton은 ViewThatFits를 거치지 않고 전체 폭 카드를 직접 표시한다. 최종 native 검사는1/1 통과, 원본 PNG와 receipt 보존.
3. **P3 · 측정 날짜 문맥**: 화면의 상대 시점은 유지하고 정확한 측정 날짜·시간을 접근성 이름에 제공한다. 업데이트 시각과 측정 시각을 구분하도록 계약도 보강했다.

실패 분석 과정의 잘못된 fallback 가정은 현재 test seed와 native AX/영상으로 교정했다. 테스트를 통과시키려고 기대 폭을 완화하지 않았다.

## 검증 범위 판정

`plan-ui-tests.py --base main`은 App fixture·project·공유 catalog·UI test body·HTML 경로 때문에 iOS/watch full을 제안했다. 실제 consumer를 확인해 이번 범위를 Today 관련 UI와 공통 smoke로 재확정했다. App 변화는 DEBUG/UI fixture opt-in, project 변화는 두 Today component와 UI test 참조, catalog는 새 Today 문구6키 추가다. storage/권한/seedDefaultRecords 기본 계약·공유 helper·전역 theme/nav는 변경하지 않았다. Watch는 새 Today View/문구를 소비하지 않아 별도 UI 실행 대상에서 제외했다. phone build는 포함 타깃 컴파일을 수행했다. 전체 회귀나 Watch UI 통과로 보고하지 않는다.

공통 smoke에서 발견한 무관한 기존 실패를 고치기 위해 범위를 넓히지 않았다. 최초 실패 증거와 [동일 기존 실패 기록](2026-10-25-today-habit-schedule.md)을 대조했다.

## 실행 결과

| 실행 | 결과 | 증거 |
|---|---|---|
| native 최종 빌드 | BUILD SUCCEEDED | `/private/tmp/today-compact-max-caption-build.log`,19cf57c9 pre-commit build |
| 최초 관련·공통 smoke 실행 | 50 수행/46통과/4실패, exit65 | `/private/tmp/today-compact-ui.log.result.json` |
| 차트·지표 보완 뒤 focused 실행 | 10 수행/9통과/1실패; 결과 정리 중 deadline124 | `/private/tmp/today-compact-ui-final.failed-result.json`; 전체 성공으로 사용하지 않음 |
| 사용자 승인 추가 홀수 검사2회 | 각각 실패, 해당 승인 소진 | `/private/tmp/today-compact-odd-approved.log.result.json`, `today-compact-odd-final-approved.log.result.json` |
| 실제 row hit-area 수정 후 승인된 최종 검사 | **1/1통과, exit0** | [저장한 receipt](../design/full-redesign-map/review/today-compact-2026-10-26/pin-interaction-result.json) |
| 최종 Today 관련 검사 | **20/20통과, exit0** | [저장한 receipt](../design/full-redesign-map/review/today-compact-2026-10-26/related-ui-result.json); 이미 통과한 홀수 case는 제외 |
| T03 root 밝음·어두움 | 네 구성에서 각1/1통과 | regular/ipad/duo/duo-open root 로그·실제 갤러리 출처 |
| T18 editor 진입·닫기 | 네 구성에서 각1/1통과 | 기기별 capture-index의 실제 시각·test·revision |

최초4실패 중 Today의 More/Less 기대 문구와 고정 편집/홀수 배치는 수정했다. 나머지2개는 기존 `DashboardSmokeTests/testNavigateToNotificationHub`의 navigation title 조회, `testNotificationHubSummaryAtMaximumAccessibilitySize`의 설정 버튼 도달성 실패다. 이 둘은 이전 별도 변경에서도 동일하게 기록됐고 이번 diff는 알림 화면·그 tests를 수정하지 않는다. 공통 smoke 전체가 통과했다고 표시하지 않는다.

최종 관련 선택은 TodayCompact11개(홀수1개는 별도통과), TodayReading7개, TodaySupportCards2개로20개다. plan은 DUNEUITests-DesignCapture, 기기는 worktree 소유 iPhone `9DF82ECF-D93E-4A35-9825-B8165E703B8A`, 명시 deadline1800/idle180초다. 첫 Full plan 실패의 sysdiagnose 정체를 반복하지 않도록 표준 capture plan의 진단수집never를 사용했다. selector를 바꿔 실패를 숨기지 않으며 정상 종료와 receipt를 확인한다.

## 실제 화면과 한계

T03·T18을 일반 iPhone·iPad·Duo 외부/내부에서 새로 캡처했다. T03은 밝음·어두움, T18은 시스템 설정의 기본 글씨다. 원본은56f62fec에서 생성했고 SHA-256으로 보존했다. 측정값 상태의 카드 잘림·겹침·표시 위계를 직접 확인했다. 내부 가로는 설정 명령과 실제 orientation이 일치하지 않아 **미검증**이며 새 내부 세로 캡처로 대체 인증하지 않았다. 수치 힌지 각도도 조회할 수 없다.

기존 T03 시작 skeleton·빈 기록 상태의 미갱신 안내를 유지했다. 모든 시간대·VoiceOver·글씨 단계·모든 테마 조합을 실제 기기에서 다시 확인한 것은 아니다. 브라우저 상태 행렬과 native UI 결과를 구분한다. 실제 맵의 무관한 항목·PNG는 원래 출처로 복원했고 T03·T18·관련 보드/포털만 갱신했다.

## 남은 게이트

최종 Today20개와 별도 고정 검사1개가 모두 정상 종료했다. 기본21개는56f62fec에서 통과했고 이후 최대 글씨 캡션만19cf57c9로 보완해 영향받는 selector1개를 추가 통과했다. 최종 PR delta reviewer의 미해결 P1/P2도0건이다. Compound와 Ship 진행 증빙은 `/run` 최종 보고서에서 별도로 확정한다. 이 검증은 명시한 관련 범위이며 전체 iOS/Watch UI 성공을 뜻하지 않는다.

## 해결 기록

[Compact 밀도·고정 편집 hit-area 해결책](../solutions/general/2026-10-26-today-compact-density-and-pin-hit-area.md)에 원인·핵심 코드·예방 항목을 저장했다. 반복한 seed 추정과 상태 확인 누락은 `docs/corrections-active.md`에 교정으로 남겼다. 기존 규칙으로 포괄돼 새 `.claude/rules`는 제안만 검토하고 추가하지 않았다. `.claude/**`는 변경하지 않았다.

## 최종 원본 육안 보완

21개 검사 통과 뒤 최대 글씨 PNG에서 영문 CONDITION이 단어 중간에서 꺾이는 것을 발견했다. `19cf57c9`에서 접근성 크기만 제목과 상세 안내를 세로 배치했다. 표준 글씨의 기존 HStack은 그대로 추출했고 점수·추세·라우팅·데이터 변화는 없다. 별도 PR delta 리뷰의 새 P1/P2/P3는0건이며 pre-commit native 빌드는 통과했다. 해당 최대 글씨/추세/상세 경로 selector1개도1/1·exit0으로 통과했고 새 원본에서 단어 중간 꺾임이 해소된 것을 육안 확인했다. 고정 편집 검사를 반복하거나 전체 범위를 다시 돌리지 않았다.

T03·T18의 기본 글씨 캡처 및 나머지 표본은56f62fec 출처를 그대로 유지한다. 영향을 받은 최대 글씨 PNG 두 장만 새 결과로 갱신하며 소스 revision을 덮어써 다른 이미지를 새 빌드의 증거로 만들지 않는다.

최종 보완 증거: [최대 글씨 후속1개 receipt](../design/full-redesign-map/review/today-compact-2026-10-26/max-caption-ui-result.json). 관련21개 고유 검사와 후속 재검증1회를 합쳐22회 성공이다. 기본 글씨·다른 카드의 변경 없는 성공 결과를 전체 반복하지 않았으며 표준 HStack은 delta 리뷰로 동일함을 확인했다.
