---
tags: [swiftui, posture, wellness, accessibility, design-map]
date: 2026-11-05
category: plan
status: reviewed
---

# H07 자세 기록 상세 표현 강화

## 목적과 현재 근거

Wellness의 최근 자세 기록에서 H07은 `PostureRecordLookupView`를 거쳐 `PostureDetailView`로 간다. 자세 이력 P06도 같은 상세 뷰를 쓴다. 현재 화면에는 저장된 점수 원형 링, Front/Side 이미지, Assessment Details의 각도·상태·신뢰도, 교정 운동, 좌우 비교, 메모, PDF 공유, 삭제가 이미 있다. 기존 일반 iPhone H07 PNG에서는 큰 Front/Side 영역이 첫 화면 대부분을 차지하고 Assessment Details가 하단 탭바 뒤쪽부터 나타난다. 자세 평가가 비어 있다는 인상은 배치와 시각 밀도에서 온다. 이 PNG는 2026-10-12 캡처이며 새 구현 증거는 아니다.

조사·구현 기준은 H04 문서 PR #921의 실제 병합 HEAD `37c87944c4753fc08dce85b61e442c7a318c27b5`다. 기존 H07/P06 기기별 이미지와 해시는 작업 검증 기록에 보존하며 새 소스의 통과 근거로 쓰지 않는다. 앱 후보와 기존 MAX 캡처 두 줄의 보완은 이 기준에서 별도로 검토했다.

## 데이터·동작 계약

- `PostureAssessmentRecord`에는 실제 저장된 `overallScore`, front/side metric 배열, joint 배열, 선택적 image data, memo, date가 있다. `PostureMetricResult`의 type, value, unit, status, score, confidence를 사용한다. 새 점수·각도·의학적 문턱·사진을 계산하거나 만들지 않는다.
- Front/Side 사진이 있으면 원본 비율과 탭 확대·기존 `JointOverlayView`를 보존한다. 이미지가 없거나 디코딩할 수 없으면 compact placeholder를 유지하고 사진/관절 오버레이가 있다고 암시하지 않는다. 메트릭만 있거나 점수만 있는 과거 기록도 정상 표시한다.
- 시각적 초점은 **실제 측정 항목**으로 옮긴다. 기존 8종 metric의 아이콘·상태색·실제 값·단위·신뢰도 행을 점수 바로 아래에 배치하고, 저장된 front/side 배열의 각 항목을 기존 SF Symbol과 상태색을 사용하는 적응형 2열 타일로 표시한다. 각 타일은 기존 항목 이름·실제 값·단위·상태·신뢰도를 그대로 읽을 수 있어야 한다. 배열이 비면 Assessment Details 제목과 기존 현지화 문구 `Unable to measure`를 표시하고 지표는 만들지 않는다. status를 의료 진단으로 재해석하지 않는다.
- 점수 링은 저장된 점수와 크기를 그대로 유지한다. 평가 항목을 사진 앞에 두고 사진 없는 자리표시자만 120pt로 줄인다. MAX 글씨에서는 한 열과 전체 레이블 표시를 우선한다. Front/Side는 구분된 카드로 남기고 사진이 없을 때 거대한 사람 실루엣을 사용하지 않는다.
- PDF 생성/ShareLink, 삭제 확인과 dismiss, 교정 운동 추천, 사진 확대, 원본 관절·각도 오버레이, 좌우 비교 링크, 메모, 날짜·뒤로 가기, 읽기 전용 기록을 보존한다. 3D 근육 메뉴를 되살리지 않는다.

## Affected Files

| 파일 | 계획한 변경 |
| --- | --- |
| `DUNE/Presentation/Posture/PostureDetailView.swift` | 동일 뷰 안에서 기존 score, metrics, photos의 순서와 크기를 정리하고 저장된 metric 상태의 간결한 2D 시각 요약을 추가. 기존 액션·데이터 경로 유지. |
| `DUNE/Presentation/Shared/Extensions/PostureMetric+View.swift` | 신뢰도 badge에 기본값이 유지되는 전경 스타일 인자를 추가해 이 상세만 대비를 강화 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 H07 직접 진입, P06 이력·하단 스크롤, 좌우 비교 선택자는 그대로 둔다. 기존 MAX 접힘 점수 메서드의 각 자세 점수 캡처 뒤에 기존 reveal/captureScrollContent로 Assessment Details와 아래 타일 3뷰포트만 캡처한다. 새 메서드·fixture·assertion 문장은 없음. |
| `docs/design/layout-map/` H07 전용 맵·index/README | 기존 H07과 P06이 같은 상세 뷰를 공유함을 명시하고 점수→평가→사진→추가 행동의 배치·누락 상태를 설명. |
| `docs/design/theme-map/` H07 보존 시안·manifest/README/index | DUNE의 기존 body 테마색·SF Symbol·상태색으로 정적 표현을 보존. 시안 수치/기호와 실제 캡처를 분리. |
| `docs/design/phone-design-map/actual/`의 H07·P06 및 갤러리 | 변경 후 실제 기기별 PNG/AX를 해당 두 ID에만 갱신하고 기존 이미지 출처를 보존. |

## Implementation Steps

1. H06 실제 병합 HEAD에서 `PostureDetailView`와 H07/P06 현재 맵·테스트 파일을 다시 바인딩한다. 기존 일반 iPhone·Duo 접힘/펼침·iPad H07 사진과 첫 메트릭 가시성을 비교한다. 공유 상세 뷰의 P06도 영향 범위에 포함한다.
2. 한 상세 뷰에서 `Assessment Details`를 사진 앞에 둔다. 저장된 `frontMetrics + sideMetrics`만 기존 `PostureMetricType.iconName`/`PostureStatus.color`로 2열 타일에 표시한다. MAX 글씨는 한 열이다. 배열이 비면 기존 카탈로그 `Unable to measure`를 표시하고 값을 만들어 내지 않는다. 실제 값·단위·신뢰도 표현은 기존 함수를 재사용한다. 네 상태색 `.green/.yellow/.red/.gray`의 밝은 화면 전경만 캐시된 `mix(with: .black, by: 0.45)`로 표시하고 어두운 화면 전경과 상태색 9% 타일 배경은 그대로 둔다.
3. Front/Side 이미지 카드는 `Data`가 있을 때 원본 표시·확대·관절 오버레이를 유지한다. 없는 사진의 자리표시자는 작은 정보 카드로 구성하되 Front/Side 구분과 부분 평가 상태를 유지한다. 합성 fixture의 `figure.stand` PNG는 사진 존재 경로만 검증하며 촬영 품질이나 실제 관절 시각화 증거가 아니다.
4. 기존 `PostureVisualAuditTests/testWellnessRecentPostureRecordOpensDetail`로 H07 직접 진입을 일반 iPhone·iPad·Duo 접힘·펼침에서 확인한다. `testPostureHistoryAndDetail`은 P06 공유 화면의 전체 스크롤을 동일한 네 프로필에서 확인한다. 기존 `testPostureDetailScoreAcrossFoldStatesAtMaximumTextSize`는 소유한 같은 Duo에서 closed→partiallyOpen→openFlat 세 자세의 실제 readback 및 MAX 점수를 확인한다. 좌우 비교의 원래 경로는 기존 `testPostureSymmetry`로 대표 접힘 프로필에서 확인한다. 합계는 H07 4 + P06 4 + Duo MAX 1 + 좌우 비교 1 = 기존 선택자 10건, 순차 실행 5회(일반 접힘과 MAX 별도)다. 동일 Duo를 자세별로 소유하고 기기는 한 번에 하나만 사용한다. MAX 메서드에만 기존 helper 호출 두 줄을 더하고 assertion 문장은 바꾸지 않는다. 실제 PNG/AX에서 첫 평가 항목과 하단 행동을 별도 검토한다. 앱/테스트·기기 실행은 표준 점유·deadline을 따른다.
5. 실제 PNG/AX에서 score, 첫 메트릭, 상태색과 텍스트, Front/Side, 메모·교정 운동·좌우 비교·PDF/공유·삭제 동작의 도달성을 검토한다. 이미지 없음, 한쪽만 있음, 메트릭 없음은 실제 fixture/기록으로 증거가 있는 경우만 통과로 쓴다. 검증한 기기/언어/외관만 게시하고 H07과 공유 P06 맵을 함께 갱신한다.

## 위험·대안·검증 경계

- **사진 없는 기록:** 기존 두 이미지 자리표시자를 단순히 숨기면 Front/Side와 부분 평가 의미가 사라진다. 작은 카드와 명확한 상태를 유지한다. summary-only 기록에 metric 행이나 joint diagram을 만들어 내지 않는다.
- **합성 fixture:** `TestDataSeeder.seedVisualPostureFixtures`는 시스템 `figure.stand` 그림을 `frontImageData`/`sideImageData`에 저장하고 joint의 normalized image 좌표를 넣지 않는다. 기존 H07 PNG의 거대한 검은 사람 모양은 그 fixture의 결과이며 카메라 영상/관절 오버레이 품질의 증거가 아니다. 새 캡처도 동일 한계를 명시한다.
- **시각 대안:** 새로운 3D 몸 모델이나 관절 좌표 추정 대신 2D metric 아이콘/상태 요약을 선택한다. 저장된 필드만 사용하고 기존 항목 이름·값·상태·신뢰도 표현을 재사용하기 때문이다. 새 타일의 VoiceOver 순서와 중복 여부는 실제 AX에서 확인한다.
- **데이터·플랫폼:** 쿼리, SwiftData 모델, score 계산, Vision/ML, HealthKit, Watch UI, 카탈로그의 광범위 수정은 범위 밖이다. 새 문구가 실제로 필요해질 때만 en/ko/ja 문자열과 formatter를 좁게 갱신한다. iOS 화면 소스 변경 후 영향 타깃은 프로젝트 설정으로 다시 확인한다.
- **검증 상태:** 비공개 소스 패치와 정적 맵 초안은 만들었고 ROOT에는 적용하지 않았다. MAX 기존 메서드의 캡처 전용 테스트 패치만 준비했고 네이티브 실행·현행 기기 캡처는 아직 없다. Apple/SwiftUI 정적 리뷰의 밝은 화면 상태 전경 대비 P2를 소스에서 두 군데만 보정했다. 0.45 혼합은 예상되는 가독성 개선이며 실제 대비 수치가 아니다. 네 상태의 아이콘·상태 글자와 평가 타일 폭·MAX 전체 텍스트는 네이티브 PNG에서 측정/확인 전까지 통과로 기록하지 않는다. MAX는 접힘 세 자세 각각 기존 점수 확인 뒤 Assessment Details를 드러내고 상단/하단 스크롤 화면을 남긴다. 이 캡처만으로 모든 8항목의 전체 가시성을 추정하지 않는다. 기존 H07/P06 이미지는 이전 소스의 역사 증거로만 사용한다. H07과 P06 각 4프로필의 새 PNG/AX가 확인되지 않으면 해당 맵 ID를 최신 캡처로 표시하지 않는다.

## 실제 닫힘 캡처에서 확인한 보완

최대 글씨의 실제 0° 캡처에서 고정 폭보다 커진 SF Symbol이 지표 제목으로 들어갔고, 밝은 카드의 신뢰도 숫자 대비가 약 2.76:1이었다. 기호의 실제 그림과 예약 영역을 함께 확대하되 상한을 두고, 이 상세 화면의 신뢰도에는 기본 전경을 명시한다. 공유 badge의 기본 스타일은 유지해 다른 소비자를 바꾸지 않는다. 기존 MAX 검사의 아래 캡처를 3회에서 5회로 늘려 여덟 항목을 모두 확인한다. 점수·측정값·신뢰도 계산·삭제·PDF·사진 기능은 바꾸지 않는다.

추가 영향 파일은 `DUNE/Presentation/Shared/Extensions/PostureMetric+View.swift`이며 기본 인자가 유지되는 `PostureResultView` 소비자도 같은 앱 타깃 컴파일로 확인한다. 기존 실패와 두 번의 host 중단, 실행 전 준비/공간 부족은 통과로 재분류하지 않는다. 수정된 앱의 새 네이티브 캡처와 실제 대비 재검증 전에는 완료가 아니다.
