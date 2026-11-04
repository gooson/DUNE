---
tags: [body-fat, dxa, nhanes, survey-reference, explicit-criteria, accessibility, menu-contrast]
category: architecture
date: 2026-11-05
status: implemented
severity: important
related_files:
  - DUNE/Domain/Models/BodyFatSurveyReference.swift
  - DUNE/Presentation/Shared/Detail/BodyPeerComparisonCard.swift
  - DUNETests/BodyFatSurveyReferenceTests.swift
  - DUNEUITests/Full/MetricDetailRedesignTests.swift
related_solutions:
  - 2026-11-02-metric-detail-visible-history-and-survey-reference.md
---

# 체지방 기록과 DXA 조사 평균을 분리해 표시하기

## Problem

기존 신체 비교 카드는 체중·BMI 조사 평균을 지원했지만 체지방에는 확인된 자료가 없었다. 체중 조사와 같은 연도·연령 구간을 적용하거나 생체전기저항법 기록과 DXA 평균의 차이를 건강 점수로 해석하면 서로 다른 측정값을 동등한 기준처럼 보이게 된다.

최대 접근성 글씨의 Duo에서는 기존 Picker가 선택한 성별을 줄였다. 단순히 탭 가능한 행을 찾는 테스트도 행 전체가 화면에 들어왔음을 보장하지 않았다. Menu로 줄바꿈을 허용한 뒤에는 상대적 `.secondary` 스타일이 버튼 tint를 상속해 선택값의 대비가 2.43:1로 낮아졌다.

## Solution

[CDC/NCHS Series 11 No. 250, Table 3](https://www.cdc.gov/nchs/data/series/sr_11/sr11_250.pdf)의 미국 NHANES 1999–2004 성인 전신 DXA 가중 평균을 별도 모델에 보존했다. 실제 연령 구간은 20–39, 40–59, 60–79, 80세 이상이다. 예를 들어 30–39세를 선택하면 결과에는 원문 구간인 20–39세로 명시하며, 표에 없는 10세별 평균을 보간하지 않는다.

| 파일 | 변경 | 보존 기준 |
|---|---|---|
| `BodyFatSurveyReference.swift` | 공식 평균 8개, 연령 매핑, 퍼센트 단위 검증 | 기존 체중·BMI 2021–2023 자료와 분리 |
| `BodyPeerComparisonCard.swift` | 명시적 기준 선택, 측정 방식 안내, 내 기록과 조사 평균의 별도 행 | 차이 그래프·건강 등급을 생성하지 않음 |
| `BodyFatSurveyReferenceTests.swift` | 원문 값·매핑·경계·무효 수치 검사 | 비율과 퍼센트 포인트의 중복 변환 방지 |
| `MetricDetailRedesignTests.swift` | 취소·적용·출처·실제 복귀·저장된 기준·큰 글씨 확인 | 탭 가능 여부와 전체 viewport를 별도로 검사 |

체지방 입력은 이미 0–100 퍼센트 포인트이므로 카드에서 다시 100을 곱하지 않는다. 단위가 `%`이고 유한한 0–100 값일 때만 기록을 표시한다. 잘못된 값에 가짜 0을 만들지 않는다. 조사 성별은 사용자의 명시적 선택만 사용하며 프로필이나 HealthKit으로 추정하지 않는다.

체지방의 접근성 글자 크기에서만 제목과 선택값이 줄바꿈하는 native Menu를 사용한다. 보통 글씨와 기존 체중·BMI Picker는 유지한다. Menu 안의 상대적 tint 상속을 피하도록 선택값과 화살표에 기존 적응형 텍스트 색을 지정했다.

```swift
Text(value)
    .foregroundStyle(DS.Color.textSecondary)
    .fixedSize(horizontal: false, vertical: true)
```

실제 어두운 Duo 캡처에서 선택값은 RGB `(222, 211, 199)`, 행 배경은 `(44, 44, 46)`이며 대비는 9.46:1이다. native 뒤로가기 버튼은 Duo의 측면 레일에도 나타나므로 navigation bar 자식으로 한정하지 않는다. 정확한 AX ID, 활성·탭 가능·전체 window 포함, 실제 Today 복귀를 함께 검증한다.

## 검증 범위

- 모델 두 suite의 논리 검사 12개는 `1480a066`에서 실제 통과했다. 두 후처리 실패와 원본 SDK·복구 증거를 보존했고, 이후 변경되지 않은 모델·단위 검사 바이트에만 결과를 재사용했다.
- [실제 갤러리](../../design/full-redesign-map/review/t06-body-fat-dxa-native-2026-11-05/index.html)에 선택한 UI 사례 5개와 PNG/AX 32쌍을 연결했다. Duo 접힘의 보통 글씨 사례는 `113b87cd`의 실패한 2실행·1통과·1실패 aggregate 안에서 통과한 한 사례다. 해당 aggregate와 원래 pipeline 실패를 통과로 바꾸지 않는다.
- 최종 `2f40e909`의 Duo 접힘 최대 글씨, Duo 펼침, iPhone, iPad 사례는 각각 실제 1개 통과했다. 접힘·펼침은 같은 소유 기기의 실제 각도와 활성 LCD를 함께 확인했다. 중간 `4a31b828` 최대 글씨의 동작 통과와 낮은 대비 지적도 별도로 보존했다.
- 전체 Vision 빌드는 기존 타깃 의존성 누락으로 실패했다. 변경한 Foundation 모델 두 개의 XRSimulator Swift 6 strict typecheck만 별도로 통과했으며 전체 Vision 통과로 표시하지 않는다. Watch에는 변경된 소비자가 없다.
- 신규 문자열 16개는 수동 en/ko/ja 항목이고 기존 3,139개 항목은 동일하다. 실제 native 캡처는 English이며 한국어·일본어는 소스와 카탈로그 검토 범위다.
- 과거 체지방 화면 4장은 iPad 자료다. 새 DXA 카드의 같은 상태·기기에서 촬영한 이전 화면으로 표시하지 않으며, 기존 T06 HRV 행과 캡처는 유지한다.

## Prevention

- 원문 표의 조사 연도·모집단·측정 방식·실제 연령 구간·통계 종류를 수치와 함께 확인한다.
- 측정 방식이 다르면 값보다 먼저 설명하고, 건강 판정이나 보간한 평균을 만들지 않는다.
- `isHittable`과 전체 행·그래프의 viewport 포함을 구분한다. 큰 행은 짧고 제한된 스크롤로 접근해 지나치지 않는다.
- 버튼·Menu 안의 상대적 foreground style을 검토하고 실제 PNG의 글자·배경 대비를 확인한다.
- 부분 통과, 후처리 실패, 전체 타깃 실패를 각각 보존한다. 변경되지 않은 소비자의 증거만 정확한 바이트·상태 범위로 재사용한다.

## Lessons Learned

컴포넌트의 시각적 통일성과 통계적 동등성은 별개다. 원문과 측정 방식을 확정한 뒤 기존 아이콘과 레이아웃으로 각 값의 의미를 드러낸다. 기능 검사 통과 뒤에도 실제 큰 글씨 캡처를 검토해야 줄임표와 tint 상속으로 생긴 가독성 문제를 발견할 수 있다.
