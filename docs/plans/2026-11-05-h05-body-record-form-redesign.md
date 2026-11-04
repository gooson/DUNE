---
tags: [swiftui, body-composition, native-form, accessibility, native-evidence]
date: 2026-11-05
category: plan
status: implemented
---

# H05 신체 기록 입력·수정

## 목적과 범위

H04의 실제 머지 `103ecfd15d8cff8263e8c351e46d7f510f2cef2f`를 기준으로, 공유 `BodyCompositionFormSheet`의 체중·체지방·근육량 헤더에 기존 지표 아이콘을 넣는다. Wellness의 추가·수정과 Body History의 수정이 같은 Form을 사용한다. H06 이력 화면의 개편은 별도 작업이다.

기존 NavigationStack/Form, 미래 날짜 제한, 선택 입력과 단위, 메모, 숫자 키보드의 Clear Input/Done, 유효성 오류, 고정 Cancel/Save, 저장 활성 조건, 성공 피드백과 create/update·HealthKit 소유권을 유지한다. 모델·쿼리·문자열 카탈로그·Watch·Vision 동작은 변경하지 않는다.

## Affected Files

| 파일 | 변경과 확인 범위 |
| --- | --- |
| `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift` | 세 헤더를 기존 category 아이콘과 중립적인 글자로 표시하는 작은 Label helper로 변경 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 추가·수정 흐름에 캡처 네 곳과 추가 흐름의 기존 키보드 Done 동작 한 곳 추가; 새 검사·assertion 없음 |
| `docs/design/layout-map/body-record-form-h05.html` 및 인덱스·README | 네이티브 Form의 배치 계약 등록 |
| `docs/design/theme-map/themes/dune-body-record-form-h05.html` 및 manifest·인덱스·README | 정적 표현 시안과 실제 검증 상태 연결 |
| `docs/design/phone-design-map/actual/`의 H05 이미지·행·보드 및 포털 | 영향받는 네 기기·자세의 새 실제 캡처 등록; 다른 화면 유지 |
| `docs/design/full-redesign-map/review/h05-body-record-native-2026-11-05/` | 실제 PNG/AX 18쌍과 역사적 참고 이미지·출처·한계 보존 |
| `docs/solutions/testing/2026-11-05-native-form-metric-headers-and-keyboard-evidence.md` | 입력 환경·저장 성공과 개별 탭 성공을 구별하는 해결 기록 |

## Implementation Steps

1. 앱 변경 전에 H05 전용 레이아웃·테마 맵 일곱 파일을 등록한다. 시안의 값·날짜·기호는 설명용으로 표시한다.
2. 세 기존 섹션 헤더만 `LocalizedStringKey`와 category를 받는 helper로 바꾼다. 글자는 `DS.Color.textSecondary`, 장식 아이콘만 기존 category 색을 쓰고 AX에서는 숨긴다. 기존 Weight `scalemass.fill`, Body Fat `percent`, Muscle Mass `figure.strengthtraining.traditional`을 유지한다.
3. 기존 추가·수정 검사를 재사용한다. iPad → iPhone → Duo 접힘의 기본 추가·MAX 수정 → 같은 Duo 펼침의 기본 추가 순서로 다섯 사례를 실행한다. 소유 기기는 한 번에 한 대만 사용하며 실제 화면 키보드를 PNG·AX로 확인한다.
4. 검토한 새 PNG/AX와 동일 소스·UID·자세 증거로 네 H05 실제 이미지를 갱신한다. H05만 바뀌는 게시 결과를 별도 검토하고 다른 화면의 카드·보드 픽셀을 보존한다.
5. 문서·출처와 검증 한계를 확정하고 화면별 PR을 생성·검토·머지한다. 모든 기기는 증거 보존 후 삭제하며 곧 재사용할 빌드 캐시는 유지한다.

## 핵심 검증과 위험

기존 `testBodyAddFlowSavesRecord`를 네 기기·자세에서 실행하고, `testBodyHistoryEditAndSaveAtMaximumAccessibilityTextSize`를 접힌 Duo에서 한 번 실행한다. 헤더 줄바꿈·원래 단위·하단 필드와 Save 접근·저장 후 목록 반영을 확인한다. 같은 UI 실행의 컴파일 증거를 재사용하며 별도 unit/full/Watch/Vision 검사를 추가하지 않는다.

입력 전에 전용 기기의 하드웨어 키보드 연결을 해제한다. `typeText` 성공만으로 화면 키보드 표시를 추정하지 않는다. 오래된 H05 PNG 네 장은 소스·UID·자세·AX가 연결되지 않은 역사적 정체성 참고이며 새 캡처로 사용하지 않는다. 실제로 생성되지 않은 오류 상태나 실행하지 않은 언어·VoiceOver·외관·MAX 조합은 검증 완료로 표시하지 않는다. 기존 완료 TODO `070-done-p2-e2e-dune-body-composition-form-sheet.md`의 입력·AX 계약을 보존한다.

## 실제 결과와 게시

앱 변경 소스는 `42a1b774`, 기존 Done 동작 한 줄을 추가한 최종 검사 소스는 `d8fca250`이다. 앱 SHA-256은 `735641ce268afe852e8564a7e2ddf1b16ef3d4e872c13941544cbd14e2c51c5d`, 최종 검사 SHA-256은 `4d4f499d6ec070e4ed8187d594d6f72112272c5725fa75c1c5cf0b8828d9e7ed`다.

다섯 핵심 사례가 통과했고 실제 PNG/AX 18쌍의 독립 검토도 통과했다. 첫 iPad 실패 한 건은 따로 유지하므로 전체 이력은 6회 실행·5회 통과·1회 실패다. 첫 Save 탭은 hit point {-1,-1}이었고, 이후 iPad Done 탭도 닫힘을 입증하지 못했지만 Save와 목록 반영은 성공했다. iPhone과 펼친 Duo에서는 Done 이후 키보드가 사라진 캡처가 있다. 실제 도구 버전은 Xcode 27.2 (27B52)이며, 원래 pipeline context의 27.1 표기는 원본을 고치지 않고 부가 정정으로 보존한다.

기본 글씨 Add는 네 기기·자세, MAX Edit는 접힘에서 확인했다. 어두운 외관·모든 언어·VoiceOver·실제 HealthKit·MAX Add·펼침 MAX는 실행하지 않았다. H05 전용 게시 산출물 62개를 독립 검토했고 각 tier의 카드 ID 111개와 다른 화면의 보드 픽셀을 유지했다. 문서 형식 보완은 별도 문서 변경으로 기록하며 앱과 PNG/AX는 바꾸지 않는다.

[실제 화면과 검증 한계](../design/full-redesign-map/review/h05-body-record-native-2026-11-05/index.html) · [해결 기록](../solutions/testing/2026-11-05-native-form-metric-headers-and-keyboard-evidence.md). 모든 전용 기기 세 대는 증거 보존 후 삭제했다. 구현·검증은 완료했으며 PR의 실제 머지 결과는 별도로 확인한다.
