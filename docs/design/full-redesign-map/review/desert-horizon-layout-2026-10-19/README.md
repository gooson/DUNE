# DESERT HORIZON 4탭 레이아웃 대조

[원본 시안](../../../theme-map/themes/dune-design-direction.html)과 **같은 어두운 모드**의 실제 앱 캡처를 우선 대조한다. 밝은 모드도 함께 보존한다.

| 화면 | 어두운 모드 실제 캡처 | 밝은 모드 실제 캡처 | 레이아웃 판정 |
|---|---|---|---|
| T03 Today | [dark/T03.png](dark/T03.png) | [light/T03.png](light/T03.png) | 점수·근거·행동을 한 카드에 묶고 7일 추세를 뒤에 배치했다. 시간별 표본이 없어 시안의 24시간 곡선 대신 빈 상태가 나온다. 추세 카드의 그래프 색·표면도 시안과 다르다. |
| A01 Activity | [dark/A01.png](dark/A01.png) | [light/A01.png](light/A01.png) | 준비도 수치·설명·운동 기록 행동을 하나의 미리보기 카드에 배치했다. 하단 능선과 행동의 대비를 실제 기기에서 추가 확인해야 한다. |
| H01 Wellness | [dark/H01.png](dark/H01.png) | [light/H01.png](light/H01.png) | 실제 수면 추세 막대·시간·하단 능선을 첫 카드에 배치했다. ‘수면 상세’가 수면 지표 상세로 열리는 UI 테스트가 통과했다. 별도 신체 기록 버튼 위치는 추가 대조가 필요하다. |
| L01 Life | [dark/L01.png](dark/L01.png) | [light/L01.png](light/L01.png) | 상단 제목과 능선, 첫 카드의 완료 수치·최대 3개 습관을 배치했다. 아래 전체 습관 목록과 정보가 중복된다. |

출처: `ThemeMatrixUITests/testDesertWarmMatrix()` 1건 통과(4탭 밝음·어두움 화면 및 수면 상세 이동), iPhone 18 Pro Max 시뮬레이터 `8D97EA93-CBF5-4D7C-9CFF-435EF2F85AB4`, 결과 번들 `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.19_12-22-55-+0900.xcresult`.

이 파일은 **중간 리뷰용 실제 캡처**다. `actual/regular/capture-index.json`은 현재 사용할 수 없는 다른 iPhone 시뮬레이터에서 만든 기준 인덱스이므로 섞어 쓰지 않았다. 시안과의 레이아웃 일치 및 디자인 디테일 검증은 아직 완료되지 않았다.
