# H02 웰니스 점수 상세 · 구현 전 배치 계약

2026-10-31. [테마 방향](../theme-map/themes/dune-h02-wellness-score-detail.html)은 브라우저 시안이다. 그 안의 숫자와 그래프는 설명용이며 현재 HealthKit 값이나 앱 캡처가 아니다. 현재 빌드의 원본 iPhone H02 캡처는 별도 검증 증거에 보존하며, 이 문서가 그 결과를 대체하지 않는다.

## 데이터와 정보 순서

1. **영문 고정 내비게이션 제목 `Wellness Score`와 시스템 back.** `WellnessView`가 실제 `WellnessScore`, 선택적 `ConditionScore`·`BodyScoreDetail`, `ScoreRefreshService`를 전달한다. `wellness-score-detail-screen` AXID를 유지한다.
2. **불투명 H02 전용 히어로.** T04/H01의 `ScoreHeroPalette` 표면·전경색과 `CompactConditionRing`을 사용한다. `WELLNESS`, 실제 0–100 점수, `WellnessScore.status`의 라벨·SF Symbol, 실제 `evaluationDate`, 기존 `narrativeMessage` 또는 `guideMessage`를 표시한다. 시안의 81점이나 excellent 아이콘을 고정하지 않는다. 아이콘·상태 텍스트는 팔레트의 `ink`/`muted`로 읽히고, 상태색과 네 구성 색은 별도 의미를 유지한다.
3. **네 구성 점수.** 수면 35% `moon.fill`, 컨디션 30% `heart.fill`, 신체 20% `figure.stand`, 자세 15% `figure.stand`. 원래 H01의 의미별 아이콘을 따른다. 실제 optional 값을 표시하고 nil은 `—`로 남기며 막대에 0을 채우지 않는다. 아래 기존 `ScoreCompositionCard`는 계산 가중치와 결측 설명을 계속 보여 준다.
4. **시간대.** 기존 `TimeOfDayCard`의 야간·아침·낮·저녁 추정을 유지하고 H02 호출부에서 적응형 배치를 켠다. 실제 `timeOfDayAdjustment`와 기준 점수에서만 계산한다.
5. **하나의 기간·추세 카드.** 기존 D/W/M/6M/Y `Picker` → 현재 가시 날짜와 Trend 토글 `ScoreDetailChartHeader` → 50점 기준선과 스크롤/점 선택을 가진 `DotLineChartView` 또는 기존 `ScoreDetailEmptyState` → 실제 요약·하이라이트 순서다. H02 ViewModel에 없는 이전/다음 기간 버튼을 그리지 않는다. 차트 높이는 큰 글씨에서 child가 요구하는 높이를 확보한다.
6. **하위 추세와 계산 근거.** 일간은 rolling snapshot만 표시하고 하위 HRV/RHR/수면 그래프는 숨긴다. 나머지 기간의 세 하위 그래프, `ScoreCompositionCard`, 기여 요인이 있을 때의 `ScoreContributorsView`, 실제 세부 정보가 있을 때만 나오는 `ConditionCalculationCard`/`BodyCalculationCard`, 다섯 계산 설명 bullet을 모두 유지한다. 비일간 웰니스 과거선은 HRV/RHR/수면 기반 기존 근사치이며 당시 신체·자세의 완전한 4요소 기록이 아니다.

## 상태와 반응형 배치

| 상태 | 표시 계약 |
|---|---|
| 전체 또는 일부 구성 점수 | 네 자리 모두 유지하고 nil은 `—`; 실제 이용 가능한 가중치만 재조정 |
| 점수 상태 경계 | 80/60/40/20점에서 동일 `status`의 라벨·아이콘·색을 함께 사용 |
| 차트 로딩 / 차트 없음 | 기존 spinner와 `ScoreDetailEmptyState`를 구분; 근거 없는 오류 문구를 만들지 않음 |
| RHR today/latest/baseline/none | 기존 `ConditionCalculationCard`의 조건부 세부 내용 보존 |
| 신체·컨디션 계산 detail 없음 | 해당 계산 카드만 생략; 방법 설명과 나머지 내용 유지 |
| 접근성 최대 글씨 / 좁은 Duo | 링 대신 외부 큰 점수·상태와 한 열 네 근거, 시간대 적응형, 값·단위 완전 표시 |

iPhone·Duo 접힘은 한 열로 스크롤한다. iPad·Duo 펼침은 전체 콘텐츠를 가운데 최대 약 680pt로 묶어 시각적 읽기 폭을 제한한다. 일반 글씨에서는 링·상태를 나란히, 큰 글씨에서는 점수를 링 밖에 둔다. 차트의 점 선택·기간 선택·토글·내비게이션은 그대로 조작 가능해야 한다. 계산 내용을 숨기는 새 disclosure는 이번 범위에 넣지 않는다.

구현 전후 검증은 동일 현재 점수·기간·기기·테마의 실제 H02 캡처로 판정한다. 예전 네 기기 H02 이미지는 화면 식별용 역사 자료이며 상태·테마가 확인된 현재 before 증거로 쓰지 않는다.
