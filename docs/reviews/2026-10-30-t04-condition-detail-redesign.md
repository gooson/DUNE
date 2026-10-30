# T04 컨디션 상세 실제 앱 검증

> Date: 2026-10-30 · Scope: T04 iPhone/iPad/Duo native implementation · PR: [862](https://github.com/gooson/DUNE/pull/862)

현재 열린 source finding은 P1=0, P2=0, P3=0이다. 초기5개P2와2개P3를 수정했고 최종 기기별 증거 게이트도 통과했다.

현재 앱 구현은 `abe732c1`, 마지막 UI 테스트 헬퍼 수정은 `ee113c0e`다. 두 소스 사이 앱·단위 코드 diff는 없다. 계산/이력 모델의 Resolve는 `8d670752`이며, 이후 변경은 테스트 가시성·좌표 허용오차, T04 차트의 바깥 고정 높이 제거, RHR 기여 카드의 영향 표시 eligibility다. 검토한 시안의 링 히어로·실제 측정/영향·통합 추세·단일 설명을 구현했다. 시안의70/30 예시 비율은 실제 Z-score/심박·시간 조정으로 대체했다.

## 검증 상태

- 관련 단위 `ConditionScoreDetailViewModelTests`26개와 `ConditionScoreDisplayTests`6개: 최종 `abe732c1`에서32개 통과, 실패/skip0. `final-unit-result.json`·`final-unit-summary.json`·압축 로그에 실제 xcresult 출처를 보존했다. 보존 스크립트의 sidecar 경로 오류는 xcresult에서 복구했고 테스트를 반복하지 않았다.
- 최초 전체 iOS 단위 실행은 변경하지 않은 live AI 평가에서 실패/idle deadline으로 종료했다. 전체 단위 통과를 주장하지 않는다. 선택 실행 출력 파서는 별도 [PR861](https://github.com/gooson/DUNE/pull/861)에서 수정했다.
- 최종 기기별 고유 UI15개 통과: iPhone7, Duo 펼침6, Duo 접힘1, iPad1. 펼침은 원래5pass/1fail 배치와 탐색 조건 수정 후 실패한1개만 재실행한1pass를 구분한다. 원래 실패 기록을6pass로 바꾸지 않았다. `final-validation.json`이 실제 testcase 합집합·32단위·4기기 새 이미지 해시·앱 코드 동일성을 검증한다.
- 초기 실패/재검증 및 수정 전 시각 원본을 개별 JSON·압축 로그·PNG에 보존한다. 선택 검사를 full UI로 승격하지 않는다.

[이전·새 실제 앱 비교](../design/full-redesign-map/review/condition-detail-2026-10-30/index.html)에서 네 기기의 원본과 촬영 당시 출처를 구분한다. 밝음·영어·기본 DUNE의100점 DEBUG fixture이며 실제 사용자 기록이 아니다. Duo 패널은 CLI 활성 readback과 새 PNG를 대조한다. 수치 angle은 조회하지 않았다. 다른 테마·locale 전체를 촬영했다고 주장하지 않는다.

## Review / Resolve

Security·Performance·Architecture·Data Integrity·Simplicity, SwiftUI·AppleUX·AppQuality 관점을 수행했다. 일반5관점의 초기 원본과 Resolve delta를 구분한다.

| Finding | 수정 및 확인 | 상태 |
|---|---|---|
| P2 RHR 미적용/불충분 baseline이0/중립으로 표시됨 | Domain requiredDays에 따른 adjustment/impact eligibility; valid0/양음값/부족·누락 및 nonempty contribution6개 단위 | Resolvedabe732c1; Data/AppQuality delta 확인 |
| P2 고정 chart duration과 달력 summary의 불일치/오늘 제외 | 단일 참조 window, 완전한 구간 이동, 명시 query bounds; 월말/윤일/DST/roundtrip/조회 횟수26개 단위 | Resolved8d670752 |
| P2 dead summary와 전용 중복조회 | 기존 highlights/subscore 의미를 유지하며 legacy summary와2조회 제거 | Resolved8d670752; Simplicity/Performance delta 확인 |
| P2 plain controls의 glyph 크기 hit area | 44pt label frame + Rectangle contentShape; 실제 모서리 좌표 탭 | Resolved8d670752; 최종 iPhone/Duo 실제 모서리 탭 통과 |
| P2 최대AX chart overflow가 날짜/화살표 침범 | outer fixed height 제거, inner rendered footprint 단언; 새 AX 날짜 하단371.2/차트 시작383.3 | Resolved032c68e0; Duo AX 통과·AppleUX 시각 delta 확인 |
| P3 미사용 palette passthrough | 미사용 getter 제거 | Resolved8d670752 |
| P3 기간 전환 fade 손실 | `.id(period)` + opacity transition, Reduce Motion 분기 | Resolved8d670752; AppleUX source 확인 |

Security/Architecture/Performance/Simplicity/Data의 Resolve delta에서 새로운P1/P2 없음. 마지막 chart-height delta는 SwiftUI와 AppleUX, RHR tile delta는 Data/AppQuality가 읽기 전용으로 재검토했고 추가P1/P2 없음. 최종 AppQuality/PR의 앱·테스트 delta 및 증거/문서 재검토는 통과했다. 미해결P1/P2/P3는0개다. 구성 캡처의 장치·xcresult·PNG/AX 해시를 보완해 원본과 재확인했다.

Agent-Native는 지침·프롬프트 변경이 없어 제외한다. 추가 perf-optimizer는 기존의 제한된 일별/시간별 자료 요약이며 대량 처리 구현이 아니므로 제외하고 일반 Performance 리뷰에서 확인했다. 리뷰 증거의 범위를 full app 전체 품질 승인으로 확대하지 않는다.

## 최종 증거와 범위

- `final-unit-result.json`, `final-unit-summary.json`:32/32, 실패/skip0.
- `release-iphone-summary.json`:7/7.
- `release-duo-open-first-summary.json`:5/6 + `release-duo-composition-retry-summary.json`:1/1. 첫 실패의 AX는 값높이65.7/viewport669이며 카드가아직아래에있었다. Condition coarse 탐색의 실제 viewport 교차만 보완했고 전체 frame 검증·반복한도·타 route는 유지했다.
- `release-duo-closed-summary.json`, `release-ipad-summary.json`:각1/1.
- 네 기기의 T04만 새 캡처로 갱신했다. 다른 캡처 인덱스 항목은 수집기에서 동일성 assertion으로 보존했다. 밝음·영어·DUNE·DEBUG fixture100 범위다.
- [해결책](../solutions/architecture/2026-10-30-condition-detail-redesign.md), [기기별 이전/새 원본](../design/full-redesign-map/review/condition-detail-2026-10-30/index.html).
