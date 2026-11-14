---
topic: theme-overhaul-completion
date: 2026-11-14
status: scoped-verification
confidence: medium
related_solutions: [docs/solutions/design/2026-03-04-adding-new-theme.md, docs/solutions/testing/2026-10-28-wellness-flow-accessibility-and-native-evidence.md]
related_brainstorms: []
---

# Implementation Plan: 최신 화면의 8개 테마 개편 마무리

## Context

사용자가 디자인 개편 머지 확인 뒤 테마 개편의 모든 잔여 작업 실행을 요청했다. 기준은 main `96d1a60e5`다. 10월 전체 테마 계획의 WATER LILIES 미구현 설명과 124pt 공통 링 설명은 이후 구현으로 대체됐다. Today Compact, Activity Flow, Wellness Flow, 현재 Life의 승인된 배치를 우선하며 이전 배치로 되돌리지 않는다.

현재 linked worktree를 재사용한다. 기존 통합 브랜치는 보존하고 `codex/theme-overhaul-completion`을 origin/main에서 시작했다. 시작 dirty 파일은 없다. primary main의 Watch scheme 세 파일은 타 작업 변경으로 보호한다.

## Requirements

- 8개 테마의 현재 루트·상세·시트·운동 흐름에서 실제 값·행동을 보존한다.
- 원본 모티프의 정지 식별성, 밝음·어두움 대비와 장식/데이터 분리를 실제 화면으로 대조한다.
- 저장·복원, Watch·Widget·Vision의 선택값/asset 연결을 조사하고 실제 누락을 수정한다.
- MAX 글씨·고대비·동작 줄이기 및 en/ko/ja를 영향에 맞춰 확인한다. AX 레이블 검사를 실제 VoiceOver 조작 검증으로 표시하지 않는다.
- 새 캡처마다 소스·기기·viewport·시각·selector·결과를 기록한다. 기존 자료는 이력이며 새 증거로 재사용하지 않는다.
- 완료·실패·미실행을 상태표에 분리하고 오래된 전체 게이트를 현재 실행과 동기화한다.

## Approach

기존 공유 테마 라우터·팔레트·장면을 사용한다. 세 가지 독립 조사(모티프, 플랫폼 전파, UI selector)를 한 번 수행한 뒤 구체적 불일치만 수정한다. 단순히 오래된 문서가 미완료라는 이유로 앱을 다시 구현하지 않는다.

| 대안 | 판단 |
|---|---|
| 테마별 화면 복제 또는 전면 재작성 | 승인된 배치와 실제 데이터 계약을 깨뜨리므로 제외 |
| 공유 구현의 실제 차이 수정 + 최신 증거와 상태표 | 채택 |

## Affected Files

| 파일 | 변경 목적 |
|---|---|
| `DUNE/Presentation/Shared/Components/*Background.swift`, `WaveShape.swift`, `ProgressRingView.swift` | 조사로 확인된 모티프·motion 누락만 수정 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift`, Watch/Widget/Vision 소비자 | 실제 전파/대비 누락만 수정 |
| `DUNEUITests/Visual/ThemeMatrixUITests.swift`, `WaterLiliesThemeTests.swift`, `ThemeFlowMatrixUITests.swift` | 최신 배치·정확한 캡처·접근성/언어 검증 |
| 관련 `DUNETests`, `DUNEWatchTests` | 저장·팔레트·전파 계약의 필요한 테스트 |
| `docs/design/full-redesign-map/{README.md,spec.json,index.html,actual,review}` | 현재 계약·상태·새 캡처 보존 |
| `docs/design/theme-map/{README.md,manifest.json,index.html}`, `layout-map/README.md` | 최신 화면 우선순위와 원본 시안/실제 구분 |
| `docs/design/phone-design-map/actual` | 영향받은 기본 DUNE 실제 화면 갱신 |

## Implementation Steps

1. 기존 계획·solution·모티프/플랫폼 구현을 조사하고 현재 계약을 맵에 먼저 고정한다. 8개 영속 값과 WATER LILIES 구현은 재사용한다.
2. 실제 누락만 작은 단위로 수정·커밋한다. 테스트의 오래된 링 크기/목적지 가정은 실제 렌더러 기준으로 수정한다.
3. 관련 unit 계약을 실행하고 iPhone의 테마별 루트/대표 흐름을 밝음·어두움으로 검증한다. 실행 소스를 동결한 뒤 PNG+AX를 추출·검토한다.
4. iPad, Duo Closed/Open, Watch, Widget/Vision의 필요한 경로를 순차 검증한다. 프로비저닝/SDK 오류는 단계·명령·실제 오류를 보존하고 성공으로 승격하지 않는다.
5. 최신 근거로 구현 맵·실제 맵·계획 상태를 갱신한다. 5관점 및 SwiftUI/Apple UX/종합 품질 리뷰, 필요한 수정, compound, 최종 PR 리뷰를 마친 뒤 PR·머지를 진행한다.

## Testing Strategy and Occupancy

- build/unit/UI/capture는 한 번에 하나. jobs 2, index store OFF, test 병렬 OFF. 현재 worktree 소유 clone만 사용한다.
- iOS unit: `scripts/test-unit.sh --ios-only --only-testing DUNETests/AppThemeTests` 및 확인된 테마 palette/motion/shared storage suite만 추가. 1200초 watchdog.
- iOS UI: `ThemeMatrixUITests/test<Theme>Matrix`, `WaterLiliesThemeTests/testFourTabRootsInLightAndDark`, 저장 복원 selector, `ThemeFlowMatrixUITests/test<Theme>Flows`를 테마별 bounded batch로 실행한다. 각 batch deadline 1200초. MAX/locale selector는 별도 실행해 기본 캡처와 구분한다.
- iPad/Duo: 동일 테마 소비자의 루트·흐름 대표 상태. 모든 테마의 새 루트 증거를 기기별로 추적하며 각 batch의 정확한 selector와 소유 UDID를 실행 전에 기록한다.
- Watch: 기존 `WatchThemeMatrixUITests`와 필요한 theme storage/DTO unit. 폰→Watch 실전파는 단순 UI override 캡처와 별도 판정한다.
- Widget: 기존 render/snapshot 경로를 조사하고 실제 runtime view가 없으면 build/asset 계약과 구분한다. Vision은 설치 runtime을 확인하고 실제 실행 불가 사유를 기록한다.
- 원인 변화가 확인된 동일 실패만 1회 재시도. full local regression을 추가하지 않는다. 이후 phase는 유효한 동일 소스 증거를 재사용한다.
- `swift scripts/format-xcstrings.swift --check --check-manual`, 두 맵 생성기의 `--check`, 참조/출처 검사. 앱을 컴파일한 UI 성공 뒤 같은 target build-only를 반복하지 않는다.

## Edge Cases / Risks

| 경우 | 대응 |
|---|---|
| 오래된 계획/캡처를 완료로 오인 | 10월 기록과 11월 현재 검증을 분리 |
| 건강 상태색과 테마 링 계약 충돌 | 최신 승인된 Compact/Flow 계약을 우선하고 숫자·상태 문구 보존 |
| 큰 글씨에서 전체 화면보다 큰 콘텐츠 | 전체 요소 동시 표시를 강제하지 않고 실제 scroll 도달성 확인 |
| Duo 물리 방향 API와 viewport 불일치 | 상태 readback·새 PNG·AX viewport를 함께 기록 |
| 미설치 visionOS/Watch pair 또는 SDK 오류 | 실제 실패 단계와 미검증 범위를 유지, 임의 통과 금지 |
| 장시간 매트릭스 | 테마별 bounded selector; 한 기기·한 실행만 유지 |

## Evidence / Phase Ledger

- Initialization: clean linked worktree, base `96d1a60e5`, 기존 main 로컬 변경 보호.
- Plan: 이 문서와 기존 `2026-10-19-full-theme-redesign.md`를 함께 사용한다. 후속 실행 결과는 전용 review 갤러리에 기록한다.
- Work: WATER LILIES 장면·motion 정리, Any/Dark 기본 lookup, Today 데이터 대비, 일본어 기간 배치를 구현했다. 생산 소스는 `a5749e105` 이후 동일하다.
- UI: iPhone 루트8/8, iPad10/10, Duo 접힘4/4+4/4 및 extras2/2, Watch16/16. 실제 VoiceOver·고대비·Reduce Motion·복귀·저장·en/ko/ja 관련 selector 통과. 전체 회귀 또는 모든 상태 시각 검증을 뜻하지 않는다.
- Evidence: 3기기 루트192 PNG/AX + Watch24 + MAX·흐름·접근성31을 실제 맵/검증 갤러리에 보존했다. 초기 Phone flow/MAX의 source dirty 상태가 확정되지 않아 새 공식 flow 인덱스로 승격하지 않았다.
- Runtime limits: Duo 펼침64조합은 내부 패널 활성화 실패로 이번 소스 미캡처. Widget native·Vision runtime·Watch 실전파는 미검증이며 성공으로 계산하지 않는다. [정확한 범위·원본 실패·재개 조건](../design/full-redesign-map/review/theme-overhaul-2026-11-14/README.md)을 따른다.
- Review/Resolve: 5관점 소스 리뷰 및 Phone/iPad/Duo 실제 표본 리뷰. 대비 P1/P2와 inventory P2 해소; scenePhase 방어 P3 유지. 최종 품질 게이트와 PR 리뷰 통과(P1/P2 없음); 인벤토리 문구 P3 수정.
- Compound: `docs/solutions/testing/2026-11-14-theme-native-evidence-and-contrast.md` 생성. `.claude/**` 원본은 수정하지 않았다.
- Pre-Ship: 두 맵 check·도구 계약13개·xcstrings format/manual·native247쌍 SHA/참조 검사 통과.
- Ship: 검증된 범위와 공개한 runtime 한계로 PR·머지 진행. 원격 결과는 해당 PR에서 확인한다.
