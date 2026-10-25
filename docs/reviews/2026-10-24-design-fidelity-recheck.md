---
tags: [design, desert-horizon, fidelity, spacing, dashboard]
date: 2026-10-24
category: design
status: reviewed
---

# 디자인 개편 시안 일치 재검토

후속 변경: 사용자의 수정 후 화면 요청에 따라 Today 세 보조 카드를 `29e54f9a`에서 수정했다. [새 실제 화면과 검증 범위](../design/full-redesign-map/review/today-support-cards-2026-10-24/README.md)에서 iPhone 밝음·어두움·최대 글씨 결과를 확인한다. 아래는 수정 전 `f4d56f63`의 최초 검토 기록이다. Today 관련 P2-01~04·P3-01~02는 수정하고 iPhone에서 확인했으며 Wellness·Activity·Life의 나머지 세 항목은 이번 범위 밖으로 남긴다. 다른 기기의 검증을 완료로 바꾸지 않았다.

**판정: 시안과 부분 일치. 카드 내부 배치와 보조 정보가 남아 있어 디자인 일치 완료로 볼 수 없다.**

검토 소스는 `f4d56f63`이다. 사용자가 제공한 Today 하단 화면, 저장된 실제 앱 PNG, 현재 SwiftUI 소스를 [최종 4탭 시안](../design/theme-map/themes/dune-final-four-tab.html)과 [레이아웃 계약](../design/layout-map/desert-horizon-final.md)에 대조했다. 앱 코드는 수정하지 않았다. 아래 우선순위는 디자인 일치 검토 범위에 한정한다.

## 여백·정렬 수치

HTML의 px는 시안 내부 논리 좌표, SwiftUI의 pt는 앱 레이아웃 값이다. 첨부 이미지의 확대 배율을 역산해 실측한 값이 아니다.

| 항목 | 목표 시안 | 현재 앱 compact | 판정 |
|---|---|---|---|
| 본문 좌우 여백 | `.screen`: 16px | `DashboardView`: 16pt | 논리 배치 기준 일치. 첨부 화면의 카드 왼쪽·오른쪽 선도 카드 간 정렬됨 |
| 보조 카드 내부 패딩 | `.support`: 17px | `InlineCard`: 12pt | 시안보다 타이트함 |
| 보조 카드 모서리 | `.support`: 18px | `InlineCard`: 8pt | 시안보다 각짐 |
| 섹션 위계와 간격 | 제목 위 24px·아래 11px, 이어서 카드 | 카드 간 20pt, 해당 외부 섹션 제목 없음 | 단순 간격 차이보다 제목·카드 구조 차이 |
| 진행 정보 배치 | 같은 폭의 두 타일, 타일 간 9px | 48pt 링 두 개·링 항목 간 20pt·끝 `Spacer` | 오른쪽 공백이 커지고 목표 정보 누락 |
| 어두운 보조 카드 표면 | `--support: #302d2a` | `DesertCardSurface` 기본 `isSupporting=false`, `--card`에 해당하는 `#222321` 사용 | 보조 카드 표면 역할 불일치 |

근거: [시안 CSS](../design/theme-map/themes/dune-final-four-tab.html), `DUNE/Presentation/Dashboard/DashboardView.swift:99,140`, `DUNE/Presentation/Shared/Components/GlassCard.swift:635-643`, `DUNE/Presentation/Shared/Components/DesertPalette.swift:18-27`, `DUNE/Presentation/Shared/DesignSystem.swift:147-173`.

## 수정할 차이

### P2-01 · 오늘의 진행이 시안의 목표 카드로 구현되지 않음

- 코드: `DUNE/Presentation/Dashboard/Components/DailyProgressRingCard.swift:17-46,58-76`.
- 시안: `dune-final-four-tab.html:648`, CSS `345-349`.
- 현재는 작은 링과 값만 왼쪽에 나열하고 끝 `Spacer`가 남은 폭을 차지한다. 첨부 화면의 넓은 오른쪽 공백과 일치한다. 시안의 섹션 제목, 오늘 목표 헤더, 걸음·수면 이름, 각 목표와 진행 막대, 같은 폭의 두 타일이 없다.
- 조치: 실제 목표값을 연결한 두 항목 레이아웃으로 복원한다. 접근성 글씨에서는 한 열로 전환한다. 시안의 예시 걸음 수 자체를 앱 값으로 복사하지 않는다.

### P2-02 · 수면 차트의 최상단 축 숫자가 잘림

- 코드: `DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift:120-124`.
- 첨부 화면에서 최상단 `10` 눈금의 윗부분이 잘렸다. 저장된 `regular/dune/dark/T03.png`에서도 같은 현상이 보인다.
- 고정 80pt 차트와 외곽 `.clipped()`가 있고 축 레이블을 위한 상단 공간을 별도로 확보하지 않는다. 이것은 코드상 원인 후보이며, 정확한 inset 값은 렌더링으로 결정해야 한다.
- 조치: 차트 clipping 규칙을 유지하면서 축 레이블과 plot 상단 공간을 확보한다. 기본 글씨와 큰 글씨에서 눈금 전체가 보여야 한다.

### P2-03 · ‘7일’ 레이블과 실제 수면 그래프의 날짜 범위가 다름

- 코드: `DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift:94-117`, `DUNE/Domain/UseCases/CalculateSleepDeficitUseCase.swift:72-77`.
- 화면은 `7일`이라고 표시하지만 첨부 그래프는 금→토→일→월→화→수→목→금→토의 9개 날짜 눈금을 보인다. 중간 누락 날짜가 있어 막대 7개가 7일보다 넓게 퍼져 있다.
- 현재 구현은 최근 기록 7개를 고르고 날짜 축은 자동 범위를 사용한다. 달력상 최근 7일을 고정하지 않는다. Dashboard는 최대 14일 범위의 수면 자료를 전달한다(`DashboardViewModel.swift:905-923,950-966`).
- 조치: 최근 7개 달력 날짜로 범위를 정하고 누락은 누락으로 남기거나, 기록 개수·실제 날짜 범위에 맞는 레이블로 표시한다. 이 검토에서는 수면 부족 계산 자체를 변경하지 않았다.

### P2-04 · 회복·수면 카드의 핵심 정보가 시안과 다름

- 코드: `DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift:39-85,92-129`.
- 시안: `dune-final-four-tab.html:651`, 레이아웃 계약의 보조 카드 표.
- 시안은 지난 수면의 총 시간·날짜, 수면 단계 타임라인과 잠듦·기상 시각을 중심으로 주간 부족량을 보조로 둔다. 현재는 부족량 링과 7일 수면 막대가 중심이다. 첨부의 `52m`는 부족량이지만 바로 옆에 그 의미를 명시하지 않아 지난 수면 시간과 혼동할 수 있다.
- 조치: 지난 수면 요약을 먼저 제공하고 부족량에 명시적인 이름을 붙인다. 수면 단계 자료가 없는 경우에는 단계·시각을 만들어 넣지 않는다.

### P2-05 · Wellness 첫 카드의 7일 점수 흐름 누락

- 코드: `DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift:8,91-103`.
- 시안: `dune-final-four-tab.html:818`, 레이아웃 계약의 H01 보조 요소.
- 현재는 링·설명·상세로 바로 이어진다. `hourlySparkline`은 선언되어 있으나 사용하지 않는다. 시간별 데이터가 곧 7일 데이터라는 뜻은 아니다.
- 조치: 실제 7일 웰니스 점수 이력을 연결하고 기간·현재값을 표시한다. 자료가 부족하면 없는 추세를 생성하지 않는다.

### P3-01 · 보조 카드 패딩·모서리·표면이 기존 InlineCard 기준에 머묾

- 코드: `DUNE/Presentation/Shared/Components/GlassCard.swift:635-643`, `DesertPalette.swift:18-27`.
- Today의 진행·브리핑·회복 카드 모두 동일한 기존 InlineCard를 사용한다. 수치 차이는 위 표와 같다.
- 조치: DESERT HORIZON의 보조 카드 역할을 적용한다. 공통 InlineCard를 일괄 변경하면 다른 테마와 화면까지 영향받으므로 변경 소비자를 구분해야 한다. 시안의 17px를 DS의 4pt 격자에 맞춰 조정한다면 맵과 구현을 함께 합의·갱신한다.

### P3-02 · 브리핑의 제목·정보 위계가 축소됨

- 코드: `DUNE/Presentation/Dashboard/Components/TodayBriefCard.swift:21-27,36-103,109-149,177-197`.
- 시안: `dune-final-four-tab.html:649`.
- 실제 화면은 날씨 한 줄·코칭 문단·가운데 상세 링크다. 시안의 외부 섹션 제목, 카드 헤더, 구분된 날씨 요약과 오늘의 제안 행이 없다.
- 위치 미허용 상태에서 온도·지역이 없는 것은 정상적인 데이터 상태다. 시안의 맑음·온도와 다르다는 이유로 결함으로 계산하지 않았다.
- 조치: 권한 안내를 유지하면서 실제 자료 유무에 맞는 헤더와 제안의 위계를 복원한다. 현재 Dashboard가 사용하는 것은 `TodayBriefCard`이며, 별도의 `TodayCoachingCard`를 고쳐도 이 화면에 반영되지 않는다.

### P3-03 · Activity 주간 운동의 7일 시간 분포 누락

- 코드: `DUNE/Presentation/Activity/ActivityView.swift:712-720`, `DUNE/Presentation/Activity/Components/WeeklyStatsGrid.swift:15-25`.
- 시안: `dune-final-four-tab.html:704-712`, 레이아웃 계약의 시간별 변화 표현 규칙.
- 현재는 2×2 통계 카드만 배치하고 시안의 일별 운동 시간 막대와 기간 표시는 없다.
- 조치: 실제 주간 운동 자료로 해당 그래프를 연결한다. 다른 상세 화면의 차트 존재만으로 루트 카드 구현 완료로 보지 않는다.

### P3-04 · Life 주간 운동 성취의 요일별 수행 표식 누락

- 코드: `DUNE/Presentation/Life/LifeView.swift:737-793`.
- 시안: `dune-final-four-tab.html:842`.
- 현재 그룹 카드에는 목표별 진행 막대·연속 주 정보가 있으나 시안의 월–일 수행 표식이 없다.
- 조치: 실제 완료 날짜를 연결해 목표 진행률과 요일별 수행을 구분한다.

## 확인된 일치점과 검토 한계

- compact Today의 바깥 좌우 여백 16pt, 카드 간 같은 좌우 정렬은 일치한다. 카드 간 20pt 자체를 임의의 여백 오류로 보지 않았다.
- Activity의 근육 지도·주간 통계, Wellness의 점수·수면, Life의 습관·운동 성취는 넓은 화면의 두 열 구조가 있다.
- 저장된 캡처는 해당 `capture-index.json`의 revision·기기·시점에 대한 증거다. 현재 HEAD에서 새로 촬영한 이미지로 표시하지 않았다. 현재 소스와 함께 확인된 차이만 위 finding으로 올렸다.
- 저장된 iPad Life의 단색 상단 경계는 별도 확인 대상으로 남겼다. 이전 dirty worktree 캡처만으로 현재 결함으로 확정하지 않았다.
- 이번에는 새 빌드·테스트·시뮬레이터 캡처를 실행하지 않았다. 디자인과 소스의 대조이며 새 런타임 합격 판정이 아니다. 이 worktree에는 전용 시뮬레이터 등록 파일도 없다. Duo 펼침 Today의 기존 미검증 상태를 해제하지 않는다.
- 로컬 HTML을 브라우저로 여는 작업은 URL 정책이 `file:`을 허용하지 않아 중단했다. 시안 CSS·DOM 소스와 앱 PNG로 대조했고 브라우저 픽셀 비교로 보고하지 않았다.

## Apple 디자인 원칙 대조

이 표는 Apple 디자인 원칙의 로컬 reference를 적용한 정성 평가다. 앱 전체 HIG 인증이 아니다.

| 원칙 | 판정 | 근거 |
|---|---|---|
| Purpose | 미충족 | 진행 카드에 목표·이름이 없어 목표 대비 상태 파악이 약함 |
| Agency | 해당 없음 | 이번 검토에서 편집·취소·복구 흐름을 실행하지 않음 |
| Responsibility | 부분 충족 | 위치 권한 안내는 존재하나 안내 후 동작은 미실행 |
| Familiarity | 부분 충족 | 날씨·수면 아이콘은 유지, 시안의 일관된 보조 카드 구조는 미반영 |
| Flexibility | 부분 충족 | 넓은 화면 두 열 구현 확인, 이 화면의 큰 글씨·다국어 새 캡처는 미실행 |
| Simplicity | 미충족 | 부족량의 의미와 목표 정보가 생략되어 숫자 해석이 어려움 |
| Craft | 미충족 | 수면 축 잘림과 보조 카드 간격·역할 차이 |
| Delight | 부분 충족 | 사구·링의 테마 표현 유지, 움직임·Reduce Motion은 이번에 미실행 |

다음 수정의 완료 기준은 영향받는 T03·A01·H01·L01의 새 캡처에서 패딩·글자·축 잘림과 시안의 정보 구성을 확인하고 실제 화면맵을 갱신하는 것이다. 이번 문서는 P2 5건·P3 4건의 열린 디자인 차이를 기록하며, 이전 구현 검증 보고서의 빌드·테스트 통과를 시안 일치 통과로 해석하지 않는다.
