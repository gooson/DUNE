---
topic: posture-exercise-picker-p03-redesign
tags: [posture, detail-redesign, p03, batched-validation]
date: 2026-11-06
category: plan
status: approved
confidence: medium
related_solutions: [../solutions/architecture/2026-03-16-posture-orientation-coordinate-contract.md]
---

# P03 운동 선택 개편 계획

## Context / Requirements

기존 상세 개편을 B05 P01–P04로 묶어 이어간다. 원래 General Posture 선택 행 → Form Check 운동 목록. 기존 아이콘·체크를 유지하고 앞자리 심볼 면·선택 위계를 보강한다. 일반 글씨는 medium에서 시작하고 large로 확장한다. MAX(accessibility5)는 large만 사용하며, 목록 밖 상단 안전 영역에 기존 Close와 Exercise Mode를 고정한다. MAX에서 NavigationStack toolbar 대신 이 헤더 한 개를 사용한다.
onSelect(nil)·각 운동·selected checkmark·Close·scroll 보존. MAX는 세로 레이블, 끝 행 도달·선택/복귀 확인.
카메라/추론/모델/저장 boundary는 변경하지 않는다. .claude 원본과 다른 활성 작업은 보존한다.

## Approach / Alternatives

기존 DS·ScoreHeroPalette·원래 기호/문구로 표현만 보강한다. 큰 camera hero로 영상/조작을 가리는 방식과 새로운 가짜 inference fixture는 제외한다. 카메라 실패는 실제 가능한 fallback 검증으로 구분한다.

## Affected Files

| File | Change |
|---|---|
| DUNE/Presentation/Posture/Components/ExercisePickerSheet.swift | 현재 기능을 보존한 화면 표현/안정 AXID |
| DUNEUITests/Full/WellnessRegressionTests.swift | 해당 화면의 핵심 상호작용·PNG/AX·MAX |
| docs/design/layout-map/posture-exercise-picker-p03.html | 구현 전 배치 계약 |
| docs/design/theme-map/themes/dune-posture-exercise-picker-p03.html | 구현 전 정적 방향 |
| docs/design/phone-design-map/actual/{regular,ipad,duo,duo-open} | 최종 실제 PNG/AX·출처 및 포털 |
| docs/solutions/general/2026-11-06-posture-exercise-picker-p03.md | 최종 구현·검증·제한 |

## Implementation Steps

1. 최신 main f044aa09와 실제 source·callers·기존 PostureVisualAuditTests/seed를 대조한다. 과거 미적용 P03 detent 제안은 source 확인 후 반영한다.
2. 배치/테마 맵을 먼저 저장·연결한 뒤 표현을 구현한다. P01/P02/ P03/ P04 각각 커밋한다.
3. 필요한 AXID와 정확한 test selector를 동결한다. camera fallback/Close, realtime entry/Close, picker nil/exercise/selection/Close/scroll, result score/partial/metrics/memo/Save/Retake를 화면별 확인한다.
4. 같은 SDK/타깃의 증분 컴파일·설치·기기 실행을 공유한다. 한 번에 소유 simulator 1개·무거운 실행 1개.
5. 독립 관점 리뷰·resolve·solution·새 actual map을 마친 뒤 화면별 PR을 정상 merge한다. 검증한 통합 source와 각 PR 관련 내용의 동일성을 확인한다.

## Testing Strategy / Execution Contract

표준 scripts/test-ui.sh의 정확한 PostureVisualAuditTests method selectors를 사용한다. 앱 로직을 변경하지 않으면 unit 추가는 면제하며 View body를 UI로 확인한다. iPhone normal 먼저, 필요한 MAX·ko/ja 표본, iPad·Duo closed/open normal 순차. 실행 전 실제 selectors·UDID·runtime·seed·예산은 .codex-checks/b05/execution-contract.json에 기록한다. UI의 iOS target compile 성공은 별도 build-only로 반복하지 않는다. 초기 deadline 각 targeted UI 1200초, jobs2/index OFF/parallel OFF. 동일 원인 재시도 최대1회, 원인 변화 증거 필수. H08 한도/보류 유지.

## Edge Cases / Risks

| Risk | Handling |
|---|---|
| camera unavailable/permission | 원래 오류·실제 가능한 retry·Close만 확인; 실물 frame/추론/자동촬영/방향은 실기기 미검증 명시 |
| MAX·긴 번역 | 전체 프레임/스크롤로 읽기·CTA 접근, 원래 의미/아이콘 보존 |
| partial/no image | 임의 점수·사진 보충 금지; 원래 partial/빈 사진 안내 |
| 기존 원본 실종 | Git 코드와 보관된 다른 증거만 재사용. l03 raw SDK archive 복구는 미확인 |
| shared execution·화면별 PR | 관련 source/test/seed closure와 통합 검증 source SHA 기록; 전체 회귀 통과 주장 금지 |

## Confidence

표현/기능 보존 high, 실제 카메라·환경별 검증 medium. 완료 건수는 실제 merge 후에만 차감한다.

## MAX Close 보완 · 2026-11-06

Duo 접힘 MAX의 재진입·마지막 행 스크롤 후 Exercise Mode 내비게이션 바에는 자식이 없고 Close 식별자도 없었다. PNG에서도 시트 제목·Close가 사라져 테스트 조회만의 문제는 아니다. 프레임워크 내부 원인은 미확정이며, MAX에서 toolbar 의존성을 제거하고 large로 표시해 고정 헤더와 전체 행 공간을 분리한다. General의 onSelect(nil), 운동 선택, 원래 기호·체크, Close의 dismiss 의미는 유지한다. 기존 Duo 실패 및 재시도 예산을 보존하고 해당 기기의 변경 후 검증은 미완료로 남긴다. 새 실행은 허용된 범위만 수행한다.
