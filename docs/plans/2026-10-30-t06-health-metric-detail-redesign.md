---
topic: t06-health-metric-detail-redesign
date: 2026-10-30
status: approved
confidence: medium
related_solutions:
  - ../solutions/architecture/2026-03-11-metric-detail-weekly-chart-current-day-alignment.md
  - ../solutions/architecture/2026-03-14-metric-detail-today-scroll-padding.md
  - ../solutions/architecture/2026-10-30-shared-score-history-contract.md
---

# 구현 계획: T06 건강 지표 상세

## 배경과 조사

사용자는 검토한 상세 시안을 실제 iPhone·iPad·Duo 앱에 구현하고, 기존 기능·아이콘을 보존하면서 화면별 `/run` PR을 만들도록 승인했다. 계획 작성 당시 T05는 `codex/t05-cumulative-stress-redesign`에 분리돼 있었고, 최종 UI 검사는 실행 도구의 제한과 명시적 예외 질문으로 보류된 상태였다. 독립 T06 브랜치는 `9a21f364`에서 시작하며 T05 소스나 실행 기록을 변경하지 않는다. 이후 실제 진행 결과는 아래 날짜별 체크포인트와 최종 품질 확인에 구분해 기록한다.

찾을 수 없던 시안은 Git snapshot `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894`에서 읽기 전용으로 복구했다. 전체 manifest SHA는 보존된 T05 검토 소스와 같다. 이는 인덱스에 등록된 시안의 식별 근거이며, 사라진 worktree에서 나중에 생긴 미커밋 변경까지 복구했다는 뜻은 아니다. T06 시안 16개 변형은 디자인 증거로 보존하고 실제 앱 캡처나 검증된 제품 비교 자료로 표시하지 않는다.

세 가지 범위로 나눠 native category 분기·프로필 근거, 해결책·화면 목록·UI selector, 공식 신체 비교 자료를 조사했다. 과거 T06 캡처 네 장은 모두 Sleep이므로 HRV 비교에 사용할 수 없다. 보존 대상은 16개 category 전체와 단위 override, 일별·시간별 데이터, 기간 선택, 차트 선택·스크롤·추세선, 제한된 이력, 하이라이트, 조건부 수면 분석 네 그룹, 가시 구간 운동 합계, All Data다.

시안의 MCST 참조값을 제품 데이터로 바로 사용할 수는 없다. [공식 배포 페이지](https://www.mcst.go.kr/site/s_policy/dept/deptView.jsp?pDataCD=0417000000&pSeq=2106)는 KOGL Type 4를 명시한다. MCST·InBody 표나 예시 프로필을 검증된 제품 기준값으로 사용하지 않는다. [NCHS Series 3 No.50](https://stacks.cdc.gov/view/cdc/174595/cdc_174595_DS1.pdf)의 표 3·10에는 public domain인 미국 NHANES 2021–2023 성인 체중·BMI 평균이 있다. 조사·대상 집단·제외 기준·재사용 출처를 상세 정보에서 확인할 수 있어야 한다. DXA 1999–2004 체지방 자료는 측정 방법이 불명확하거나 BIA인 기록의 정밀한 순위를 산정할 근거가 아니다. 한국인 및 체지방·제지방량 비교는 적용 가능한 정확한 출처와 권리가 확인되기 전까지 미지원으로 남기며, 완료 보고에서도 이 공백을 명시한다.

## 요구사항

- category별 쿼리·실제 값·포맷·정밀도·단위·내비게이션·조건부 분석을 보존한다. 0, 현재 값, 이력, 프로필, 비교 백분위, 임상 등급을 임의로 만들지 않는다.
- 기존 `ScoreHeroPalette`와 category의 원래 아이콘·색을 사용해 실제 수치가 돋보이는 일관된 히어로를 만든다. kg·BMI·ms·min은 100점 점수가 아니므로 점수 링을 만들지 않는다. 큰 글씨에서는 값·단위·보조 정보를 재배치해 잘림을 방지한다.
- 기간 선택·이전/다음·가시 날짜 범위 한 번·차트·추세선·가시 구간 요약을 한 카드에 모은다. D/W/M/6M/Y, 기존의 세밀한 일간 sampling, 선택·스크롤 수명주기, 기간 경계, 이력 제한을 보존한다. 점수 전용 helper를 재사용하기 전에 기존 달력·원본 통계 계약을 확인한다. plot 집계가 원본 통계의 의미를 바꾸면 안 된다.
- 지표의 앞쪽 아이콘·간격·수치 의미를 일관되게 표현한다. 수면 분석 네 그룹과 거리·분 단위 운동 분기를 보존하고 전문화된 내용을 일반 카드로 대체하지 않는다.
- 체중·BMI에는 사용자가 명시적으로 선택하는 선택적 미국 참조 집단과 출처의 실제 평균을 제공한다. locale이나 시안으로 나이·성별·지역을 추정하지 않는다. 새 HealthKit 인구통계 권한을 요청하지 않으며, 비교 기준 시트는 선택한 참조 나이 구간과 통계상 성별만 로컬에 저장한다. 초기값은 미선택이다. Apply 전에 미국 조사라는 맥락을 알리고 미지원 집단으로 fallback하지 않는다.
- 표시 단위로 변환하기 전에 기준 kg 또는 무차원 BMI로 비교하며 선호 체중 단위를 보존한다. 현재 값에서 평균을 뺀 중립적인 차이를 표시하고 건강·비건강 평가로 표현하지 않는다. 체지방·제지방량 비교는 미지원임을 명확히 표시하면서 실제 데이터와 이력을 보존한다. 이는 전체 동년배 비교 요청에서 아직 남은 부분이며 체지방 지원 완료가 아니다.

## 접근 방식과 대안

| 접근 방식 | 판단 |
|---|---|
| 시안의 MCST 값과 고정된 30–34세·남성 프로필 복사 | 제외. 예시 프로필이며 사용이 제한되거나 제품 적용을 검증하지 않은 자료다. |
| 인구통계 정보를 추정하거나 미국 자료를 한국 자료로 표시 | 제외. 사용자 식별·대상 집단이 맞지 않는다. |
| 전문 분석이나 All Data를 제거하면서 외관만 변경 | 제외. 기존 기능이 빠진다. |
| native category 분기·formatter 유지, 히어로 palette 재사용, 차트 요약 통합, 검증된 선택적 참조 제공 | 채택. 작고 검토 가능한 변경을 유지한다. |
| 모든 지표 쿼리·이력 계약 재작성 | 실제 불일치가 확인되지 않으면 하지 않는다. 영향받은 계약만 수정하고 필요한 검사를 선택한다. |

## 영향 파일 (Affected Files)

| 파일·영역 | 계획한 변경 |
|---|---|
| `Presentation/Shared/Detail/MetricDetailView.swift` | 히어로·이력 통합·간격, 기존 분석·조작과 참조 화면 진입 |
| `MetricSummaryHeader.swift` / 필요한 새 히어로 컴포넌트 | 정확한 값·단위 포맷 재사용. 기간·통계를 옮긴 뒤에만 히어로의 중복 표시 제거 |
| `MetricDetailViewModel.swift` | 확인된 가시 구간·페이지·요약 불일치만 수정. 쿼리 분기·cadence 유지 |
| 신체 참조 전용 domain model과 표시 컴포넌트 | 검증한 체중·BMI 평균·적용 범위·차이, 미선택·미지원 상태, 로컬 기준과 출처 공개 |
| `DUNETests/MetricDetailViewModelTests.swift`, 관련 formatter·참조 검사 | 단위·cadence·경계·참조·잘못된 입력 검증 |
| T06 전용 UI 캡처·회귀 검사와 필요한 opt-in DEBUG fixture | 정확한 지표 식별·전후 행렬·native 내비게이션·큰 글씨 |
| `Shared/Resources/Localizable.xcstrings`, 생성 프로젝트, layout/theme/actual map | en/ko/ja, 표준 formatter·regen, 실제 소스 출처 보존 |

## 구현 순서와 게이트

1. 검토한 variant JSON을 보존하고 앱 수정 전에 layout/theme 방향을 갱신한다. theme map 동기화를 검사한다. 영향받는 native 파일·호출부와 관련 해결책을 직접 읽어 프로필·출처 가정을 확인한다.
2. 결정적인 opt-in fixture와 가능한 기존 내비게이션으로 올바른 native 원본 증거를 확보한다. 제품 배치를 바꾸기 전에 원래 지표 화면을 캡처한다. `metric-detail-screen-hrv`와 HRV·단위가 맞아야 하며 과거 Sleep 이미지를 대신 쓰지 않는다. 사용자가 모든 상세 변형을 요청했으므로 16개 category의 식별 행렬을 보존한다. 네 기기 대표 맵은 HRV를 사용하고 나머지 변형은 비교 갤러리에 둔다. 운동 km/min 분기와 전문 수면 내용도 각각 근거를 확보한다. 없는 변형은 대체 이미지를 넣지 말고 미확보로 기록한다.
3. 일관된 실제 수치 히어로와 통합 차트·요약을 구현하되 전문 그룹과 All Data를 보존한다. 논리적 단위로 커밋한다. 검증한 체중·BMI 참조와 미선택·미지원 상태를 추가하고 필요한 계산·프로필 검사를 작성한다. 체지방 순위나 사용 권리가 확인되지 않은 값은 추가하지 않으며 전역 프로필·HealthKit 권한 개편으로 범위를 넓히지 않는다.
4. 소스를 동결하고 소유 기기에서 표준 빌드·포맷 검사·소비자 분석·관련 unit·선택 UI 검사를 한 번에 하나씩 실행한다. iPhone의 필요한 검사부터 시작해 영향받는 iPad와 Duo 접힘·펼침을 확인한다. 큰 글씨·어두움·단위·차트 제스처·원래 내비게이션을 검사한다. 사용자 명시 요청 없이 로컬 전체 suite를 실행하지 않는다. pipeline 시도 전에 잠금 사용 가능 여부를 확인하며 잠금 대기를 앱 실패나 테스트 성공으로 표시하지 않는다. 이 화면을 통과시키기 위해 실행기를 수정하지 않는다.
5. 정확한 revision·fixture·기기·상태와 native AX/PNG 식별 정보를 포함한 새 실제 캡처를 내보낸다. 확보한 전후 쌍을 모두 비교하고 영향받은 맵 기록만 다시 생성한 뒤 실제 이미지를 검토한다. HRV 캡처 한 장으로 모든 category·상태·테마를 검증했다고 주장하지 않는다.
6. 소스 리뷰 다섯 관점, SwiftUI·Apple UX·UI-test·성능 검토의 적용 여부, App Quality, Resolve, Compound, Pre-Ship, PR reviewer 절차를 수행한다. 미지원 참조 자료나 미확보 캡처 범위를 명시한다. 필요한 native 게이트를 충족한 뒤 PR 생성·머지를 진행하고 소유 기기·브랜치 정리와 표준 프로젝트 재생성을 수행한다.

## 검사와 경계 조건

- 16개 category 분기·단위 전체, SpO₂ 비율의 1회 변환, 부호 있는 손목 온도, 수면 시간, 운동 km/min, 선호 질량 단위를 확인한다.
- 달력·DST·월말, 현재의 완전한 하루, 가시 이전 구간, 취소·늦은 응답, 누락·제한·오류 데이터, 원본 요약과 plot bucket의 구분, 스크롤 후 선택과 차트에서의 세로 스크롤을 확인한다.
- 참조 조회는 조사표의 20–29/30–39/40–49/50–59/60–69/70–79/80+ 및 남성·여성 행과 정확히 대응해야 한다. 5세 구간 보간, 가까운 나이·다른 성별 fallback, 미지원 지표, 잘못 저장된 기준을 허용하지 않는다. 나이·성별 기본값을 두지 않는다. 유한한 기준 수치, kg/lb 차이 변환, 원본 표 출처, 평균과 P50의 구분을 확인한다.
- 새 전후 화면의 정확한 식별, 큰 글씨·아이콘·수치 간격, 도달 가능한 44pt 조작을 확인한다. 기존 진입·All Data 선택 검사는 `WellnessRegressionTests/testHRVCardOpensMetricDetailAndAllData`이며 관련 차트 회귀 검사는 `ChartInteractionRegressionUITests`에 있다.

## 위험과 신뢰 수준

계획 시점에서 소스 보존의 신뢰도는 높고, 실제 실행·캡처 범위와 비교 자료의 제품 UX는 구현·검증 전까지 중간 수준이다. NHANES 참조는 미국 조사 평균이며 한국인 기준이나 건강 목표가 아니다. 체지방·제지방량 비교는 지원을 주장하지 않으며 적용 가능한 출처 조사가 더 필요하다. HRV 비교에서 과거 Sleep 쌍을 제거해야 한다. 공통 차트 수정은 다른 소비자에 영향을 줄 수 있으므로 동작 변경을 최소화하고 필요한 범위 확장을 기록한다. 당시 T05 실행 정책 질문은 독립 사안이며 T06을 통해 우회하지 않는다.

## 구현 체크포인트: 독립 native 브랜치의 당시 기록

당시 원본 T06 캡처 worktree는 `0dc77dc4`로 동결해 뒀다. native 구현 브랜치에는 검토한 실제 수치 히어로, 가시 구간 통계, 기간 조작, 명시적 미국 조사 비교를 연결했다. 소스·UI·카탈로그 변경은 이 브랜치에 한정했다. generic iOS 빌드로 Swift 통합을 확인했으며, 그 시점의 unit/UI selector·기기 표시·새 실제 디자인맵 캡처는 별도 게이트로 남겼다. 체지방·제지방량의 비교 평균은 미지원이지만 기존 이력은 계속 표시한다.

## native 최대 글씨 검토 후속: 당시 기록

`b95e366a`의 Weight 최대 접근성 글씨 캡처에서는 기능 도달 검사가 통과했는데도 요일 라벨이 겹쳤다. `AreaLineChartView`의 소비자는 `MetricDetailView`뿐이다. 접근성 글씨에서만 주간 축을 달력에 고정된 요일 두 개로 줄이고 데이터·선택·스크롤·다른 기간·기본 글씨 눈금·전체 날짜 범위를 보존했다. 이 수정의 검증 대상으로 `MetricDetailRedesignTests/testWeightMaximumAccessibilitySizeKeepsContentReachable`과 새 축 PNG 검토를 선택했다. 표시 밀도만 바꾸므로 기존 모델·도메인 검사 57개의 대상은 바뀌지 않는다. 별도의 기본 글씨 DotLine 날짜 라벨 문제는 당시 T05 재시도 한도 아래 미해결로 남겼다.

## main 통합 체크포인트: 2026-10-31 당시 기록

독립 T06 브랜치에 고정한 main `10fa29fb`를 병합하면서 상위 검토를 위해 커밋 전 상태로 뒀다. 텍스트 충돌은 Xcode 프로젝트의 테스트 소스 목록 한 곳이었으며 T06 `MetricDetailRedesignTests.swift`와 main `LocalTimePresentationUITests.swift` 등록을 모두 보존했다. T06 metric/detail/chart/ContentView 구현과 전용 지표 UI 검사는 병합 전 `3d299a50`와 byte-identical이고, main의 dashboard 로컬 시계·Health Query 파일은 `10fa29fb`와 byte-identical이었다. Watch test target 설정은 T06 전용 수정 없이 main에서 들어왔다. 당시 병합 결과 빌드와 필요한 UI 증거는 상위 작업에 남겼으며, 이전 T06 native 영수증이나 main 로컬 시계 영수증을 병합 결과의 통과로 바꾸지 않았다.


## 최종 품질 확인 (2026-11-02)

최신 main `f8d04319`를 실제 부모로 가진 병합 `807c69e1`과 테스트 준비 수정 `a6f52495`를 검토했다. 기존 T06 제품 소스와 들어온 T05·main 소스 및 카탈로그 키를 모두 보존했다. 독립 상세 fixture의 탭 바 요구 오류는 정확한 category 화면 ID를 기다리는 override로 해결했으며 기본 공통 준비·orientation·strict audit와 기존 본문 assertion은 유지한다. 첫 접힘 실패와 같은 ID의 수정 후 재시도 1회를 보존했다.

검증 후보 `c0b51078`에서 iPhone 5개(식별·5개 기간·이동·어두움·체중 최대 글씨), Duo 접힘 1개와 펼침 1개가 통과했다. Duo는 각각 0°/180° 및 활성 LCD의 strict PNG/AX 2쌍을 확인했다. 최대 글씨의 Weight 주간 Wed/Sun 날짜가 실제로 겹치지 않음을 확인했다. 기존 iPad 18개 식별은 한 테스트의 행렬이며 18개 테스트 통과로 부풀리지 않는다. 18개 원본/개편 초기 PNG 36장의 종류·아이콘·단위·상단 배치를 모두 시각 검토했다.

[실제 비교 갤러리](../design/full-redesign-map/review/t06-metric-matrix-native-2026-11-02/index.html)와 네 기기 actual map의 T06만 갱신했다. 다른 행·T05는 보존했다. 기존 iPad 공통 원본과 Phone·Duo의 서로 다른 기기/viewport를 명시하며 존재하지 않는 기기별 원본이나 수영 하단 캡처를 만들지 않았다.

현재 앱 CI 빌드와 Watch 213개/29개 suite는 통과했다. iOS의 관련 T06 7개 suite도 모두 통과했으나 전체 2,733개/302개 suite는 변경 없는 라이브 AI 평가 2개의 모델 asset 누락으로 실패했다. 원래 실패를 보존하고 관련 소스 동등성 및 범위를 별도로 검토한다. 이전 T05에서는 해당 라이브 AI 평가가 skip이었으므로 AI 회귀 통과로 표시하지 않는다. 공통 날짜 눈금 TODO 158은 여전히 별도 미해결이다. 최종 Ship 결과는 원격 머지 확인 후 기록한다.
