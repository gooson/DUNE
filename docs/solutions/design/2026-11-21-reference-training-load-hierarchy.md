---
tags: [design, iphone, r06]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Activity/
---
# Solution: R06 · training load hierarchy

## Problem

The approved reference hierarchy for A06 is not represented in the existing native view.

## Change

Selected date and load now precede the chart; rolling comparison follows it. Fixed 2/4/7 colors and legend remain. R07 owns same-count cache invalidation and scroll-domain reset; this PR consumes those values without changing their update policy.

## Evidence to attach before merge

- Focused tests to run: ChartInteractionRegressionUITests.testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection and testTrainingVolumeTrainingLoadChartScrollsToPastData.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open A06; selected day, scroll, empty state, and large text.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.

## Native capture verification

- [Actual A06 gallery](../../design/phone-design-map/actual/r06-training-load-hierarchy-2026-11-21/index.html) contains 4 native capture(s) linked to passed XCTest cases.
- Source revision `67c7fef94e88e615d011d7ce1d35fb00fc004ef9`; build revision `112f1d6e8b8627579efe5fa334735ff84c4f01d1,676e10da12b4cc957e8cb6eb516fbee14af5035f,e4600dc0700a0362fc4dcc42a0def7bf96c0b475,0a266b6ad3dedb4b8cb2e990f9e27cb77a54a871`. 기능별 원격 소스와 최종 통합본을 파일 단위로 대조했다. 각 이미지를 통과한 개별 UI 테스트에 연결했다. Duo 내부 화면은 지정된 체크포인트에서 활성 LCD-1 프레임버퍼를 직접 캡처했다. 파일별 빌드·크기·관찰 결과는 아래 기록에 있다.
- Unverified devices: none by device; screen IDs: none by screen ID. Any state absent from evidence.json remains unverified.
- Original file names, dimensions, hashes, test selectors, and timestamps are in gallery evidence.json. Visual inspection: 원본 화면 검토 완료; 선택 날짜 11월 21일과 값 0.0, 간격을 둔 날짜 눈금, 7일 합계 및 범례를 한 화면에서 읽을 수 있다. iPad A06 실제 PNG에서 선택 날짜(11월 21일)와 큰 부하 값 0.0이 차트 위에 있고, 7일 막대·이동평균선·최근 7일 34.1(↑55%) 비교·고정 구간 범례가 모두 보인다. 카드 하단과 범례가 화면 안에 있으며 레이아웃 겹침은 보이지 않는다. 이 한 장은 탭/빈 상태나 다른 날짜 선택을 검증하지 않는다. 접힌 외부 화면에서 선택 날짜·값, 훈련 부하 그래프 전체, 16·18·20일 눈금과 합계 및 범례가 함께 보인다. 위쪽 일별 운동 시간 카드는 별개 차트다. Duo 내부 가로 화면에서 선택일과 0.0, 막대 그래프 전부, 7일 합계와 범례가 같은 카드 안에 표시된다.; 기능별 캡처 검토.
