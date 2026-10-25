---
topic: today-reading-v2
date: 2026-10-25
status: implemented-validated
confidence: high
related_solutions:
  - ../solutions/architecture/2026-04-05-cumulative-stress-detail-view.md
  - ../solutions/general/2026-03-30-sleep-card-redundant-unit.md
related_brainstorms:
  - ../brainstorms/2026-03-29-today-tab-evolution.md
---

# Implementation Plan: Today 하단 읽기 위계 V2

## Context

사용자가 검토한 [V2 시안](../design/theme-map/themes/dune-today-reading.html)을 회복·수면, 장기 스트레스, 오늘 요약에 적용한다. 작은 글씨가 같은 밀도로 반복되는 문제를 큰 수치·짧은 상태·펼치는 근거로 해결한다. `/run`이 구현·검증·PR·머지까지 승인한다. 기존 `codex/today-design-fidelity`의 미완료 UI 실행과 Watch 변경은 포함하지 않고 main f4d56f63에서 분리한다.

## Requirements

- 지난 수면을 큰 숫자로 표시하고 수면 부족과 구분한다. 수면 히스토리 기간·단위를 명시한다.
- 스트레스 점수·상태를 강조하고 근거를 펼친다. 상세 진입을 보존하며 링크 안에 disclosure 버튼을 중첩하지 않는다.
- 오늘 요약은 기존 `DigestMetrics`로 수치와 짧은 상태를 표시한다. 원문 요약은 펼칠 수 있고 누락값을 0으로 만들지 않는다.
- 기존 테마 토큰·서체·Dynamic Type·en/ko/ja를 사용한다. 모델·계산·HealthKit 조회·전역 스크롤은 변경하지 않는다.

## Approach

화면 전용 SwiftUI 표시 변경으로 제한한다. `StandardCard(padding: DS.Spacing.xxl)`와 기존 시간·숫자 formatter를 재사용한다. 새로운 데이터 모델 대신 `DailyDigest.metrics`를 사용한다. 누적 스트레스 카드의 외부 NavigationLink는 내부 명시적 상세 링크로 옮긴다.

| 대안 | 장점 | 한계 | 결정 |
|---|---|---|---|
| 간격만 확대 | 범위 작음 | 문단·근거 밀도가 남음 | V1 비교용 보존 |
| V2 표시 재구성 | 정보 위계 명확, 데이터 재사용 | disclosure·큰 글씨 검증 필요 | 채택 |
| 분석·요약 모델 변경 | 문구 완전 재구성 가능 | 불필요한 도메인·동기화 위험 | 제외 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift` | modify | 큰 지난 수면·명시적 수면 부족·차트 기간/단위 |
| `DUNE/Presentation/Dashboard/Components/CumulativeStressCard.swift` | modify | 큰 점수·상태·분석 근거·상세 링크 |
| `DUNE/Presentation/Dashboard/Components/DailyDigestCard.swift` | modify | 지표형 요약·원문 펼침; T10 소비자 포함 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | 스트레스 링크 중첩 제거 |
| `DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift` | modify | 공유 카드의 컨디션·걸음 중복 제거, 수면 보충 |
| `Shared/Resources/Localizable.xcstrings` | modify | 새 문구 3개 언어 |
| `DUNEUITests/Visual/TodayReadingUITests.swift` | add | seeded 렌더링·토글·상세·큰 글씨·캡처 |
| `docs/design/{layout-map,theme-map,phone-design-map}/` | modify | 시안 보존·계약·실제 캡처와 출처 |
| `docs/solutions/general/2026-10-25-today-reading-hierarchy.md` | add | 최종 구현·검증 한계 기록 |

## Implementation Steps

1. 시안·맵 기준 보존 및 회복 카드: 유효한 수면만 크게 표시, 수면 부족 별도 행, 실제 히스토리 기간·단위·누락 보존. Swift 구문 검사 후 단위 커밋.
2. 스트레스·요약 표시와 내비게이션: 기존 데이터·formatter 재사용, 근거/원문 disclosure, 큰 글씨 세로 확장, 상세 링크와 식별자. 단위 커밋.
3. en/ko/ja 카탈로그·UI 테스트·프로젝트 재생성. `format-xcstrings.swift --check` 전후 검사. 새 계산 로직이 있으면 관련 단위 테스트 추가; body만 변경하면 UI 테스트로 검증.
4. 표준 빌드와 targeted UI·공통 진입 검증. 캡처 PNG 육안 확인 후 디자인맵 갱신. Review·Quality·Resolve·Compound·Ship를 순차 수행.

## Edge Cases

| Case | Handling |
|---|---|
| 수면 지표만 있음 | 지난 수면과 상세 표시; 결손·차트 강제 생성 안 함 |
| 수면/근거 없음 | 기존 shouldShow 계약에 유효한 수면만 추가; 없는 기록은 감춤 |
| 큰 글씨·긴 번역 | 세로 배치·자연 줄바꿈·고정 높이/축소 없음 |
| 차트 날짜 누락 | 실제 표본만 표시; 0시간 표본 생성 금지 |
| 요약 지표 일부 없음 | 해당 항목 감춤; 원문 요약 보존 |
| 알림에서 일간 요약 진입(T10) | 같은 카드 소비자; 내용·원문 확인 |
| 스트레스 disclosure | 명시적 상세 링크와 별개 행동 |

## Testing Strategy

- `scripts/build-ios.sh` 실제 실행. 새 로직 없는 SwiftUI body는 UI 테스트로 확인한다.
- `python3 scripts/plan-ui-tests.py --base main`으로 범위 산출 후 호출부 분석. 공유 카탈로그는 문자열 추가에 한정하므로 watch/full UI로 확대하지 않는다.
- 전용 worktree 소유 iPhone에서 새 Today suite + 공통 smoke 관련 진입을 실행한다. 실패 시 원인 수정 후 해당 테스트만 최대 1회 재시도; 기존 Today 다른 브랜치의 실패는 통과로 재사용하지 않는다.
- iPad·Duo 접힘·펼침도 T03의 영향 기기다. 각 전용 기기에서 새 화면만 캡처한다. T10 원문 확인도 포함한다. 기기 상태/공용 잠금 등으로 불가능하면 화면 ID·기기·재개 조건을 기록하고 완료로 표시하지 않는다.
- 캡처는 `.xcresult`의 새 첨부 화면에서 추출하고 출처·기기·소스를 기록한다. 기존 시안 PNG는 실제 앱 증거로 사용하지 않는다.
- 전체 회귀는 요청되지 않아 실행하지 않는다. 검증 종료 조건은 변경 기능+공통 진입 통과, 영향 화면 새 캡처·육안 확인, open P1/P2=0이다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 링크와 펼침 제스처 경쟁 | 중간 | 상세 오진입 | 외부 링크 제거·독립 행동 UI 테스트 |
| 요약 내용 손실 | 중간 | 데이터 맥락 상실 | 원문을 disclosure에 보존 |
| 큰 글씨 카드 높이 증가 | 높음 | 스크롤 필요 | 콘텐츠 자연 확장·전체 카드 동시 노출 강제 안 함 |
| 시뮬레이터 잠금·기기 상태 | 중간 | UI 게이트/캡처 미완료 | 표준 runner·deadline·실제 실패 기록 |

## Confidence Assessment

High: 데이터 모델·계산을 재사용하는 국소 표시 변경이다. 네 기기 캡처와 UI 검증은 실행 결과로만 판정한다.

## Execution status

구현과 P2수정을14d37e32에 반영했다. 명시적 허용 뒤 iPhone2/2·iPad2/2·Duo접힘2/2 및 Duo펼침의 통과 T10+수정 후 카드1/1을 확인했다. 이전 iPhone7/7의 variant 증거는44018fcc로 유지한다. 실제 화면38장과 각도0°/180°·활성 화면·창 크기를 기록했다. 펼침 테스트의 장식 Image선택 오류는 테스트만 수정했고 재시도 내역을 보존한다. 상세 결과는 [실행 기록](../reviews/2026-10-25-today-reading-v2-run.md)에 보존한다.
