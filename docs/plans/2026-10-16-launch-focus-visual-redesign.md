---
tags: [launch, product-scope, dashboard, activity, visual-hierarchy, healthkit, cloudkit]
date: 2026-10-16
category: plan
status: draft
topic: launch-focus-visual-redesign
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-11-launch-permission-deferral-stability.md
related_brainstorms:
  - docs/brainstorms/2026-02-16-dashboard-ux-redesign.md
  - docs/brainstorms/2026-03-07-activity-tab-hero-first-layout.md
---

# Implementation Plan: 출시용 핵심 흐름과 시각적 위계 개편

## Context

DUNE의 출시 약속을 **“오늘의 회복 상태를 이해하고, 적절한 운동을 바로 시작한다”**로 좁힌다. 현재 Today는 컨디션 점수 이후 수면·날씨·인사이트·요약·Q&A·지표가 연속 카드로 쌓이고, Activity에서는 운동 추천이 준비도·근육 지도·주간 통계·부상 위험 아래에 있다. 저장된 실제 화면 `T03`, `A01`에서 핵심 행동보다 정보 카드가 먼저 눈에 들어온다. 이는 화면 검토에 따른 제품 판단이며 사용자 선호나 사용률을 측정한 결과는 아니다.

출시 검토에서 두 무반응 행동도 확인됐다. Today의 “Start this workout”은 빈 클로저이고, “Log Weight”는 기존 체중 지표가 없으면 아무 일도 하지 않는다. 성공한 HealthKit 조회 결과가 비어 있어도 권한 거부 안내를 보여 준다. 또한 현재 CloudKit 설정과 동기화 모델은 개인 건강 정보의 iCloud 저장을 금지하는 [Apple App Review Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/)와 충돌할 가능성이 높다. Apple의 최종 해석을 단정하지 않되 이 문제를 제출 전 게이트로 둔다.

## Requirements

### Functional

- Today 첫 화면에서 상태, 주된 근거, 다음 행동을 한 번에 이해할 수 있어야 한다.
- “운동 시작” 및 첫 체중 기록 등 노출된 버튼은 실제 완료 가능한 경로로 이어져야 한다.
- 권한 거부, 권한 허용 후 기록 없음, 기준선 수집 중, iCloud 대기 상태를 구별해야 한다.
- 출시 화면에서 보조 기능의 노출을 줄여도 기존 습관·자세·운동·체성분 기록을 삭제하거나 접근 불가능하게 만들지 않는다.
- 개인 건강 정보의 CloudKit 저장 경로를 제출 전에 해결한다.

### Non-functional

- 기본 테마의 명도 대비, Dynamic Type, VoiceOver, Reduce Motion을 유지한다.
- 한국어·영어·일본어 문자열과 기존 deep link·알림 목적지를 보존한다.
- 변경된 화면은 영향받는 기기와 상태에서 새로 캡처해 실제 디자인맵을 갱신한다.

## Proposed Release Surface

| 영역 | 출시 노출 | 구체적 처리 |
|---|---|---|
| Today 컨디션과 추천 행동 | 전면 유지 | 점수 시각화, 원인 최대 2개, 주요 행동 1개를 첫 화면의 중심에 배치 |
| Activity 운동 기록·추천 | 전면 유지 | 준비도 바로 아래에 추천/운동 시작 경로; 2D 근육 회복 지도는 시각적 보조 정보로 유지 |
| 수면·HRV·RHR 상세 | 유지 | Today에서는 요약만, 깊은 분석은 상세 화면으로 이동 |
| Briefing·Daily Digest·인사이트 | 통합 | 시간대에 맞는 **하나의** 요약 블록만 Today에 표시; 중복 빠른 버튼은 제거 |
| Health Q&A | 2차 진입으로 이동 | 첫 화면의 상시 카드와 빠른 버튼을 제거하고 관련 상세 또는 설정에서 접근; 지원 불가 기기에서는 약속하지 않음 |
| 3D 근육 지도 | 상세에 유지 | Activity 첫 화면의 직접 아이콘을 숨기고 2D 지도 상세에서만 진입 |
| 자세 평가·실시간 자세 | 2차 진입으로 이동 | Wellness의 주요 카드/추가 메뉴에서는 뒤로 보내되 기존 기록과 진입 호환성 유지 |
| Life 습관 | 결정 대기 | 독립 탭을 Wellness의 보조 목적지로 옮기는 3탭 안을 검증. 기존 습관·알림·딥링크 영향 확인 전에는 탭 삭제 금지 |
| 테마 선택 | 기본 노출 축소 | 출시 기본 테마에 집중하고 테마 선택은 설정에만 둔다. 저장된 테마 값은 계속 읽는다. 현재 논의한 8개 방향 시안은 [테마 맵](../design/theme-map/index.html)에 별도 보존한다. |
| iCloud 건강 정보 동기화 | 출시 게이트 | 건강 정보의 업로드를 중단하는 local-first 안 또는 Apple의 명확한 심사 판단이 필요. 기존 사용자 데이터 보존 경로를 먼저 정의 |

**결정 조건:** Life 탭 이동과 자세 기능의 노출 축소는 사용자 사용률 자료가 없으므로 가설이다. 핵심 사용자 과업 5~8건의 관찰 또는 제한된 TestFlight 피드백으로 운동 기록, 습관 확인, 자세 기록의 진입 성공 여부를 확인한 뒤 확정한다. 데이터 모델 삭제는 이번 계획에 포함하지 않는다.

## Target Screen Hierarchy

### T03 Today · 일반 iPhone

```text
상단: Today + 알림·설정
큰 컨디션 시각화: 점수/상태 + “오늘은 어떤 강도로 움직일지” 한 문장
근거: HRV · 수면/휴식 중 의미 있는 변화 최대 2개
주 행동: “추천 운동 보기” 또는 “운동 시작” (실제 목적지에 맞게 명명)
보조 시각화: 7일 추세 또는 회복 지도 미리보기 중 1개
접힌 상세: 수면·지표·날씨·인사이트
```

단일 추천 운동을 곧바로 시작할 수 없으면 “Start this workout”이라는 문구를 유지하지 않는다. Activity의 추천 위치로 이동시키고 “추천 운동 보기”로 표기한다. 시작 동작을 구현할 수 있을 때만 직접 시작 CTA를 쓴다. 데이터가 없으면 점수 대신 수집 진행 상태와 수동 운동 기록 경로를 보여 준다.

### A01 Activity · 일반 iPhone

```text
준비도 시각화 + 상태 한 문장
추천 운동/운동 시작 버튼 및 이어하기
2D 근육 회복 지도
최근 운동
접힌 분석: 주간 통계·볼륨·위험·리포트·기록
```

iPad에서는 준비도·추천을 주 패널, 근육 지도와 분석을 보조 패널로 배치한다. Duo 접힘·펼침에서는 주요 행동이 접힘 전환 후에도 첫 화면에 남아야 한다. 시각 요소는 정보를 압축하는 데 쓰고 차트와 장식을 동시에 늘리지 않는다. Apple의 [iOS 디자인 지침](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios/)과 [시각적 위계 지침](https://developer.apple.com/design/human-interface-guidelines/layout/)을 기준으로 한다.

## CDO Visual & UX Audit · 첫 번째 방향(Today 중심)

### 증거와 판정 범위

- [일반 iPhone T03](../design/phone-design-map/actual/regular/images/T03.png), [iPad T03](../design/phone-design-map/actual/ipad/images/T03.png), [Duo 펼침 T03](../design/phone-design-map/actual/duo-open/images/T03.png)의 저장된 **밝은 화면**과 현재 SwiftUI 소스를 비교했다. 캡처는 영어·mock fixture의 특정 시간대 상태이며 모든 실사용 상태를 대표하지 않는다.
- 제품 강점은 따뜻한 모래색 배경, 유기적인 파형, 점수 링의 일관된 형태다. 개선 목표는 장식을 더하는 것이 아니라 **데이터의 의미와 다음 행동을 시각적으로 더 뚜렷하게 만드는 것**이다.
- 점검 근거는 Apple의 [디자인 원칙](https://developer.apple.com/design/human-interface-guidelines/design-principles/), [타이포그래피](https://developer.apple.com/design/human-interface-guidelines/typography/), [레이아웃](https://developer.apple.com/design/human-interface-guidelines/layout/), [접근성](https://developer.apple.com/design/human-interface-guidelines/accessibility/), [재질](https://developer.apple.com/design/human-interface-guidelines/materials/)이다. 아래의 새 크기·간격 제안은 Apple의 강제 수치가 아니라 DUNE의 설계안이다.

### Apple의 여덟 디자인 원칙 대조

| 원칙 | 판정 | 화면에 나타난 근거와 개편 방향 |
|---|---|---|
| Purpose | 부분 충족 | 상태 점수는 즉시 보이지만 행동은 첫 화면에서 보이지 않는다. “오늘 어떻게 움직일까”를 점수 옆 문장과 CTA로 연결한다. |
| Agency | 미충족 | `Start this workout`의 빈 동작과 첫 체중 기록의 무반응은 선택의 결과를 없앤다. 모든 주요 버튼을 유효한 목적지에 연결한다. |
| Responsibility | 미충족 | 건강 데이터가 비어 있으면 원인과 관계없이 권한 안내가 나온다. 권한·기록 없음·기준선 수집을 다른 화면 상태로 설명한다. iCloud 저장 범위도 정확히 알린다. |
| Familiarity | 부분 충족 | 시스템 탭과 내비게이션은 익숙하다. 그러나 큰 히어로 전체가 상세 링크인 점은 외형만으로 분명하지 않다. 상세 화살표/레이블을 주고, 주요 행동은 별도 버튼으로 분리한다. |
| Flexibility | 미충족 | 히어로 `CONDITION`은 고정 9pt이며 iPad의 넓은 카드 안에 내용이 한쪽에 몰린다. Dynamic Type과 사용 가능한 너비에 따라 수직/2열 구성을 바꾼다. |
| Simplicity | 미충족 | Today에 비슷한 톤의 카드와 중복 진입점이 누적된다. 첫 화면에는 한 가지 결정과 한 가지 행동만 강조한다. |
| Craft | 부분 충족 | 파형·원형 링·모서리 토큰은 통일돼 있다. 반투명 카드의 다층 색과 약한 보조 문구가 정교한 정보 위계를 흐린다. 곡선과 재질에 역할을 부여한다. |
| Delight | 부분 충족 | 파형과 링은 차분한 정체성을 만든다. 여러 카드의 순차 등장과 장식 효과는 완료 가능한 행동을 강조할 때만 사용한다. |

### 시각적 문제와 구체적 설계 기준

| 우선 | 항목 | 현재 관찰 | 첫 번째 방향의 설계 기준 | 확인 방법 |
|---|---|---|---|---|
| P1 | 시선 흐름 | T03에서 `Today` 제목과 큰 히어로 뒤에 수면·인사이트·요약·Q&A가 같은 무게로 반복된다. 추천 행동은 시간대에 따라 더 아래에 있거나 보이지 않는다. | 첫 시선은 **상태 문장과 발광 링**, 두 번째는 **히어로 안의 시간대 그래프와 원인 두 개**, 세 번째는 **채워진 주 버튼**. 기존 `ConditionHeroView`의 시간별/7일 스파크라인은 제거하거나 축소하지 않고 히어로 안에서 충분한 폭과 대비를 준다. 히어로와 CTA를 한 영역으로 묶고 일반 카드와 충분한 여백으로 분리한다. | 5초 관찰에서 사용자가 “오늘 상태/변화/이유/다음 행동”을 말할 수 있는지 확인 |
| P1 | 글자 크기 | `ConditionHeroView`의 `CONDITION`은 `.system(size: 9)` 고정, 목표·시간 표시는 `.caption2`다. 점수에는 `.minimumScaleFactor(0.5)`가 걸려 있다. | 핵심 라벨은 Dynamic Type의 `.caption` 이상으로 올리고, 핵심 점수·상태는 축소보다 줄바꿈/수직 배치를 우선한다. 정보 설명은 `.body` 또는 `.subheadline`, 보조 메타데이터만 `.footnote`/`.caption`을 사용한다. | 기본·접근성 최대 글자 크기, 한국어·영어·일본어에서 잘림/겹침 없음 |
| P1 | 대비 | 저장 캡처의 보조 글자는 밝은 재질 위에서 흐리게 보인다. 명명된 색만 계산하면 `TextSecondary`/`CardBackground` 밝은 모드 3.87:1, `AccentColor`/`CardBackground` 2.54:1이다. 이는 실제 material·gradient 합성 전 수치다. | 작은 정보 글자에 약한 브랜드색을 쓰지 않는다. 우선 읽을 텍스트는 의미 기반 고대비 색으로, 브랜드색은 링·아이콘·큰 강조 면에 사용한다. 대비 증가 설정용 변형도 준비한다. | 실제 렌더링에서 작은 일반 글자 4.5:1, 큰/굵은 글자 3:1 이상을 Accessibility Inspector로 측정; 밝음·어두움 각각 확인 |
| P1 | 행동의 형태 | 히어로는 큰 카드 전체가 상세 링크인데 외형은 정보 카드와 같다. `ExerciseIntelligenceCard`의 행동은 낮은 채도의 얇은 배경으로 놓인다. | 카드 전체 탭과 내부 CTA를 중첩하지 않는다. “점수 자세히”는 보조 링크, “추천 운동 보기”는 구분되는 채운 버튼으로 만든다. 버튼의 동사는 실제 목적지와 일치시킨다. | 주 버튼의 탭 영역 44×44pt 이상, VoiceOver 명칭과 실제 행동 일치 |
| P2 | 곡선과 카드 | `HeroCard`는 compact 20pt/regular 24pt, `StandardCard`는 12/16pt, `InlineCard`는 8/12pt의 위계를 이미 갖는다. 그러나 비슷한 반투명 카드가 연속되며 모두 같은 중요도로 읽힌다. | 기존 반경 토큰은 유지하고 **히어로 1개에만 가장 큰 곡선·색면**을 준다. 보조 지표는 중간 카드, 이력은 작은 행으로 표현한다. 모래 능선은 Today·Activity·Wellness·Life 각 루트 화면 배경에서 이어지는 시각 언어로 사용하고, 개별 카드마다 반복하지 않는다. | 카드 윤곽을 흐리게 보아도 주·보조·이력 세 계층이 구분되는지 확인 |
| P2 | 넓은 화면 | iPad와 Duo 펼침 T03은 히어로가 화면 전체 폭으로 늘지만 내용은 왼쪽에 남고 오른쪽 대부분이 비어 있다. | 히어로의 텍스트 폭을 읽기 좋은 범위로 제한한다. 충분한 폭에서는 오른쪽에 **의미 있는** 7일 추세 또는 다음 행동 영역을 두고, 데이터가 없으면 카드 폭 자체를 제한한다. 숫자와 CTA를 서로 먼 양끝에 놓지 않는다. | iPad 창 크기 변화, Duo 접힘/펼침에서 같은 정보 순서와 가까운 시선 이동 유지 |
| P2 | 시간대 일관성 | 저장된 야간 T03은 `0m` 수면 옆에 `Well Rested`가 보인다. fixture 조합일 수 있어 제품 버그로 단정할 수는 없다. | 시간대·수면 데이터 유무에 따라 문구와 시각 상태를 함께 설계한다. 데이터가 없으면 긍정 상태색·완료 링 대신 “아직 기록 없음”을 사용한다. | 아침/낮/밤, 기록 있음/없음의 실제 캡처 조합 확인 |
| P3 | 움직임 | 히어로 점수, 링, 카드 등장, 배경 파형에 각각 애니메이션이 있다. `DashboardView`는 0~12 인덱스 순차 등장을 사용한다. | **지속 움직임은 네 탭의 모래 능선과 Today 상태 링에 집중한다.** 기존 `DesertDuneShape`처럼 능선의 위상이 한 방향으로 계속 진행하며, 먼 능선은 느리고 가까운 능선은 조금 빠르다. 탭마다 진폭만 조절하고 리듬은 공유한다. 링은 현재 Desert Warm의 금빛→상태색 끝점을 유지하면서 짧은 진입 채움 뒤 빛의 하이라이트가 호를 따라 순환하고 광택이 미세하게 호흡한다. 카드의 반복 등장은 줄인다. Reduce Motion에서는 완성된 링과 정적 능선을 보여 준다. | 4탭 화면 녹화에서 능선이 끊김 없이 흐르고 링 광택이 점수·텍스트 가독성을 해치지 않는지 확인; Reduce Motion 켬/끔 비교 |

대비 수치는 `Shared/Resources/Colors.xcassets`의 sRGB RGB 값으로 WCAG 상대 휘도 공식을 적용한 **정적 색상쌍 사전 검사**다. 재질, 불투명도, 그라데이션, 배경 이미지가 합성된 실제 픽셀의 접근성 통과/실패 판정은 아니다. Apple의 접근성 지침에서 iOS/iPadOS 기본 글자 목표는 17pt, 제시된 최소 크기는 11pt이며, 터치 컨트롤의 권장 크기는 44×44pt다. 이 숫자는 개별 카드 디자인에 일률적으로 적용할 강제 레이아웃 치수가 아니라 검증 기준이다.

### Today 시각 설계안 · 첫 접힘 화면

```text
Today                     알림 · 설정

┌ 상태 영역 ────────────────────────────────┐
│  84  회복 상태 좋음                        │
│      평소보다 HRV가 높고, 잠은 충분했어요. │
│  오늘의 변화  ──╮╭──╮──╲─●  현재 점수     │
│  [ HRV ↗ 7 ]   [ 수면 7시간 10분 ]        │
│                                            │
│  [ 추천 운동 보기                 → ]      │
└────────────────────────────────────────────┘

7일 상태 추세  ───╮──╯─╮──  자세히
오늘의 보조 정보  수면 · 운동 기록 · 지표
```

- 문구는 차분하고 과장되지 않게 쓴다. 예시 수치·문장은 실제 데이터가 있을 때만 표시한다.
- `ConditionHeroView` 내부의 숫자·설명·버튼은 별도 접근성 요소로 제공하고, 링에만 의존하지 않는다. 현재의 히어로 전체 `NavigationLink`는 CTA와 겹치므로 컨테이너/상세 링크를 분리한다.
- 첫 접힘 화면의 실제 높이는 기기·Dynamic Type에 따라 다르다. 위 도식은 레이아웃 목표이지 픽셀 고정 시안이 아니다.
- 현재 `T03`은 야간 상태 한 장이므로 낮의 Quick Actions/Today Brief/추천 카드와 비어 있는 상태를 별도로 확인해야 한다. 밝은 화면만으로 어두운 모드를 통과 처리하지 않는다.

## Approach

먼저 출시 위험과 무반응 경로를 고친다. 다음으로 카드의 생성 로직을 삭제하지 않고 Today와 Activity의 **노출 순서 및 중복 진입점**을 조정한다. 보조 기능은 상세 목적지로 옮겨 기존 기록과 알림 경로를 보존한다. 화면 재설계가 검증된 뒤에만 미사용 코드 제거를 별도 작업으로 다룬다.

### Alternative Approaches Considered

| Approach | 장점 | 단점 | 결정 |
|---|---|---|---|
| 기능과 SwiftData 모델 즉시 삭제 | 표면적 코드량 감소 | 기록 손실·마이그레이션·딥링크 파손 위험 | 기각 |
| 현재 4탭/모든 카드 유지, 색과 애니메이션만 확대 | 구현이 빠름 | 핵심 행동이 계속 묻힘 | 기각 |
| 주요 행동을 전면 배치하고 보조 진입만 단계적으로 축소 | 가치 전달과 데이터 보존을 함께 검증 가능 | 라우팅·캡처 검증 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/App/DUNEApp.swift` 및 `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | investigate/modify | CloudKit에 저장되는 모델 경계와 local-first 전환 방안 결정 |
| `DUNE/Data/Services/HealthSnapshotMirrorStore.swift`, `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift` | investigate/modify | 건강 스냅샷 CloudKit 업로드 차단, 기존 로컬 데이터 보존 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift`, `DUNE/Presentation/Settings/SettingsView.swift` | modify | 실제 동기화 범위와 상태를 정확히 설명 |
| `DUNE/App/ContentView.swift`, `DUNE/App/AppSection.swift` | modify | Today→Activity 목적지 연결; 3탭 안 채택 시 습관 라우팅 보존 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | 히어로·CTA·요약 순서, 중복 진입 제거, 빈 상태 분기 |
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift`, `ExerciseIntelligenceCard.swift`, `QuickActionsRow.swift` | modify | 점수와 행동의 시각적 위계 및 실제 버튼 동작 |
| `DUNE/Presentation/Shared/DesignSystem.swift`, `DUNE/Presentation/Shared/Components/GlassCard.swift`, `Shared/Resources/Colors.xcassets/**` | conditional modify | 첫 화면의 글자·대비·표면·곡선 토큰을 실제 검증 결과에 맞게 조정 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | modify | 권한/기록 없음/기준선 상태 분리 |
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | 추천과 시작 경로를 준비도 바로 아래로 이동, 3D 지도 진입 축소 |
| `DUNE/Presentation/Wellness/WellnessView.swift`, `DUNE/Presentation/Life/LifeView.swift` | conditional modify | 자세·습관의 2차 진입 및 보존 경로 |
| `DUNETests/DashboardViewModelTests.swift`, `DUNETests/LaunchExperiencePlannerTests.swift`, 관련 UI 테스트 | modify | 빈 상태와 핵심 행동의 회귀 검증 |
| `docs/design/phone-design-map/screen-inventory.md`, `actual/**` | modify | 영향받는 T03·A01·L01 및 변경된 상세 화면의 새 실제 캡처 |

## Implementation Steps

### Step 1: 출시 정책 및 데이터 경계 확정

- **Files**: CloudKit 설정·스키마·미러 저장소·동의/설정 화면.
- **Changes**: CloudKit에 들어가는 모든 개인 건강 필드를 목록화한다. local-first 출시를 기본안으로 삼고 이미 동기화를 켠 사용자 데이터의 로컬 보존·전환 절차를 정한다. Apple의 별도 판단을 선택한다면 서면 근거를 출시 기록에 남긴다.
- **Verification**: 신규 설치와 기존 데이터 전환에서 건강 필드가 iCloud로 업로드되지 않는지 확인. 동의·설정 문구가 실제 저장 범위와 일치.

### Step 2: 핵심 행동과 빈 상태 복구

- **Files**: `ContentView`, `DashboardView`, `DashboardViewModel`, `QuickActionsRow`, `ExerciseIntelligenceCard`, 체성분 입력 경로.
- **Changes**: 추천 CTA를 실제 Activity 목적지로 연결하거나 행동에 맞는 이름으로 수정. 첫 체중 기록은 기존 metric 없이 입력 폼에 진입. 권한 거부와 기록 없음, 기준선 대기를 분기.
- **Verification**: 첫 설치/권한 허용·거부/체중 기록 없음/추천 있음·없음 각각에서 무반응 버튼 0개. 관련 단위·UI 테스트.

### Step 3: Today·Activity 시각적 위계 재배치

- **Files**: Today·Activity, 관련 카드 컴포넌트, 필요한 경우 공통 디자인 토큰·색상 asset.
- **Changes**: 위 Target Screen Hierarchy와 CDO audit의 글자·곡선·대비 기준대로 상단 정보와 행동을 재구성. Briefing·Digest·인사이트 중복을 한 요약 블록으로 조정. 복잡한 분석은 기존 상세 화면으로 이동. 히어로 전체 링크와 내부 CTA를 별도 요소로 분리.
- **Verification**: 첫 화면에서 상태와 행동이 스크롤 없이 보임. 실제 렌더링 텍스트 대비, 기본/최대 Dynamic Type, 밝음/어두움, VoiceOver, Reduce Motion. 일반 iPhone·iPad·Duo 양 자세의 영향 화면 실제 캡처.

### Step 4: 보조 기능 노출 축소 결정

- **Files**: `AppSection`, `ContentView`, `WellnessView`, `LifeView`, 관련 알림·딥링크 라우터.
- **Changes**: 사용성 근거가 확보되면 Life의 독립 탭을 Wellness의 보조 진입으로 이동. 3D 지도와 자세 분석의 첫 화면 진입을 상세로 이동. 영속 데이터와 기존 목적지 처리 유지.
- **Verification**: 기존 습관 알림, 자세 기록, 3D 상세와 모든 저장 기록 접근 가능. 진입 경로가 사라진 화면은 인벤토리에서 실제 상태대로 수정.

### Step 5: 출시 검증과 디자인맵 동기화

- **Files**: 관련 테스트 및 `docs/design/phone-design-map/actual/**`.
- **Changes**: 영향받는 화면 ID를 기기별로 확인하고 새 빌드의 PNG를 수집. 앱 심사에 필요한 개인정보·지원 경로·권한 설명을 점검.
- **Verification**: 관련 테스트 통과, 실제 기기 핵심 흐름 점검, 새 PNG의 글자 잘림/겹침/대비 검토. 기존 PNG를 새 화면의 증거로 재사용하지 않음.

## Edge Cases

| Case | Handling |
|---|---|
| HealthKit 허용했지만 데이터 없음 | 권한 재요청 대신 기준선 준비와 수동 운동 기록 제시 |
| HealthKit 거부 | 설정 이동과 앱에서 가능한 기능을 명확히 표시 |
| 추천이 휴식일/없음 | 시작 CTA를 숨기고 회복 또는 직접 기록 행동 표시 |
| 기존 체중 기록 없음 | 체성분 입력 폼으로 직접 진입 |
| iCloud 동기화가 이미 켜진 테스트 사용자 | 로컬 기록 확인·보존을 먼저 수행; 데이터 삭제나 일괄 초기화 금지 |
| Life 탭을 숨긴 뒤 습관 알림 열기 | 라우터가 Wellness의 습관 화면으로 연결 |
| Apple Intelligence 미지원 | Q&A를 주요 행동으로 제시하지 않음 |

## Testing Strategy

- **Unit**: 권한·데이터 상태 구분, 추천 목적지 정책, 기존 저장값·라우팅 보존.
- **UI**: Today 추천→Activity 시작, 첫 체중 입력, 데이터 없는 첫 실행, 습관 알림 목적지.
- **Manual**: 실제 기기 HealthKit 권한과 CloudKit 전환, 밝음/어두움·큰 글자·VoiceOver, iPhone/iPad/Duo 화면.
- **Visual QA**: T03의 아침/낮/밤과 데이터 있음/없음, A01의 추천 있음/휴식일을 캡처한다. Accessibility Inspector로 실제 재질 위 텍스트 대비와 버튼 영역을 확인한다.
- **Evidence**: `docs/design/phone-design-map/README.md`의 「화면 수정 시 갱신」 절차. 초기 영향 화면은 T03·A01, 3탭 안 채택 시 L01 및 탭 내비게이션이 보이는 화면 전체를 다시 판정.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| CloudKit 건강 정보가 심사 정책과 충돌 | high | critical | Step 1을 출시 게이트로 처리하고 업로드 경계 검증 |
| 탭 축소로 습관/자세 기능 발견성 하락 | medium | high | TestFlight 과업 관찰 후 결정, 기존 목적지 유지 |
| HealthKit 기록이 적은 사용자에게 점수 중심 화면이 비어 보임 | high | medium | 기준선 진행 시각화와 수동 행동 제공 |
| 카드 재배치가 iPad/Duo 레이아웃을 깨뜨림 | medium | medium | 영향 기기만 실제 캡처하고 화면별 확인 |
| CloudKit 축소가 기존 데이터 접근에 영향 | medium | critical | 데이터 보존·전환 시나리오를 구현 전 확정 |

## Success Criteria

- 첫 화면에서 컨디션 또는 기준선 상태와 **작동하는** 다음 행동을 스크롤 없이 찾을 수 있다.
- 핵심 라벨이 고정 9pt로 남지 않고, 작은 텍스트/주요 버튼이 실제 화면의 대비·탭 영역 검증을 통과한다.
- 출시 첫 화면에는 동일 기능으로 가는 중복 카드/빠른 버튼이 없다.
- 핵심 흐름의 보이는 버튼 중 빈 콜백이 없다.
- 건강 데이터가 없거나 권한이 없는 사용자도 앱 안에서 할 수 있는 다음 행동을 받는다.
- 개인 건강 정보의 iCloud 저장 문제에 대한 구현 또는 Apple의 명확한 판단이 기록되기 전에는 제출하지 않는다.
- 실제 변경 화면의 디자인맵 캡처가 새 코드와 일치한다.

## Confidence Assessment

- **Overall**: medium
- **Reasoning**: 무반응 버튼, 카드 순서, CloudKit 데이터 경계는 코드로 확인했다. 기능의 실제 사용률·전환율, App Review의 최종 판단, 실기기 접근성 결과는 아직 없다. Life 탭 이동과 자세 기능 축소는 이 근거를 얻기 전까지 가설로 유지한다.
