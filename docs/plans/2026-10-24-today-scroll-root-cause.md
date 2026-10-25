---
topic: today-scroll-root-cause
date: 2026-10-24
status: completed
confidence: high — isolated inspector host and verified original failing gestures
related_solutions:
  - docs/solutions/performance/2026-10-16-today-scroll-top-settling.md
  - docs/solutions/performance/2026-10-17-today-native-pull-scroll-lock.md
related_brainstorms: []
---

# Implementation Plan: Today 스크롤 점프 원인 분리

## Context

사용자가 세 차례 수정 이후에도 재현되는 Today 스크롤 영상을 제공했다. 현재 코드는 감속 종료 시 상단 130pt 이내의 모든 양의 오프셋을 즉시 zero-height anchor로 이동한다. 과거 테스트는 최종 상단 복귀만 검증해 의도한 부분 스크롤의 손실이나 복귀 중 불연속을 검출하지 못했다. 히어로 preference는 content-local이고 현재 배경에 inset 소비자가 없어 직접적인 스크롤 피드백 근거는 없다.

## Requirements

- 짧은 관성 스크롤에서 사용자가 멈춘 위치를 유지한다.
- 깊은 위치에서 빠르게 돌아오기, 실제 refresh 당김과 해제, 다음 스크롤, 탭 재선택을 검증한다.
- 위치 보정에 다른 threshold/delay를 추가해 원인을 가리지 않는다.
- 반복 `cannot add handler` 로그와 앱 offset 변경의 인과관계를 분리해 기록한다.

## Approach

먼저 seeded UI 테스트로 현재 자동 이동의 실패를 확인한다. 스크롤 phase/geometry trace와 영상으로 native title/inset 변화를 분리하고 자동 idle 이동을 제거한다. 그 상태에서도 상단 복귀가 깨지면 scroll host/anchor 구조를 별도 검증한다. 명시적인 탭 재선택만 프로그램 이동을 허용한다. Apple `ScrollPosition.scrollTo(edge:)`는 content view ID 대신 실제 edge를 대상으로 하는 대안이다.

| 대안 | 판단 |
|---|---|
| 방향·threshold·delay를 더한 자동 보정 | 정상 부분 스크롤 개입을 유지하므로 제외 |
| 내비게이션 제목을 고정 inline으로 변경 | 요구하지 않은 디자인 변경이므로 제외 |
| 자연 스크롤 + 명시적인 edge 이동 | 우선 검증 |

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/App/ContentView.swift` | Today NavigationStack 외부에 inspector와 배타적 metric/QA 상태 소유 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 자연 스크롤에 개입하는 보정 제거, 필요한 host/anchor 교정 |
| `DUNE/Presentation/Shared/Components/WaveRefreshTaskCoordinator.swift`, `WaveRefreshIndicator.swift` | native caller와 화면 소유 refresh 취소 분리 |
| `DUNETests/WaveRefreshTaskCoordinatorTests.swift` | 취소·중복 실행4개 계약 검증 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 부분 스크롤·빠른 복귀·refresh lifecycle 회귀 |
| `docs/design/layout-map/README.md` | T03 스크롤 계약 |
| `docs/design/phone-design-map/README.md`, `actual/**` | 영향 T03의 새 실제 캡처와 출처, 미검증 기기 명시 |
| `docs/solutions/performance/2026-10-24-today-scroll-root-cause.md` | 재현·원인·수정·검증 한계 |

## Implementation Steps

1. 수정 전 새 부분 스크롤 테스트와 영상/trace를 수집한다. 앱 source는 빌드 중 동결한다.
2. phase 기반 자동 이동을 제거하고 재현 테스트 및 기존 상단 복귀 테스트로 차이를 확인한다.
3. native 복귀 결함이 남으면 host/edge 구조만 원인별 실험한다. 반복 실패 뒤 사용자에게 받은 추가 원인 격리 승인을 적용한다. inspector·toolbar·refresh·배경·콘텐츠를 독립 비교한다.
4. 최종 소스의 targeted Today UI와 공통 smoke, iOS 빌드를 실행하고 T03 새 PNG를 확인한다.
5. 5관점 리뷰, SwiftUI·Apple UX 품질 검토, 해결책 기록 후 PR 생성·머지한다.

## Edge Cases / Risks

| 조건 | 처리 |
|---|---|
| 큰 제목의 정상 collapse | 실제 부분 offset을 top 실패로 오인하지 않는다 |
| refresh inset 복구 | 손을 뗀 momentum 경로와 held pull 모두 검증 |
| iPad·Duo | 동일 Dashboard 소비자. 영향 T03만 검증·캡처하며 불가하면 명시 |
| 시뮬레이터 잠금·정지 | 전용 UDID, 표준 실행기, 전체 deadline, 무관한 기기 조작 금지 |
| 무관한 기존 테스트 실패 | 이번 diff 관련성을 먼저 확인하고 범위 확대 금지 |

## Testing Strategy

순수 View 변경은 UI 테스트로 검증한다. 새 짧은 관성 스크롤, 깊은 위치에서 빠른 상단 복귀, 실제 refresh, manual 복귀, 탭 재선택을 선택 실행한다. 테스트의 최종 위치만으로 부드러운 전환을 인증하지 않고 영상/geometry trace를 함께 검토한다. 화면의 문구·카드 정보 순서·테마는 바꾸지 않는다. Watch/visionOS는 DashboardView 소비자가 아니므로 제외한다. 전체 suite는 요청되지 않아 실행하지 않는다.

## Pipeline State

| Phase | 상태 | 증거 |
|---|---|---|
| 0 Initialization | completed | 작업 브랜치 `codex/today-scroll-root-cause`; 삭제된 checkout은 저장된 브랜치에서 동일 경로로 복구 |
| 1 Plan | completed | 관련 solution·공식 API·코드·사용자 영상 분석과 이 계획서 |
| 2 Work | completed | inspector 소유자 이동 f356c479, main 통합 ef42c58e; 양쪽 정상 pre-commit iOS build 성공 |
| 2.5 UI | completed | main 통합 후 iPhone10·iPad4·Duo접힘2·펼침2 통과, 내부 디스플레이 native 캡처용 추가1건 통과 |
| 3 Review | completed | Security·Performance·Architecture·Data Integrity·Simplicity 각각 P1/P2/P3=0, Localization0; agent 파일 변경 없어 Agent-Native 제외 |
| 3.5 Quality | completed | SwiftUI·Apple UX·app-quality 각각 도입 결함0; 성능 대량 데이터 처리 변경 없어 perf-optimizer 제외 |
| 4 Resolve | completed | Review findings P1=0/P2=0/P3=0으로 추가 소스 수정 없음. main 통합 빌드 통과 |
| 5 Compound | completed | solution과 실제 캡처7장, 원본 영수증·소스 해시·리뷰 기록 저장 |
| 5.5 Pre-Ship | pending | 최종 실행 영수증과 문서 커밋 후 진행 |
| 6 Ship | pending | PR 생성·원격 merge는 검증 게이트 이후 수행, 결과는 실행 보고서에 기록 |

## 원인 격리 결과

사용자가 재시도 제한을 풀고 추가 격리를 승인했다. 기본 ScrollView에 refresh 없음·native·wave는 정상 복귀했고, 실제 Today에서 refresh·ScrollPosition·배경·toolbar를 각각 제외해도 실패가 남았다. 본문을 고정 Text로 바꾸고 inspector를 유지해도 실패했다. inspector만 제거한 실제 Today는 반복 복귀와 held pull 모두 초기 위치와 일치했다.

따라서 inspector를 기능에서 없애지 않고 Today NavigationStack 바깥으로 옮겼다. metric/QA 선택을 ContentView에 올리고 Dashboard의 callback으로 연다. 기존 실패했던 수동/전체 스크롤 검사는 제스처나 ±12pt 허용 범위를 완화하지 않고 통과했다. 경고 메시지의 발신자는 QuartzCore이며 경고 전체 제거를 성공 조건으로 삼지 않는다. 자세한 native trace·대조군과 적용 소스는 [해결책](../solutions/performance/2026-10-24-today-scroll-root-cause.md)에 있다.

TodoWrite 도구가 없는 런타임에서는 `.codex-checks/scroll-proof/pipeline.json`으로 Phase 상태와 증거를 유지한다. 리뷰 역할의 지정 모델이 런타임에 없어 현재 주 에이전트 모델을 상속했고, 5관점 및 전문 에이전트는 실제로 각각 실행했다.
