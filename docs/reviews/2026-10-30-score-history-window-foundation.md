# Score history window foundation review

> 2026-10-30 · PR863 · base9fa10e46 · source2ecfa3ff

Security·Performance·Architecture·Data Integrity·Simplicity의 실제 읽기 전용 리뷰에서 도입된P1/P2/P3는0개다. AppQuality도 범위 지정 게이트를 통과했다. 기존 함수 본문은 동일하고 ViewModel의 호환 진입점만 delegate로 바뀐다. Agent-Native는 instruction/prompt/config 변경이 없어 제외한다. SwiftUI/AppleUX 추가 검토·새 실제 캡처는 View/배치/문구/상태/내비게이션 변화가 없어 해당 없음이다. 대량 처리·새 알고리즘이 없어 perf-optimizer 추가 실행도 해당 없음이다.

## 실제 검증

- 표준 regen/generic iOS build 및 precommit compile 통과.
- 기존 ConditionScoreDetailViewModelTests26개 통과, 실패/skip0. 월말·윤일·DST·half-open current/prior·가용0/자료없음·raw-day가중치·페이지 경계 계약을 유지한다.
- 전용 iPad7AA4의 DesignCapture 선택 UI2개 정상 종료/통과: `DashboardSmokeTests/testAppLaunchesOnDashboard`는 foreground만 확인하고, `ConditionDetailRedesignTests/testPeriodWindowAndTrendControlsUpdateVisibleReadback`가 Today 진입과5개기간·앞뒤·통계 갱신을 확인한다.
- 자동 계획의 iOS/Watch full/full은 Shared/pbx 경로 fallback이다. 실제 호출자 두 delegate와 iOS-only source membership, UI scope expert 판단에 따라 위 항목을 선택했다. 사용자 full 요청은 없으며 전체/full은 미실행·미검증이다. 다른 탭/Watch/visionOS/widget 검증으로 확대하지 않는다.

## 최초 UI 실패와 조건 변경

첫 Full-plan 선택 실행에서 기간 검사는 XCTest 로그상 통과했으나, `testConditionTrendAndHeroDetailRoute`가 상세 진입 전 주간 대체 차트만을 요구하는153줄에서 실패했다. 앱은 유효한 시간별 차트가 있으면 그것을 먼저 표시한다. 사용한 fixture는 시간별 경로를 막지 않는다. 실패 당시 실제 분기나 baseline 재현을 확인하지 않았으므로 기존 실패라고 단정하지 않는다. 새 helper는 상세 VM 안에서만 호출돼 이 before-tap 분기와 무관하다.

이후 Xcode 결과 정리도300초 idle 한도로 종료됐다. 정상 성공 receipt가 아니므로 원래 기간 검사도 이 실행만으로 완료 처리하지 않았다. 원본 로그/원인 기록을 보존하고, 소스·fixture를 수정하지 않은 채 scope expert가 승인한 기본 foreground smoke로 대체했다. DesignCapture의 `collect-test-diagnostics never` 조건으로 결과 정리 정체를 피하고 기간 검사도 다시 확인해 정확히2pass/0fail/0skip·exit0을 얻었다. 원래 실패 selector를 무조건 반복하거나 unrelated Dashboard 코드를 수정하지 않았다.

증거: [validation.json](2026-10-30-score-history-window-foundation/validation.json), unit/UI summary·receipt·gzip, 자동 계획과 scope-decision, 원래 실패 기록. 이전 T04의32/15는 이 PR의 검증으로 재분류하지 않는다.

최종 PR reviewer의 소스/문서/증거 대조에서도 새P1/P2/P3는0개다. 코드 검증 source는2ecfa3ff이며, 이후 변경은 이 문서·증거 및 실제 T04 Ship 상태 기록뿐이다.
