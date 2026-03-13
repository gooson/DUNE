# /run 전수 조사 보고서: 사용자 노출 화면 연결 점검

## 범위
- iOS 앱(`DUNE/`)의 `struct ...: View` 컴포넌트를 대상으로 정적 참조 점검을 수행했습니다.
- 선언 외 참조가 없는(= 사용자 플로우에 연결되지 않았을 가능성이 큰) 화면/컴포넌트를 추출했습니다.

## 조사 방법
1. `rg --files DUNE -g '*.swift'`로 분석 대상 Swift 파일 수집.
2. Python 스크립트로 `struct <Name>: View` 선언을 파싱.
3. 전체 Swift 소스 내에서 각 View 타입명의 단어 경계 참조 수를 집계.
4. 참조 수가 1(자기 선언만 존재)인 항목을 “연결 누락 후보”로 분류.

## 조치 사항 (이번 작업에서 연결 완료)

### 1) HabitIconPicker 연결
- 문제: `HabitFormSheet`에 `HabitIconPicker` 컴포넌트가 정의되어 있었지만 실제 Form 섹션에 삽입되지 않아 유저가 아이콘 카테고리를 선택할 수 없었습니다.
- 조치: `iconSection`을 추가하고 `Form`에 삽입하여 `selectedIconCategory` 바인딩을 연결했습니다.
- 영향: Life 탭의 습관 생성/수정 시 아이콘 선택 UI가 실제 노출됩니다.

### 2) Solar 전용 Wave Background 연결
- 문제: Solar 테마 전용 `SolarTabWaveBackground`, `SolarDetailWaveBackground`, `SolarSheetWaveBackground`가 존재했지만 라우팅 레이어(`WaveShape.swift`)는 legacy ocean solar 배경을 사용하고 있었습니다.
- 조치: `TabWaveBackground`, `DetailWaveBackground`, `SheetWaveBackground`의 `.solarPop` 분기를 Solar 전용 컴포넌트로 연결했습니다.
- 영향: Solar 테마 사용자의 실제 화면에서 최신 Solar 배경 컴포넌트가 반영됩니다.

## 잔여 연결 누락 후보 (추가 설계 결정 필요)
아래 항목은 선언 외 참조가 없으며, 데이터 소스/화면 배치 정책 확인 후 연결 여부를 결정해야 합니다.

- `HeartRateZoneChartView`
- `InjuryBodyMapView`
- `PeriodComparisonView`
- `SleepStageChartView`
- `WeeklySummaryChartView`
- `WorkoutRecommendationCard`
- `OceanLegacySolarTabWaveBackground`
- `OceanLegacySolarDetailWaveBackground`
- `OceanLegacySolarSheetWaveBackground`

> 참고: 마지막 3개는 이번 변경으로 사용자 라우팅에서 분리된 legacy 컴포넌트입니다(코드 보존 상태).

## 검증 명령
- `python3` 기반 정적 참조 카운트 스크립트로 후보 재검출.
- `git diff --stat`로 변경 파일 범위 확인.
