---
tags: [design, iphone, r10]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Exercise/
---
# Solution: R10 · cardio summary hierarchy

## Problem

The approved reference hierarchy for W25 is not represented in the existing native view.

## Change

Distance is the single primary result for distance cardio, duration follows, and secondary statistics use aligned rows. Time-only cardio makes duration primary. Existing Save action and persistence are unchanged. The previously missing Elevation Gain catalog entry is supplied in Korean and Japanese.

## Evidence to attach before merge

- Focused tests to run: ActivityExerciseRegressionTests.testCardioFlowReachesSummary and testVisualAuditCardioAtDefaultTextSize; verify distance above duration, no-distance stair primary duration, secondary metrics, and Save hit area.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open W25; running and no-distance cardio, standard/large text.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.

## Native capture verification

- [Actual W25 gallery](../../design/phone-design-map/actual/r10-cardio-summary-hierarchy-2026-11-21/index.html) contains 5 native capture(s) linked to passed XCTest cases.
- Source revision `41de4dfbcbb5265ae80d5b86f295842d965c992b`; build revision `47781c2d49de3f1c1ea54aef44a457ea8bb99b20,9d56a10d504b9970029186331187604a962cf472,676e10da12b4cc957e8cb6eb516fbee14af5035f,7b077bad0e854e86f904ecefe839d25f208de766,0a266b6ad3dedb4b8cb2e990f9e27cb77a54a871`. 기능별 원격 소스와 최종 통합본을 파일 단위로 대조했다. 각 이미지를 통과한 개별 UI 테스트에 연결했다. Duo 내부 화면은 지정된 체크포인트에서 활성 LCD-1 프레임버퍼를 직접 캡처했다. 파일별 빌드·크기·관찰 결과는 아래 기록에 있다.
- Unverified devices: none by device; screen IDs: none by screen ID. Any state absent from evidence.json remains unverified.
- Original file names, dimensions, hashes, test selectors, and timestamps are in gallery evidence.json. Visual inspection: 원본 화면 검토 완료; 기본 글씨에서 거리와 시간이 보조 지표보다 먼저 보인다. 최대 접근성 글씨에서 요약은 세로로 스크롤되고 저장 버튼이 하단에 보인다. iPad W25 실제 PNG에서 달리기 완료 제목 다음에 거리 0.00 km가 가장 크고 시간 0:17이 두 번째로 보이며, 하단 Save Workout 버튼 전체가 시트 안에 있다. 보조 지표는 스크롤 아래에 있어 이 한 장으로 행 배치를 판정할 수 없다. 한글 종목명과 영어 완료 문구가 혼재하지만 이 캡처의 테스트 언어 설정은 별도 확인이 필요하다. 접힘·최대 글자 크기: 거리 0.00 km가 주 결과로 크게 보이고 저장 버튼도 화면 안에 온전히 표시된다. 다만 영문 완료 문구와 달리기 이름이 매우 커서 시간 및 보조 지표는 이 한 장에 보이지 않으며, 화면 안의 한국어·영어 혼용도 확인된다. 펼친 Duo의 최대 글자 크기에서 달리기 완료 시트에 거리 0.00 km와 시간 0:17이 세로로 표시되고 저장 버튼 전체가 보인다.; 기능별 캡처 검토.
