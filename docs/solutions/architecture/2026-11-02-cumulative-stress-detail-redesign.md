---
tags: [cumulative-stress, score-history, swiftdata, dynamic-type, contrast, native-evidence]
category: architecture
date: 2026-11-02
severity: important
status: reviewed
related_files:
  - DUNE/Data/Services/ScoreRefreshService.swift
  - DUNE/Presentation/Dashboard/CumulativeStressDetailViewModel.swift
  - DUNE/Presentation/Dashboard/CumulativeStressDetailView.swift
  - DUNE/Presentation/Dashboard/Components/CumulativeStressLevelGuide.swift
  - DUNEUITests/Full/CumulativeStressDetailRedesignTests.swift
related_solutions:
  - 2026-04-05-cumulative-stress-detail-view.md
  - 2026-10-30-shared-score-history-contract.md
---

# 누적 스트레스 상세: 일관된 이력과 읽기 쉬운 구간 안내

## Problem

기존 요인 점수·심벌·설명·기간 조작을 보존하면서 점수 히어로와 카드 간격을 강조해야 했다. 행 수를 제한한 이력 조회는 최신 기록을 누락할 수 있었고, 달력 기준 요약은 차트의 실제 가시 구간과 다를 수 있었다. 현재 적용 비중과 모델의 기본 비중도 구분해야 했다.

실제 앱 검토에서는 작은 구간 숫자의 대비가 낮은 문제도 확인했다. `.tertiary` 텍스트와 비활성 행 전체의 opacity가 겹친 것이 원인이었다. AX 요소의 존재만으로는 실제 글자가 읽히는지, 내비게이션 material에 가리지 않는지 확인할 수 없었다.

## Solution

| 영역 | 구현 계약 |
|---|---|
| 이력 조회 | 최대 31일의 완전한 반개구간 `[start, end)` 조회, 취소 검사, 유한한 0–100 값 검증, 시간별 최신 행의 결정적 선택을 사용한다. 임의의 새 행 수 제한이나 DB 정리는 하지 않는다. |
| 가시 구간 통계 | 공통 고정 길이 window를 사용한다. 일간은 시간별 관측값, 긴 기간은 원본 일별 집계를 사용하며 plot bucket을 만들기 전에 통계를 계산한다. 누락 기록은 누락 상태로 둔다. |
| 비동기 상태 | generation·취소 검사로 이전 성공·실패가 새 기간을 덮지 않게 한다. loading·empty·error를 구분한다. |
| 기여 요인 | 원래 심벌과 원점수, 가로 progress, 표시 전용 실제 적용 비중을 보여준다. 계산기와 기본 40/35/25 비중은 보존한다. |
| 설명 | 하나의 native DisclosureGroup에 정의와 기존 세 요인 설명을 모은다. 현재 기여 요인은 별도로 계속 노출한다. |
| 가독성 | 구간 숫자에 기존 불투명 `DS.Color.textSecondary`를 사용하고 행 전체의 흐림 처리를 제거한다. 원래 네 구간·심벌·안내·현재 단계의 굵은 제목과 배지를 보존한다. |

범례 전용 UI 검사는 native 내비게이션 바·탭 바를 제외한 viewport에서 각 결합 행 전체를 노출한다. 네 원래 구간과 Moderate에만 붙는 Current 배지를 검사하고 밝음·어두움 캡처를 수집한다. 기존 UI 검사는 기본 인자로 원래 helper 동작을 유지한다.

## 검증과 한계

서로 다른 실행과 소스를 합쳐 하나의 전체 통과로 표시하지 않는다.

| 실행 범위 | 실제 소스와 결과 |
|---|---|
| iPhone 기능 기준 검사 | `c763a55b`에서 6개 selector 통과. 히어로·원래 요인·5개 기간·이동·가시 통계·차트 drag/selection·단일 펼침·최대 접근성 글씨·어두운 화면을 검사했다. 두 가지 대비 스타일 수정 전의 결과다. |
| iPhone 대비 수정 후 검사 | `edad6355`에서 밝은 핵심 화면과 어두운 화면의 2개 selector 통과. 수정한 앱을 컴파일·실행했으며, 이 캡처만으로 네 구간 전체의 대비를 인증하지 않았다. |
| Duo 펼침 핵심 검사 | `edad6355`에서 native 1개 검사 통과와 유효한 PNG/AX 8쌍을 확보했다. pipeline은 별도로 cache 파일 변화에 따른 fingerprint 실패를 보존한다. 재현한 cache-only 소스 동등성 검토를 함께 기록하며 원래 실패 영수증을 성공으로 바꾸지 않는다. |
| Duo 펼침 범례 전용 검사 | `af8ab656`에서 `testAllLevelGuideIntervalsRemainVisibleInLightAndDarkAppearance` 1개 통과. 12개 strict paired checkpoint가 모두 유효하고 ACK를 받았다. 네 구간이 밝음·어두움에서 가리지 않고 노출됐다. 실제 최소 대비는 밝음 **6.097:1**, 어두움 **11.184:1**로, 구간 숫자의 P2를 닫았다. |
| 관련 unit 검사 | `af8ab656`에서 `ScoreRefreshServiceTests`, `CumulativeStressDetailViewModelTests`, `CumulativeStressDisplayTests`의 3개 suite·27개 검사 통과. 전체 unit suite 결과가 아니다. |
| Duo 접힘 핵심 검사 | `af8ab656`에서 동일 핵심 selector 1개 통과. 0° 자세 전후 확인, 활성 LCD 및 strict PNG/AX 8쌍의 ACK를 확보했다. 승인된 표준 진입점 예외 1회를 사용했고 이전 실행 전 오류 2회는 보존했다. |
| 최종 iPad 핵심 검사 | `af8ab656`에서 밝은 기본 글씨의 `testHeroFactorsAndUnifiedTrendAreVisible` 1개 통과. iPad 전체 상태·어두움·최대 글씨 검증으로 확대 해석하지 않는다. |

실제 main 병합 커밋 `468df320`의 T05 관련 코드·테스트 11개 경로는 `af8ab656`과 byte-identical임을 확인했다. 이는 해당 소스의 증거 재사용 근거이며, 캡처의 실제 커밋을 개별 PR 커밋으로 바꾸거나 새 main의 모든 소비자·테마·언어를 실행했다는 뜻이 아니다.

기존 화면 비교에는 실제 과거 캡처임을 명시한다. 과거 iPad·Duo 접힘은 9/Low, iPhone·Duo 펼침은 42/Moderate이며 일부 과거 표시 비중도 다르다. 이를 같은 입력의 전후 비교나 제품 계산식이 바뀐 증거로 해석하지 않는다.

Duo 접힘 캡처와 네 기기 실제 디자인맵 갱신을 완료했다. [실제 전후 비교](../../design/full-redesign-map/review/t05-cumulative-stress-native-2026-11-02/index.html)에 캡처별 소스·해시·과거 입력 차이를 기록한다. 현재 앱 소스 `0e0d8f6f`의 CI는 빌드 및 iOS 2,700개 검사·296개 suite를 통과했다. 현재 Watch 검사는 런타임 번들 누락으로 실행 전에 두 번 실패해 실패 상태로 보존했다. Watch의 455개 소스·리소스 입력과 설정이 동일하므로 PR 902의 213개 검사·29개 suite 통과 결과를 변경 없는 기능의 참고 증거로 재사용하고, 현재 iOS CI의 Watch 컴파일 성공을 함께 확인했다. 현재 Watch 검사 통과로 표시하지 않는다. 기존 공통 DotLine 날짜 축 glyph 문제는 TODO 158에 미해결로 유지한다. 승인된 animation-mask 진단 1회는 음성 결과였고 원본을 복원했으며 잔여 실행은 0회다. 기간 기능 검사의 성공으로 이 시각 결함을 해결한 것으로 표시하지 않는다.

## Prevention

- 모델의 기본 비중과 현재 적용 비중을 명확히 구분한다.
- plot 집계 전에 차트와 같은 반개구간의 원본 관측값으로 통계를 계산한다.
- 계층을 바꿀 때 원래 아이콘과 설명의 의미를 보존한다.
- 작은 글씨는 두 appearance의 실제 solid glyph와 주변 material을 검사한다. asset 이름이나 AX 존재만으로 가독성을 추정하지 않는다.
- 노출 증거를 수집할 때 반투명 내비게이션 영역을 제외한다.
- 원본 result bundle·자세 readback·PNG/AX 쌍·실패 이력을 폐기 가능한 worktree 밖에도 보관한다. 캡처 전에 스크립트 실행 권한을 확인한다.
- 동결된 실행 중 tracked 디렉터리에 진단용 Python module을 import하지 않는다. cache-only fingerprint 경고도 명시적이고 재현 가능한 소스 동등성 근거가 필요하며 성공 영수증으로 바꾸지 않는다.

## Lessons Learned

각 원본 데이터와 조작의 계약을 추적하면 시각적 강조를 높이면서 기존 동작을 보존할 수 있다. native 실행·소스 동등성·실제 픽셀 검토는 서로 다른 사실을 검증하므로 어느 하나로 다른 검증을 대신하지 않는다.
