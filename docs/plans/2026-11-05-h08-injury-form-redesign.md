---
tags: [h08, injury, swiftui, form, accessibility]
topic: h08-injury-form-redesign
date: 2026-11-05
status: approved
confidence: high
category: plan
related_solutions:
  - architecture/2026-02-23-injury-ui-bilingual-radio-list-patterns
  - architecture/2026-02-20-injury-tracking-review-fixes
  - general/2026-11-05-posture-record-detail-accessible-metric-cards
related_brainstorms:
  - 2026-02-23-injury-ui-improvements
---

# H08 부상 기록 입력·수정 표현 개선

## Context

실제 병합 기준은 PR #923의 `ca9a62460f541c5cabf7034491751beae6afb885`다. 현재 한 `InjuryFormSheet`를 Wellness의 Add/Edit와 부상 이력·상세의 Add/Edit 네 caller가 공유한다. 기존 네 Form 섹션은 제목만 있고 심각도 이름은 밝은 sand 전경을 사용한다. 같은 형태의 정보에 원래 아이콘을 배치하고 읽기 쉬운 전경을 쓰라는 전체 개편 요청을 이 입력 화면에도 적용한다.

현재 Form은 private 소스 후보의 기준과 바이트가 동일하며 caller·ViewModel·저장/초기화/닫기·날짜 검증·현지화 키를 조사했다. 과거 부상 라디오 리스트·중복 저장 방지 해결책과 이번 H07의 최대 글씨/대비 교정을 참조한다. 과거 H08 PNG 네 장은 정체성 참고이며 현재 소스의 before나 새 통과 증거가 아니다.

## Requirements

- `Body Part`, `Severity`, `Duration`, `Notes`를 기존 SF Symbol을 쓰는 시스템 `Label` 헤더로 구성한다. Location·조건부 Side·Minor/Moderate/Severe·Start Date·Recovered/End Date·Memo와 toolbar Cancel/Save는 그대로 둔다.
- 밝은 심각도 기호·체크 전경은 원래 색을 진하게 섞고 이름은 기본 전경으로 표시한다. 어두운 상태색과 기존 설명 문구·선택 의미는 유지한다. 새로운 의료 등급·문구·계산을 추가하지 않는다.
- 기록 생성·수정, 날짜 범위, `isSaving`, validationError, 메모와 접근성 ID·선택 상태·haptic·저장/취소 경로를 유지한다.
- iOS Presentation 화면만 변경한다. Watch·Vision·Domain/모델·CloudKit·HealthKit와 H09/H10의 디자인은 범위 밖이다.

## Approach

시스템 Form을 유지하고 네 섹션 헤더와 작은 전경만 다듬는다. 별도 히어로·그림·커스텀 Picker나 새 상태 모델은 필요하지 않다. 측면 부위에서만 Side가 보이는 기존 조건을 유지한다. 기본 `.knee`는 측면이므로 MAX 검사에서는 Side도 명시적으로 확인한다.

기존 실제 맵은 H08 한 ID만 보유하며 네 프로필의 대표는 Add 초기 화면이다. Recovered/End Date와 Edit는 사례별 보조 상태로 보존한다. 브라우저 시안의 상태 이름을 H08-active/H08-edit라는 새 실제 카탈로그 ID로 만들지 않는다.

## Affected Files

| 파일 | 변경 |
| --- | --- |
| `DUNE/Presentation/Injury/InjuryFormSheet.swift` | 네 섹션의 Label 헤더, 밝은 심각도 기호/체크와 이름 전경 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 Add/Edit에 상태 캡처 세 개, 별도 MAX 한 사례와 실제 viewport 기반 유한 reveal helper |
| `docs/design/layout-map/injury-record-form-h08.html`, index/README | 기존 입력·조건부 상태와 큰 글씨/키보드 계약 |
| `docs/design/theme-map/themes/dune-injury-record-form-h08.html`, manifest/README/index | 보존 시안과 실제 캡처 구분 |
| `docs/design/phone-design-map/actual/` H08 네 프로필과 보조 갤러리 | 현재 Add 대표와 Recovered/Edit/MAX의 새 실제 PNG/AX |
| 본 계획·`docs/solutions/` | 최종 결과와 확인하지 않은 상태 기록 |

## Implementation Steps

1. 병합 기준·원래 Form과 네 과거 H08 이미지의 출처를 보존한다. 전용 배치·테마 맵을 먼저 추가한다. 같은 layout index의 이미 완료된 H07 링크에 남은 대기 표기도 실제 갤러리 상태와 맞춘다. 앱 변경은 H08에 한정한다.
2. 검토한 한 파일 source 후보를 적용한다. 원래 네 문자열 키를 재사용하며 새 번역이나 데이터 모델을 만들지 않는다. source/caller/private 리뷰가 유효한지 확인한다.
3. 기존 두 Add/Edit 검사의 assertion을 보존하고 Add 초기·Recovered End Date·Edit 초기의 명시적인 checkpoint를 추가한다. MAX helper는 실제 Form/window/nav/keyboard 경계를 쓰며 임의 상하 여백으로 보이는 필드를 거부하지 않는다.
4. 일반 iPhone 2, iPad 2, Duo 접힘 3(Add/Edit/MAX), 펼침 2(Add/Edit)의 **총 9사례·순차 4런**을 표준 UI 실행기로 실행한다. App/UI 타깃의 컴파일을 포함한 첫 필요한 실행을 빌드 증거로 사용하며 별도 동일 빌드를 반복하지 않는다. 한 번에 소유 기기 한 대, 기존 UI 캐시·잠금·deadline을 사용하고 완료한 기기만 정리한다.
5. 새 Add 대표 및 보조 Recovered/Edit/MAX의 실제 PNG/AX를 각 case·UID·날짜·Duo 0°/180°/활성 화면과 묶어 독립 검토한다. 실제 카탈로그 H08만 갱신하고 다른 화면/보드 타일을 보존한다. 시안의 대기 표기는 실제 검증 후 현재 상태와 갤러리에 맞춘다. source/native/최종 리뷰와 문서화를 마친 뒤 독립 PR로 일반 병합한다.

## Testing Strategy

- 네 프로필 각각 `DUNEUITests/WellnessRegressionTests/testInjuryAddFlowShowsRecoveredFieldsAndCreatesHistoryRow`, `DUNEUITests/WellnessRegressionTests/testInjuryHistoryRowOpensDetailAndEditForm`를 선택한다. Add→Recovered/End Date→Save→이력 행 생성과 History→Detail→Edit→Save→상세 복귀의 원래 assertion을 유지한다.
- Duo 접힘만 `DUNEUITests/WellnessRegressionTests/testInjuryFormAtMaximumAccessibilityTextSize`를 추가한다. AXXXL에서 Location/Side, 세 심각도, Start Date, Recovered/End Date, Memo의 전체 프레임과 도달성을 실제 Form 스크롤로 확인한다. 실제 소프트웨어 키보드 PNG/AX, dismiss 후 완전히 보이는 Save/Cancel, Save 뒤 폼 닫힘과 이력 행을 확인한다.
- `DUNEUITests-DuoAudit`과 `DUNEUITests-DesignCapture`의 포함/환경을 확인했으며 정확한 셀렉터만 고른다. 실행 전 소유 기기의 하드웨어 키보드 연결을 해제하고 실제 소프트웨어 키보드가 나오는지 확인한다.
- 이번 변경에는 입력 검증/계산/모델 로직이 없으므로 새 unit이나 full/smoke 회귀를 추가하지 않는다. 실제 저장·수정 소비자에 대한 위 핵심 UI 검사가 검증 범위다. 문자열 카탈로그 check/manual과 테마 맵·diff 검사는 유지한다.
- 수정이 필요하면 원인·기존 실패·횟수를 보존하고 영향을 받은 정확한 선택자만 다시 확인한다. 테스트의 MAX 전용 helper만 바뀌고 App·기존 Add/Edit 소스/환경이 같으면 그 두 흐름의 이미 유효한 증거를 반복하지 않는다.

## Edge Cases and Risks

| 경우 | 처리·확인 |
| --- | --- |
| 비측면 부위 | 기존 Side 숨김·저장 의미 유지. fixture의 실제 선택과 구분 |
| Recovered 해제/활성화 | 원래 endDate nil/초기값과 DatePicker 범위 유지 |
| 저장 중·잘못된 날짜 | 기존 VM·Save 비활성화·오류/haptic 코드 유지 |
| MAX/긴 문구 | 시스템 Form 스크롤·전체 프레임·기호/제목 간격을 새 native에서 검토 |
| Memo·키보드 | 실제 키보드 AX와 PNG를 확인하고 dismiss 후 toolbar 전체를 확인 |
| 기존 이미지 | source가 맞지 않는 before 비교나 새 구현 증거로 재사용하지 않음 |

색·기호의 실제 대비, MAX 줄바꿈, 키보드·네 기기의 새 캡처는 아직 미검증이다. English·Light가 기본 증거이며 다른 언어/외관과 실제 의료 결과를 이 실행의 통과로 암시하지 않는다. 과거 unrelated Watch CI는 런타임 누락의 실행 전 실패이며 H08 iOS 범위를 Watch 전체 검사로 확대하지 않는다.
