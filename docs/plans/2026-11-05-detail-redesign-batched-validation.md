---
tags: [detail-redesign, targeted-ui, batching, validation-reuse]
date: 2026-11-05
category: plan
status: approved
confidence: medium
related_solutions:
  - ../solutions/general/2026-11-05-injury-history-icons-contrast-and-lazy-list.md
---

# 상세 화면 개편: 화면 묶음과 검증 공유

## Context

사용자가 관련 화면을 묶어 구현·검증하도록 요청했다. 기존 화면별 PR 원칙은 유지하고, 같은 worktree·앱 타깃·기기·검증 환경의 빌드, 설치, 부팅, 테스트 실행 비용을 공유한다. 이 문서는 작업 방식의 변경이며 앱 구현이나 검증 완료 증거가 아니다.

기준 main은 `3e0a97bdca2b0e4e0be20c3f2a2b00863a993b54`이다. 이전 81개 원래 계획 ID에서 실제 머지된 20개를 제외한 **61개**가 남았다. 60개는 아래 17개 검증 묶음 후보, H08 한 개는 기존 실패 경로 중단 상태다. T06 체지방 후속은 PR #917로 완료되어 이 수에 추가하지 않는다. S07/W32는 A05의 공유 자식 구현만으로 완료 처리하지 않는다.

## Requirements

- 화면별 기능·상태·아이콘·기간 선택·내비게이션 보존과 fresh 실제 캡처를 유지한다.
- 한 번에 이 worktree 소유 시뮬레이터 한 개, 무거운 실행 한 개만 사용한다.
- 묶음의 App/UI/fixture 내용을 고정한 뒤 기기별 한 표준 실행에 정확한 selector 합집합을 전달한다. 각 테스트는 필요한 seed로 독립 실행한다.
- 정상 상태와 필요한 MAX·오류·빈 상태를 화면별로 정한다. 대표 화면 하나의 성공을 다른 화면의 성공으로 대신하지 않는다.
- 이미 유효한 compile·테스트·캡처·리뷰는 단계가 달라도 재사용한다. 문서 변경만으로 앱을 다시 빌드하지 않는다.

## Approach

완료한 화면의 source/test/map 변경을 화면별 커밋으로 분리하고, 같은 묶음의 누적 통합 후보를 검증한다. 표준 실행기의 반복 `--only-testing`을 사용하며 새 실행기·전역 정책·`.claude/**`는 수정하지 않는다. 기기별 컴파일은 증분 캐시를 사용한다. 서로 다른 시뮬레이터/SDK에서도 물리적으로 빌드를 단 한 번만 한다는 보장은 하지 않는다.

화면별 PR에는 묶음 실행의 해당 테스트·PNG·AX 증거만 연결한다. 검증한 통합 tip과 PR의 관련 App/테스트/fixture/공유 의존성 내용 및 실행 조건이 동일한지 확인한다. 후속 화면 의존성이나 App 변경 때문에 동일성을 입증할 수 없으면 해당 PR에 필요한 최소 검사를 추가한다. 통합 tip 성공을 다른 PR revision의 성공으로 자동 전환하거나 receipt를 수정하지 않는다.

## Affected Files

| File | Change |
|---|---|
| 이 계획서 | 검증 묶음·PR·재사용 계약 |
| `.codex-checks/detail-rollout/batched-validation-plan-2026-11-05.json` | 원래 ID별 묶음/완료/중단 추적, 로컬 전용 |
| `.codex-checks/detail-rollout/quality-queue/current-continuation-2026-11-03.json` | 현재 첫 묶음과 다음 실행 갱신, 과거 결과 보존 |
| `.codex-checks/h10/continuation-state.json` | 단독 검증 시작 대신 첫 묶음 통합 준비 |
| 화면별 App/UI·layout/theme/actual map | 각 묶음 구현 계획에서 실제 영향 파일과 selector를 확정; 이 계획에서는 미변경 |

## Implementation Steps

1. 실제 main과 남은 ID를 대조하고 아래 후보를 큐에 기록한다.
2. **첫 묶음 H10/H11/H12/H13**의 기존 코드·디자인맵·호출부·테스트를 확인하고 화면별 패치를 준비한다. H10 기존 private 초안은 재사용하며 별도 단독 UI 실행은 시작하지 않는다.
3. 4화면 구현과 테스트를 고정한다. 최종 selector/seed/상태/기기/예산을 실행 전 기록한다.
4. 첫 기기의 핵심 정상·MAX 검증과 native 이미지 품질 검토를 먼저 수행하고, 문제를 해소한 최종 내용으로 나머지 영향 기기를 한 개씩 검증한다.
5. 실패한 화면과 공유 영향 범위만 수정·재검증한다. 원인별 실패/재시도 기록은 묶음 전후 동일하게 보존한다.
6. 화면별 리뷰·Compound·실제 맵·PR을 마치고 순서대로 머지한다. 완료 수는 실제 머지된 ID만 감소시킨다.

## 검증 묶음 후보

현재 소스의 소비자·test plan·seed·실행 비용을 확인한 뒤 크기를 조정한다. 묶음은 PR 단위나 성공 증거를 뜻하지 않는다.

| 순서 | 화면 ID | 묶는 이유 |
|---|---|---|
| 01 | H10, H11, H12, H13 | 현재 상세 초안을 살리고 Wellness·수면 상세의 카드·설명 시트 검증을 공유 |
| 02 | H14, T17, T18 | 건강 설명·질문·지표 도구; 서로 다른 진입 경로는 각각 확인 |
| 03 | L02, L04, L09 | 습관 생성·관리·지난 날짜 입력; 같은 기록 흐름 |
| 04 | L05, L06, L07, L08 | 습관 이력·분석; 공통 데이터와 날짜 조건 |
| 05 | P01, P02, P03, P04 | 자세 촬영·실시간·선택·결과; 카메라 권한/시뮬레이터 제한 구분 |
| 06 | P05, P07, P08 | 자세 이력·대칭·비교 |
| 07 | S01, S02, S03, S04 | 설정·운동 기본값·선호 운동 |
| 08 | S05, S06 | 새 소식 목록과 기능 상세 |
| 09 | W01, W02, W03, W04 | 운동 목록·선택·정보·생성 |
| 10 | W05, W06, W31 | 근력 시작·세션·마지막 세트 |
| 11 | W07, W08, W09 | 휴식·RPE·도움말; single/template/compound 영향 소비자 조사 |
| 12 | W10, W11, W26, W27, W28 | 완료·공유·기록; 수동/HealthKit 소유권 각각 확인 |
| 13 | W12, W13, W14, W15, W34 | 템플릿 목록·편집·선택·주간 계획·AI 진입 |
| 14 | W16, W19, W20, W21, W22 | 템플릿·복합 운동·전환; 종료와 저장 경로 각각 확인 |
| 15 | W23, W24, W25 | 유산소 시작·진행·완료 |
| 16 | W29, W30, W33 | 분류 관리·추가·이름 편집 |
| 17 | S07, W32 | 공유 주간 통계의 별도 창/시트; iPad 창 생명주기와 복귀 각각 확인 |
| 보류 | H08 | 기존 Duo 닫힘 Add toolbar 동일 실패가 허용 재시도 후 남음; 새 묶음/ID로 재시도 횟수를 초기화하지 않음 |

## Testing Strategy

작업 방식/문서 변경 자체에는 앱 빌드·UI 실행이 필요하지 않다. ID 중복/누락, 61개 산술, 참조, diff를 확인한다.

첫 묶음의 기존 selector 후보는 아래와 같다. 아직 실행/통과한 것이 아니며 새 디자인의 완전한 화면 내용·복귀/닫기 검사를 보강한 뒤 확정한다.

- `DUNEUITests/WellnessRegressionTests/testInjuryHistoryRowOpensDetailAndEditForm`
- `DUNEUITests/WellnessRegressionTests/testInjuryHistoryAtMaximumAccessibilityTextSize`의 기존 H10 확장 private 초안
- `DUNEUITests/WellnessRegressionTests/testInjuryStatisticsRouteOpensFromHistory`
- `DUNEUITests/SleepDetailSmokeTests/testSleepDebtExplanationOpens`
- `DUNEUITests/SleepDetailSmokeTests/testWakeAnalysisExplanationOpens`

DesignCapture/DuoAudit test plan은 같은 DUNEUITests 타깃을 선택하고, 표준 실행기는 반복 `--only-testing`을 받는다. sleep 진입의 `XCTSkip`은 해당 화면 검증 통과로 세지 않는다. 각 화면의 native 캡처와 돌아가기/닫기 증거가 필요하다. MAX는 큰 카드 전체를 동시에 보이도록 강요하지 않고 각 필드의 완전한 접근을 확인한다.

각 실행의 초기 예산은 기존 targeted UI 1200초다. selector 합집합의 예상 실행시간이 이를 넘으면 실행 전에 2개 하위 묶음으로 나눈다. 동일한 컴파일/기기 캐시는 계속 재사용한다. 실패한 테스트를 다시 실행하기 위해 통과한 전체 묶음을 반복하지 않는다.

## Risks / Edge Cases

| Risk | Handling |
|---|---|
| 큰 묶음의 실패로 전체 반복 | 기본 3~5 화면, 1200초 사전 예산, 실패 selector만 재실행 |
| 화면별 PR과 통합 tip의 내용 차이 | 관련 source/test/fixture/공유 의존성 동일성 확인; 불명확하면 해당 최소 검사 |
| 공유 helper 수정 | 영향받은 기존 소비자 selector만 합집합에 추가 |
| 다른 seed/상태/기기 | 한 실행 내부에서도 테스트별 relaunch·fixture를 명시; 다른 조건으로 증거 대체 금지 |
| 카메라/창/HealthKit 실제 권한 제한 | 실제 실패 단계와 미검증 범위를 기록; 가짜 정상 상태로 완료 처리 금지 |
| H08 실패 횟수 우회 | 보류 기록 유지; 새 ID/묶음 이름은 재시도 권한이 아님 |

## Confidence

방식 전환은 high, 각 묶음의 정확한 실행시간/패치 독립성은 medium이다. 앱 코드가 아직 합쳐지지 않았으므로 절감률이나 완료 시각은 주장하지 않는다.
