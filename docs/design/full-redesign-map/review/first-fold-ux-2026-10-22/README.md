# T03·A01·H01 첫 화면 UX 개편 실제 캡처

[화면별 밝음·어두움 비교](index.html) · [전체 디자인맵](../../index.html)

2026-10-22의 `d55e08aa` 앱 소스에서 만든 DESERT HORIZON 실제 화면이다. 테스트 데이터가 주입된 `ThemeMatrixUITests.testDesertWarmMatrix`의 `XCUIScreen.screenshot()` 첨부 파일을 복사했다. 시안 이미지나 기존 인덱스의 이미지를 재사용하지 않았다.

| 기기 | 화면 | 출처 |
|---|---|---|
| iPhone 18 Pro · 1206×2622 · `E98E4EDD-DE25-41FA-A6C8-B5051C82F35E` | [T03 밝음](iphone/T03-light.png) · [T03 어두움](iphone/T03-dark.png) · [A01 밝음](iphone/A01-light.png) · [A01 어두움](iphone/A01-dark.png) · [H01 밝음](iphone/H01-light.png) · [H01 어두움](iphone/H01-dark.png) | `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.22_14-50-47-+0900.xcresult` · 1/1 통과 |
| iPad Pro 13-inch (M5) · 2064×2752 · `18499616-B76F-44AE-B07F-219E68716586` | [T03 밝음](ipad/T03-light.png) · [T03 어두움](ipad/T03-dark.png) · [A01 밝음](ipad/A01-light.png) · [A01 어두움](ipad/A01-dark.png) · [H01 밝음](ipad/H01-light.png) · [H01 어두움](ipad/H01-dark.png) | `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.22_14-53-01-+0900.xcresult` · 1/1 통과 |
| iPhone Duo 접음 · 외부 화면 1398×2034 · `E24F79F5-AA72-4A0E-8018-91ADC761F40D` | [T03 밝음](duo-closed/T03-light.png) · [T03 어두움](duo-closed/T03-dark.png) · [A01 밝음](duo-closed/A01-light.png) · [A01 어두움](duo-closed/A01-dark.png) · [H01 밝음](duo-closed/H01-light.png) · [H01 어두움](duo-closed/H01-dark.png) | `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.22_14-59-01-+0900.xcresult` · 1/1 통과 |
| iPhone Duo 펼침 · 내부 화면 2007×2853 · 같은 기기 | [T03 밝음](duo-open/T03-light.png) · [A01 밝음](duo-open/A01-light.png) · [H01 밝음](duo-open/H01-light.png) | `/tmp/dune-final-duo-open-host/`의 002–004 체크포인트 · 실제 활성 화면 `simctl io` 캡처 |

T03은 히어로 전체를 컨디션 상세 진입으로 통일하고 탭 전환 버튼을 제거했다. 시간별 데이터가 부족할 때는 실제 일별 추세를 보여주며, 두 종류 모두 부족하면 빈 상태를 표시한다. H01은 최근 수면 날짜·시간과 표본이 충분할 때의 7일 평균을 구분한다. 몸 기록 행동은 관련 정보 뒤에서 제공한다.

A01은 긴 건강 데이터 조회 중에도 준비도 카드와 운동 진입·검색을 표시한다. 별도 빈 데이터 UI 테스트에서 기존 실패 5건을 포함한 Activity 9건이 통과했다. iPad H01은 점수·설명과 수면 기록을 두 열로 나눴다.

iPhone·iPad·접은 Duo의 밝음·어두움 18장과 펼친 Duo의 밝음 3장을 확인했다. iPad H01의 오른쪽 수면 열과 하단 상세 링크에 잘림·겹침이 없었다. 펼친 Duo는 `XCUIScreen.screenshot()` 첨부 이미지가 검게 저장되어 활성 내부 화면의 호스트 캡처만 사용했다. 네 번째 체크포인트에서 호스트 캡처가 시간 초과됐고 재시도는 앱 재실행 중 멈춰, 펼친 상태의 어두움 화면은 확인하지 못했다. 이 이미지는 세 화면과 DESERT HORIZON 테마의 해당 상태만 증명하며 8테마 전체 또는 큰 글씨 검증으로 확대하지 않는다.
