---
topic: posture-history-p05-redesign
date: 2026-11-06
status: approved
confidence: medium
related_solutions: [../solutions/general/2026-11-06-posture-result-p04.md]
related_brainstorms: []
---

# Implementation Plan: P05 history

## Context

원래 상세 개편 B06의 P05를 기존 main 코드와 보존된 증거로 이어간다. l03/batch04 실종 원인·원본 복구는 미확인이다. B05 P03와 H08의 기존 한도·보류를 유지한다.

## Requirements

### Functional

기존 실제 점수·날짜·정렬·단위·기호·data flow·navigation/callbacks를 보존한다. P05는 최신 실제 record 요약, 원래 차트/필터/행·상세·비교·삭제·Capture·빈 상태를 유지한다. P07은 여섯 기존 좌우 값·부호·단위·bar/difference와 no-data를 유지한다. P08은 두 record·newer−older delta·날짜·사진·joints·zoom·두 scroll pane을 유지한다.

### Non-functional

ScoreHeroPalette의 불투명 강조면과 기존 StandardCard·DS, 680pt 읽기 폭을 사용한다. MAX에서 글자·값·조작이 도달 가능해야 한다. .claude 원본과 다른 활성 작업·기기는 변경하지 않는다.

## Approach

구현 전 layout/theme 맵을 먼저 보존·연결한다. 기존 View 표현만 바꾸고 ViewModel·분석·저장·fixture 계산을 바꾸지 않는다. 같은 타깃 증분 컴파일과 exact selector 실행을 공유하되 화면별 리뷰·실제 맵·solution·PR을 분리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 기존 DS와 실제 record 사용 | 기능·데이터 보존 | 실제 MAX 확인 필요 | 선택 |
| 새 점수/가상 기록·공통 화면 재작성 | 없음 | 원래 계약과 범위 확대 | 제외 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| DUNE/Presentation/Posture/PostureHistoryView.swift | modify | 표현·안정 AX |
| DUNEUITests/Full/WellnessRegressionTests.swift | targeted tests | 기존 isolated visual posture seed 재사용 |
| docs/design/layout-map/posture-history-p05.html | new | 구현 전 계약 |
| docs/design/theme-map/themes/dune-posture-history-p05.html | new | 정적 시안 |
| docs/design/phone-design-map/actual/*/P05 | refresh | 영향 4profile 새 PNG/AX와 출처 |
| Shared/Resources/Localizable.xcstrings | narrow | 새 숫자 분수 표시의 manual catalog key만 필요 시 등록 |

## Implementation Steps

### Step 1: Plan/maps

기준 소스 SHA256 `e3ad80df6cff5c9bb22a153bded4daf90e95e4e9e5fc1006265343394b13558e`와 호출부·공용 DS를 확인하고 정적 맵을 먼저 연결한다. private 소스/리뷰 초안은 검토 자료이며 실행 완료 증거가 아니다.

### Step 2: Work

화면별 작은 커밋·원격 보존. P05 새 hero는 실제 최신 record를 사용하며 날짜·metrics count도 기존 Text를 combine하여 VoiceOver에 유지한다. P08 정적 MAX 시안도 실제 세로 배치 계약과 맞춘다.

### Step 3: Validate/Review/Ship

정확한 관련 UI·native PNG/AX를 순차 수집하고 독립 전문가 검토·solution·actual maps를 완료한 뒤 화면별 PR을 일반 merge한다. 실패 한도를 초기화하거나 통과한 관련 검사를 반복하지 않는다.

## Edge Cases

| Case | Handling |
|---|---|
| P05 latest 삭제·빈 기록·14일 reminder | isolated mock record 삭제/Cancel/확인만 UI 검증; 실제 사용자 데이터 아님 |
| P07 no joints / P08 missing image | 원래 경로 보존, 현재 seed로 미검증인 상태는 명시 |
| MAX·Duo 두 pane | 값 전체 프레임과 스크롤, active display+native PNG로 확인 |
| locale / numbers | 기존 문구 재사용; 새 보간은 실제 추출 키·타입을 대조하고 formatter 전후 검사 |

## Testing Strategy

- Unit: 계산·저장·서비스 변경이 없어 추가 unit은 면제. UI compile로 iOS View 타깃 확인, 같은 소스 별도 build-only 반복하지 않음.
- Integration: PostureVisualAuditTests의 P05/P07/P08 normal3 + 각 MAX3. 첫 iPhone6, iPad normal3, Duo closed6/open3의 정확한 selector만 표준 실행기로 실행한다. 한 번에 소유 기기1·SDK1, jobs2/indexOFF/parallelOFF, wall1200초.
- Native: en_US·기존 opt-in synthetic2records(73/86, delta+13·실제 joint 계산값), PNG/AX를 같은 실행에서 수집. Duo 각도 수치는 현재 CLI 미제공이므로 null, LCD/LCD-1 활성·rotation/native PNG 대조.
- Reuse: source/file/method/dependency hash와 원본 receipt 보존, 화면별 PR 분리 후 관련 동일성 판정. 전체 회귀/실물 추론/다른 locale는 통과 주장하지 않는다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| MAX card 높이/좁은 bar | medium | 읽기·조작 | 실제 프레임·새 PNG 확인 |
| 새 AX 그룹 label | medium | VoiceOver | 날짜·항목 수도 combine, 실제 hierarchy 검사 |
| hosted CI 환경 실패 | known B05 | unit 미시작 | 원본 보존·이번 diff 원인 여부 판정, 무관한 실행기 변경 금지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 로직과 값은 보존하며 새 runtime/native 검증 전에는 완료로 표시하지 않는다.
