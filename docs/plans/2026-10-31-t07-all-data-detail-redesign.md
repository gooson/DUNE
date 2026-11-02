---
topic: T07 all-data native detail redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-03-04-all-data-sleep-awake-alignment.md
  - docs/solutions/healthkit/2026-03-11-sleep-all-data-time-anchor.md
---

# 구현 계획: T07 전체 데이터

## 배경

승인된 상세 화면 전환 계획에 따라 AllDataView의 16개 카테고리를 모두 다루는 네이티브 화면 단위 PR이 필요하다. 실제 조회와 모든 네이티브 상태를 보존하면서 카테고리 식별성과 날짜·시간·값의 위계를 개선한다. 사용자는 run을 통한 구현, 범위에 맞춘 검증, 독립 리뷰와 화면별 PR·머지를 승인했다. 계획 수립 당시 이 브랜치의 기준은 T06 후보 a367ae22다. T06 화면이 반영될 때까지 PR의 의존 관계를 유지하고, 이후 main으로 대상을 변경한다. main, 원래 프로토타입 체크아웃과 .claude 설정은 수정하지 않는다.

## 요구사항

### 기능

- HealthMetric+View의 16개 카테고리 아이콘과 이름, 영어로 고정된 카테고리 내비게이션 제목, 시스템 뒤로 가기, all-data-screen-<rawValue>와 빈 상태의 AX 식별자를 보존한다.
- 실제 날짜 섹션, 각 데이터 포인트의 시간과 측정값 형식을 모두 보존한다. 수면은 보고 날짜로 묶고, 가장 이른 비각성 단계의 displayDate를 표시한다. 각성 제외, 백분율·온도·소수점 정밀도를 유지한다.
- 조회 기간 제한 안내와 ready/empty/limited-empty/loading/next-page 상태, 페이지 조회를 보존한다. 페이지 크기는 달력 기준 30일이며, 30개 기록이나 전체 이력의 상한을 뜻하지 않는다.
- 근거 없는 날짜 필터, 평균, 백분위수, 전체 이력 개수, 마지막 갱신 시각이나 가상의 출처 배지를 추가하지 않는다. 프로토타입의 전환 스위치는 검토용 픽스처이며 네이티브 조작 요소가 아니다.
- 기존 시드에 없는 호흡 장애 카테고리의 명시적 테스트 픽스처 분기를 제외하고 AllDataViewModel, 취소·요청 ID, latestDate를 통한 빈 기간 건너뛰기와 프로덕션 서비스를 변경하지 않는다.

### 비기능

기존 DS 간격, 카테고리 SF Symbol과 테마 색을 사용한다. 지표 상세 화면과 일관된 작고 불투명한 식별 헤더, 화면 폭에 맞춰 읽기 쉬운 행, 고정폭 숫자와 실제 Dynamic Type을 적용한다. 시스템 List의 지연 로딩·페이지 조회와 정적인 장식을 유지한다. 대상은 iPhone, iPad, Duo 접힘·펼침이다. 소유한 시뮬레이터는 한 번에 하나만 실행하며, 다른 네이티브 UI 실행 중에는 빌드하지 않는다. 이 화면 작업에서 .claude와 검증 실행기를 변경하지 않는다.

## 조사

독립 planner /root/t07_plan이 소스, 소비자, 프로토타입 manifest, 기존 해결책, 계획·할 일과 네이티브 비교 쌍을 조사했다. 상세 보고서는 Git 추적 대상에서 제외된 L03 .codex-checks/detail-rollout/t07-plan-research.md에 보존했다. 기존 --seed-mock은 15개 카테고리 서비스에서 SimulatorAdvancedMockDataProvider를 사용한다. BreathingDisturbanceQueryService는 이 공급자를 거치지 않는다. ContentView에는 이미 DEBUG T06 직접 진입 패턴이 있다. 기존 조회 기간 제한·빈 공급자 플래그로 안내와 빈 상태를 확인할 수 있다. LatestDate의 빈 기간 건너뛰기는 기존 VM 단위 테스트의 별도 계약으로 유지한다. 현재 픽스처를 전체 이력이라고 설명하지 않는다.

복구한 승인 프로토타입의 리비전 786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894는 시안 근거이며 네이티브 데이터가 아니다. 정확한 기존 PNG 비교 쌍은 HRV의 phone/Duo 접힘과 수면의 iPad/Duo 펼침에만 존재한다. 새 기준 캡처에는 원래 AllDataView 레이아웃과 변경 후와 동일하게 명시된 결정적 목 데이터를 사용한다. 다른 과거 카테고리 이미지를 정확히 대응하는 기준 이미지로 표시하지 않는다.

## 접근 방법

먼저 AllDataView의 프로덕션 레이아웃을 바이트 단위로 유지한 채 범위가 한정된 명시적 UI 경로·픽스처 계측과 선택한 테스트를 추가한다. 원래 16개 레이아웃을 고정하고 캡처한다. T07 레이아웃·테마 맵을 기록한 뒤 View의 식별 헤더와 행만 구현한다. 기존 포맷과 데이터 경로를 재사용한다. 쿼리 목 분기는 DEBUG 시뮬레이터, --uitesting과 명시적 T07 의도를 모두 요구하며 실제 기기·프로덕션의 기본 경로를 유지한다. 기존 공급자의 referenceDate를 기준으로 누락 카테고리의 명시적 테스트 샘플(1.2 disturbances/hr)을 만든다. 이는 픽스처이며 실시간 측정값이나 기존 데이터셋의 측정값이 아니다. 기존 15개 시드 카테고리와 범위 필터를 기준으로 삼는다. 카테고리 픽스처를 올바르게 생성할 수 없으면 준비된 행을 만들어 내지 말고 해당 주장을 중단한 뒤 누락 상태를 정확히 기록한다.

### 검토한 대안

| 접근 | 장점 | 비용 | 결정 |
| --- | --- | --- | --- |
| List를 자체 조회·그리드로 교체 | 시각적 자유도가 높음 | 지연 페이지 조회, 이력 의미와 AX가 달라질 위험 | 제외 |
| 프로덕션에 프로토타입 예시 행 사용 | 빠른 렌더링 | 실제 건강 데이터를 대체함 | 제외 |
| View 레이아웃만 변경하고 실제 UI용 명시적 픽스처 사용 | 변경 범위가 작고 정확한 반복 비교 가능 | 누락 카테고리의 목 분기와 네이티브 캡처 필요 | 선택 |

## 영향받는 파일

| 파일 | 변경 | 이유 |
| --- | --- | --- |
| DUNE/Presentation/Shared/Detail/AllDataView.swift | 기준 캡처 후 View 레이아웃만 변경 | 카테고리 식별, 읽기 쉬운 시간·값 행, 실제 상태 보존 |
| DUNE/App/ContentView.swift | DEBUG 경로 계측만 추가 | 명시적 T07 의도로 기존 AllDataDestination 사용 |
| DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift | 필요한 경우에만 엄격한 DEBUG 테스트 목 분기 추가 | 16번째 카테고리의 기존 공급자 시드 보완, 실시간 조회 유지 |
| DUNEUITests/Full/AllDataDetailRedesignTests.swift | 범위를 좁힌 UI 계약 | 16개 식별자, 실제 시드 행 포맷, 수면 시작, 빈 상태·제한 상태와 AX |
| docs/design/layout-map/all-data-detail-t07.html 및 인덱스 | 구현 전 계약 | 화면 위계와 모든 데이터 상태 |
| docs/design/theme-map/themes/dune-all-data-detail-t07.html, manifest/README/index | 디자인 방향 보존 | 식별 헤더와 네이티브 List 표현, 가상 데이터 주장 방지 |
| Shared/Resources/Localizable.xcstrings | 필요한 경우에만 변경 | 기존 카테고리·History 문자열 우선 사용, 새 문자열은 en/ko/ja/manual 형식 적용 |
| 실제 디자인맵 인덱스·이미지와 리뷰 갤러리 | 레이아웃 변경 후 네 가지 기기 구분별 새 캡처 | 원래 기준 화면, 새 네이티브 UI와 시안을 구분 |

## 구현 단계

### 1단계: 결정적 계측으로 원래 레이아웃 고정

관련 코드, 디자인, UI·테스트와 건강 데이터 규칙을 읽는다. 명시적 DEBUG 경로와 누락된 호흡 목만 추가하고 실제 범위 필터를 적용한다. 현재 시드 데이터셋을 재사용한다. --uitesting/--seed-mock/--ui-t07-all-data 플래그를 명시적으로 사용하는 한정된 16개 카테고리 테스트를 작성한다. 프로덕션 조회와 AllDataView 소스 해시를 보존한다. 커밋 전 독립적인 테스트·소스 리뷰를 수행한다. 부모 에이전트가 표준 App/UI 컴파일을 실행하고 단일 검증 phone에서 변경하지 않은 원래 레이아웃을 캡처한다. 원본 xcresult/AX/PNG/logs 전체와 정확한 소스 리비전을 보존한다.

### 2단계: View 코드보다 먼저 디자인 계약 갱신

공유 헤더 토큰, 16개 아이콘, 실제 섹션 날짜·시간·값, 제한·빈 상태·로딩과 Dynamic Type 동작을 포함한 T07 레이아웃·테마 방향을 기록한다. 인덱스를 연결하고 테마 맵을 생성·검사한다. 구현 전에 이 계획을 읽는다.

### 3단계: View 변경을 좁게 구현

원래 카테고리 아이콘·이름·테마를 작고 정적인 헤더에 사용한다. 네이티브 지연 List, 안내, 섹션 묶음, 스피너 task와 AX 루트를 유지한다. 가능한 한 formattedValue 메서드와 displayDate 선택을 바이트 단위로 보존한다. 모든 행에 실제 viewModel 포인트를 표시하며 요약을 만들어 내지 않는다. 좁은 화면과 접근성 레이아웃은 읽기 쉬운 한 열로 구성하고 불필요한 기간 문구 반복을 피한다. 다른 화면 소스는 수정하지 않는다.

### 4단계: 범위에 맞춘 검증과 수정

변경 전후 동일한 16개 카테고리 픽스처 반복 검사, 별도의 수면 보고 날짜·표시 시간 단언, 제한된 준비·빈 상태와 어두운 모드의 최대 AX 크기에서 접근 가능 여부를 확인한다. 소스 일치 범위를 확인할 수 있으면 변경하지 않은 기존 페이지 조회·수면 VM 테스트 증거를 재사용한다. 그렇지 않으면 정확히 관련된 AllDataViewModelTests를 실행한다. 적용되는 T06·Wellness의 실제 진입 경로 selector를 유지하고 요청하지 않은 전체 회귀는 실행하지 않는다. 모든 실패와 원인에 따른 재시도 예산을 기록하며 같은 원인은 한 번만 재시도한다. 빌드·unit·UI·캡처는 루트별로 직렬 실행하고, 소유 기기 하나와 고정된 제한 시간을 사용한다.

### 5단계: 리뷰, 실제 맵, Compound와 화면 PR

정식 모델 정책에 따라 적용되는 Security, Data Integrity, Architecture, Simplicity, Performance와 SwiftUI/Apple UX/app-quality/pr 리뷰 역할을 독립적으로 실행한다. phone/iPad/Duo 접힘·펼침의 새 네이티브 캡처에서 같은 카테고리의 정확한 대응, 아이콘 일치, 페이지 조회·안내와 텍스트 잘림을 검토한다. 발견사항을 해결하고 변경 범위만 다시 검사한다. 실제 디자인맵을 동기화하고 시안은 별도로 보존한다. 구체적인 학습 내용을 문서화하고 최종 diff·검증·소스 출처를 확인한다. T06에 의존하는 별도 T07 PR을 만들고 게이트 통과 후에만 머지하며 소유한 리소스만 정리한다.

## 경계 조건

| 상황 | 필요한 처리 |
| --- | --- |
| 빈 상태 + 조회 기간 제한 | 동일한 제한 안내 문구와 안내 요소 유지, 가짜 0 값 행 금지 |
| 전날 저녁에 시작한 수면 | 보고 날짜로 묶고 행 시간은 displayDate에서 가져오며 각성 제외 |
| 기록 없는 기간 | latestDate의 빈 기간 건너뛰기와 hasMoreData 의미 유지 |
| 지금까지 불러온 데이터 | 개수를 전체 이력이라고 표시하지 않음 |
| 좁은 Duo / 최대 글씨 | 고정 너비에 의한 잘림 없이 전체 값·단위와 읽기 쉬운 위계 유지 |
| View 재진입 / 취소 | 기존 VM 요청 ID와 task 유지 |
| 16번째 픽스처 | 명시적 목만 사용하고 기존 데이터에 범위 필터 적용, 실제 HealthKit 샘플이라고 단정하지 않음 |

## 테스트 전략

실제 앱에서 의미 있는 범위의 네이티브 테스트를 수행하고 변경 전후 픽스처를 일치시킨다. 기존 AllDataViewModelTests는 페이지 조회, 요청 취소, 수면 시간 기준점과 지속 시간을 다룬다. 프로덕션 VM 로직은 변경하지 않으므로 구현을 그대로 반복하는 중복 단위 테스트는 피한다. 정확한 기존 경로 테스트는 MetricDetailRedesignTests/testHRVRealWellnessEntryAndAllData, LimitedHealthHistoryUITests/testAllDataExplainsLimitedHistory와 TodaySettingsRegressionTests/testSleepMetricPushesDetailBackAndReopensAllData다. 소스에 존재하는지 확인한 뒤 영향받는 selector만 실행한다. 최종 실제 디자인맵에는 네 가지 하드웨어 구분의 실제 화면이 필요하며 Watch는 제외한다. UI 수집기의 성공은 시각적 품질 통과를 뜻하지 않는다.

## 위험과 대응

| 위험 | 대응 |
| --- | --- |
| 헤더가 지연 페이지 조회의 가시성을 바꿈 | 네이티브 List/스피너 의미와 범위를 한정한 실제 상태 테스트 유지 |
| 날짜·시간 혼동 | point.date와 point.displayDate 계약 및 수면 픽스처 테스트 보존 |
| 변경 전 PNG의 카테고리가 잘못 대응됨 | 원래 레이아웃의 16개 카테고리를 새로 캡처하고 이미지별 출처 명시 |
| 픽스처가 실제 경로에 유입됨 | DEBUG + simulator + --uitesting + 명시적 T07 조건, 프로덕션 기본 경로 유지 |
| 부모 T06이 아직 머지되지 않음 | T06 반영까지 명시적 스택 의존 관계 유지, main 통합 후 PR 대상 변경 |

## 확신도 평가

View만 변경하는 접근과 기존 15개 시드 카테고리에 대한 확신은 높다. 누락 카테고리의 테스트 목·경로는 첫 캡처 전에 집중 리뷰가 필요하다. 네 가지 기기 구분의 UI와 최종 PR 게이트는 계획 수립 당시 미완료이며, 이 계획은 구현 완료를 뜻하지 않는다.


## 최종 검증 체크포인트 (2026-11-02)

최신 main `bf3ebc11`를 실제 부모로 병합한 `13a9d7d5`와 준비 조건 수정 `95f5bc59`를 검토했다. 공개 T07 제품·unit·UI 소스와 동결 후보 `e2759822`의 해당 입력은 동일하며 기본 준비·orientation·엄격한 캡처·기존 assertion은 유지했다. 5개 독립 리뷰와 SwiftUI·Apple UX·최종 품질에서 새 P1/P2/P3는 없었다.

기존 변경 없는 unit 11개와 Phone 16개 분류 행렬·상태·실제 진입·큰 글씨, iPad 행렬의 실제 기록을 재사용했다. 새 Duo 접힘의 제한 ready/empty 1개는 0°·활성 LCD·strict 4쌍 ACK, 펼침의 수면 시각·보고 날짜 1개는 180°·활성 LCD-1·strict 3쌍 ACK로 통과했다. 이 실행은 앱·UI target 컴파일을 포함한다. Phone/iPad의 새 실행이나 전체 회귀로 표시하지 않는다.

[실제 비교 갤러리](../design/full-redesign-map/review/t07-all-data-native-2026-11-02/index.html)와 네 기기 canonical T07만 갱신했다. 다른 행·T05·T06·Watch는 보존했다. Phone/접힘의 HRV와 iPad/펼침의 Sleep을 각 원본과 정확히 짝지었으며, 과거 전역 수집 출처를 개별 소스·자세 증거로 바꾸지 않는다.

부모 PR 브랜치를 먼저 삭제해 #880이 자동 닫힌 것을 확인하고, 부모 ref를 임시 복원한 뒤 기존 PR을 다시 열어 main으로 전환했다. 의존 PR이 없는 것을 확인하고 임시 ref를 정리했다. 이 과정과 원래 닫힘 이벤트를 기록에 보존했다. source push는 이전 base 필터 밖이었고 base 편집 이벤트는 workflow 대상이 아니어서 현재 새 원격 CI는 미실행이다. 이를 통과라고 표시하지 않으며, 소스 동등성이 있는 실제 관련 증거와 필요한 두 검사를 사용했다. 보호 규칙과 최종 일반 머지는 별도로 확인한다.
