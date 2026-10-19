---
tags: [design, visual-system, themes, implementation-map, ios, watchos]
date: 2026-10-19
category: plan
status: in-progress
---

# DUNE 전체 디자인 개편 맵

[인터랙티브 구현 맵](index.html) · [8개 테마 방향 시안](../theme-map/index.html) · [4탭 레이아웃 맵](../layout-map/index.html) · [현재 실제 화면](../phone-design-map/actual/index.html)

이 맵은 테마 방향 시안 **8개 모두를 앱에 구현하기 위한 목표 상태, 실행 순서와 검증 상태**를 기록한다. 목표 시안과 실제 앱 화면을 분리하며, 검증 근거가 없는 조합을 완료로 표시하지 않는다. [2026-10-17 출시 UX·비주얼 명세](../2026-10-17-ux-visual-spec.md)는 WATER LILIES를 시안 전용으로 두었지만, 이번 요청에 따라 **WATER LILIES도 구현 대상**으로 확장한다. 건강 데이터와 주요 행동은 유지하되, 카드의 크기·순서·묶음·버튼 위치는 시안에 맞춰 다시 배치한다.

## 세 종류의 근거

| 자료 | 역할 | 완료 증거로 사용 |
|---|---|---|
| `theme-map/themes/*.html` | 8개 테마의 색·장면·표면·링·움직임 방향 | 불가. 시안이며 예시 건강 수치가 있다. |
| `layout-map/index.html` | T03·A01·H01·L01의 순서·행동·반응형 배치 | 불가. 구현 기준 시안이다. |
| `phone-design-map/actual/**` | 앱 빌드에서 얻은 기기별 실제 PNG와 출처 | 해당 빌드·화면·기기에 한해 가능. |

2026-10-19 현재 iPhone과 iPad의 4탭은 8개 테마 × 밝음·어두움으로 각각 64장씩 촬영했지만, 시안과 레이아웃을 대조하기 전의 **변경 전 기준 캡처**다. UI 테스트 통과는 화면 진입을 확인할 뿐 시안 일치를 증명하지 않는다. DUNE Today의 단일 히어로 배치를 수정해 iPhone 테스트 1건과 새 캡처로 확인했으나, 4탭 레이아웃 전체는 아직 미완료다.

## 작업 순서와 레이아웃 게이트

1. **DESERT HORIZON 4탭 배치:** 시안의 Today 전체 화면과 Activity·Wellness·Life 미리보기에서 카드 순서, 카드 안 묶음, 수치·설명·행동 위치를 먼저 맞춘다. 시안에 없는 실제 앱 섹션은 핵심 배치 아래로 이어 붙인다. 예시 수치는 실제 데이터로 바꾸고 빈 상태는 별도 확인한다.
2. **DESERT HORIZON 실제 대조:** 동일 크기 iPhone의 T03·A01·H01·L01을 새로 촬영해 시안과 나란히 본다. 배치가 다른 항목을 고친 뒤 레이아웃 게이트를 닫는다. iPad와 큰 글씨에서는 같은 정보 순서가 유지되는지 확인한다.
3. **시각 디테일:** 레이아웃 게이트가 닫힌 다음 능선의 형태·위치·움직임, 표면색, 링, 그래프, 타이포그래피, 간격을 시안에 맞춘다.
4. **나머지 7개 테마:** 완성된 정보 배치 위에서 테마별 시안의 장면·카드·장식과 화면별 변형을 각각 대조한다. WATER LILIES의 수련은 별도 형태 대조 대상으로 둔다.
5. **화면군·기기·접근성:** 4탭 시각 대조가 끝난 테마에 한해 상세·시트·운동과 Watch·Widget·Vision, iPad·Duo 및 접근성 상태를 검증한다.

현재 8개 테마는 시안 레이아웃 일치 게이트를 통과하지 못했다. 기존의 테마별 캡처 수는 이 게이트의 완료 수로 사용하지 않는다.

[DESERT HORIZON 4탭 중간 리뷰 캡처](review/desert-horizon-layout-2026-10-19/README.md)는 사용자에게 표시된 어두운 모드 시안과 같은 조건의 새 앱 화면을 담는다. 기존 `actual/regular` 인덱스의 기기는 현재 사용할 수 없어 중간 리뷰 캡처를 별도 보존했으며, 이 캡처를 전체 완료 증거로 계산하지 않는다.

| 화면 | DESERT HORIZON 시안의 첫 화면 배치 | 현재 남은 레이아웃 차이 |
|---|---|---|
| T03 Today | 짧은 상단 제목 → 하나의 어두운 카드 안에 점수·설명·24시간 흐름·근거·행동 → 별도 7일 추세 카드 | 카드의 순서와 묶음을 새로 촬영했다. 시간별 표본이 없는 빈 슬롯과 7일 그래프의 색·표면이 시안과 다르다. |
| A01 Activity | 요약 카드 안에 준비도 큰 수치·설명·운동 기록 행동 → 근육 지도 등 상세 영역 | 준비도와 행동을 단일 카드에 합치고 다시 촬영했다. 카드 하단 행동의 기기별 대비를 추가 확인한다. |
| H01 Wellness | 요약 카드 안에 수면 추세 막대·수면 시간·상세 행동 → 기존 건강 섹션 | 실제 수면 막대·시간·하단 능선을 배치하고, ‘수면 상세’가 수면 지표 상세로 열리는 UI 테스트가 통과했다. 신체 기록 버튼 위치를 추가 대조한다. |
| L01 Life | 요약 카드 안에 완료 수치·최대 3개 습관·오늘 행동 → 전체 습관 목록 | 상단 제목과 능선을 맞추고 첫 카드를 촬영했다. 전체 목록과 중복되는 정보량을 다듬어야 한다. |

## 검증 현황

| 범위 | 현재 근거 | 남은 확인 |
|---|---|---|
| iPhone 4탭 | 변경 전 기준 64/64 캡처, 화면 진입 테스트 통과 | DESERT HORIZON부터 시안의 카드 배치·순서·묶음·행동 위치를 재구현하고 새 캡처로 대조 |
| iPad 4탭 | 변경 전 기준 64/64 캡처, 화면 진입 테스트 통과 | iPhone 레이아웃 확정 후 같은 정보 순서와 읽기 폭 대조 |
| 상세·시트·운동 | iPhone 8테마 × 밝음·어두움 × 3화면 48/48 새 캡처, 흐름 테스트 8건 및 시트 대비 테스트 통과. 기본 화면맵의 변경된 상세·시트 17개 ID도 새 캡처로 갱신 | iPad·Duo 대표 상태 |
| Watch | 8개 테마의 홈·운동 목록·운동 중 24/24 새 실제 캡처, UI 테스트 16건 통과. 운동 카드에서 테마별 장식색을 구분해 확인 | 폰→Watch 선택값 실제 전파와 영향받은 기존 운동 상태 |
| Duo 접힘·펼침 | 기존 화면 경로와 캡처 절차 확인 | 각 자세의 활성 디스플레이 확인과 새 실제 화면 |
| Widget | 공유 저장소에 테마 선택값 반영, 빌드 통과 | 실제 위젯 화면과 테마별 대비 확인 |
| Vision | 8개 테마 선택·색상 연결, generic visionOS 빌드 통과 | visionOS 실행 기기에서 실제 화면·선택값 확인 |

이 표의 미확인 항목은 완료로 계산하지 않는다. 전체 판정은 아래 기기·상태 검증과 새 실제 캡처 조건을 모두 채운 뒤 갱신한다.

## 범위와 상속 규칙

- **8개 테마 × 4개 루트 = 32개 조합**을 첫 기준으로 삼는다. 먼저 DESERT HORIZON에서 화면 배치를 확정한 뒤, 각 테마 시안의 장면·표면·장식·링·그래프 표현을 적용한다. 실제 데이터와 CTA 목적지는 유지한다.
- [폰 화면 인벤토리](../phone-design-map/screen-inventory.md)의 108개 ID를 모두 추적한다. 진입 경로가 없는 W17·W18을 제외한 **106개 화면**은 T/A/W/H/P/L/S 화면군 규칙을 적용한다. 새 화면은 먼저 인벤토리에 추가한 뒤 이 맵을 재생성한다.
- 인벤토리의 실제 화면 출처는 각 기기별 통합 실제 화면맵에 연결한다. ‘이번 개편 촬영’은 2026-10-19 이후 캡처라는 뜻이고 완료 판정은 아니다. ‘기존 캡처’는 이번 개편 검증에 포함하지 않는다.
- 루트 바깥의 상세는 같은 모티프를 낮은 강도로, 시트·입력·운동 중 화면은 더 안정된 표면으로 잇는다. 카메라, 3D, 운동 수치, 타이머, 동의·권한 화면에서는 장식이 작업을 방해하지 않도록 한다.
- [Watch 운동 62개 상태](../../plans/2026-10-12-watch-workout-redesign.md)는 화면 구조를 다시 만드는 대상이 아니라 8개 테마의 색·표면·상태 대비와 설정값 전파를 확인할 대상이다. Widget과 Vision은 현재 테마 참조를 조사해 새 테마의 누락·fallback을 확인한다. 원본 테마 시안에 해당 플랫폼의 완성 시안은 없으므로 폰 시안을 실제 Watch/Widget/Vision 화면이라고 표시하지 않는다.

## 공통 구현 계약

1. **장면:** 각 테마의 모티프가 움직임을 멈춘 첫 화면에서도 식별된다. Today가 가장 풍부하고, Activity·Wellness·Life는 내용 읽기에 맞춰 강도를 낮춘다.
2. **표면:** 시안의 카드 크기와 내부 묶음을 먼저 맞춘다. 그 뒤 테마별 첫 히어로의 깊이와 보조 카드 표면을 맞춘다.
3. **링:** 시안의 테마별 호·광택을 재현한다. 건강 상태는 점수와 문구·접근성 레이블로도 전달하며 Reduce Motion에서는 완성된 정지 링을 보여 준다.
4. **그래프:** 실제 표본, 기간, 단위·축 또는 기준, 현재점을 읽을 수 있게 한다. 모티프 선과 다른 굵기·색을 쓴다. 표본이 부족하면 가짜 곡선을 만들지 않는다.
5. **행동·문구:** 상태 → 변화 → 근거 → 다음 행동 순서를 유지한다. 권한 거부, 기록 없음, 기준선 수집, 동기화 지연, 오류를 구분한다. CTA는 실제 목적지와 일치한다.
6. **움직임:** 장면과 링 광택만 낮은 진폭으로 지속한다. 본문·터치 영역·실데이터는 움직이지 않는다. Reduce Motion과 비활성 장면에서는 의미가 완전한 정지 상태다.

### 테마 토큰 경계

| 구현 역할 | 원본 시안에서 가져올 것 | 앱에서 유지할 것 |
|---|---|---|
| `sceneBase`·`sceneMid`·`sceneLight` | `theme-map/manifest.json`의 4색과 원본 HTML의 층 순서 | 밝음·어두움의 실제 합성 대비는 별도 측정 |
| `sceneMotif` | 테마별 능선·포말·안개·꽃·오로라·코로나·등고선·수련 형태 | 본문·터치 영역 밖의 장식 레이어 |
| `heroSurface`·`supportingSurface` | 원본의 히어로 깊이와 낮은 강도의 보조 카드 | `DS` 간격·반경·Dynamic Type 규칙 |
| `themeGlint` | 링 호 위의 작은 테마 광택 | `scoreExcellent` 등 건강 상태 호의 의미색 |
| `dataForeground` | 원본의 그래프 위계와 기간 표기 | 실제 데이터, 단위, 축, 빈 상태, 충분한 대비 |

시안의 hex 값을 건강 상태색이나 실데이터 색으로 직접 치환하지 않는다. 구현 색상은 `Shared/Resources/Colors.xcassets/`와 `AppTheme+View.swift`의 역할별 asset에 연결하고 합성 화면에서 조정한다.

보조 문구는 장식색과 분리한다. `*Sand`는 점수 단위·차트 축에 쓰이는 테마별 글자색이고, `TextSecondary`·`TextTertiary`는 카드·섹션의 공통 글자색이다. 두 계열 모두 실제 밝음·어두움 카드 위의 작은 글자에서 4.5:1 이상을 목표로 검증한다. 카드 위의 제목이나 설명을 SwiftUI의 낮은 불투명도 `.tertiary`만으로 처리하지 않는다.

주요 CTA의 테마 accent fill에는 `AppTheme.prominentButtonForegroundColor(for:)`를 쓴다. 현재 asset의 sRGB 값 기준 정적 전경·배경 대비는 밝음·어두움 16개 조합에서 최소 5.95:1이다. 이 계산은 실제 카드 합성이나 고대비 모드의 캡처 검증을 대체하지 않는다.

## 구현 단계와 담당 파일

| 단계 | 주요 파일 | 완료 조건 |
|---|---|---|
| 0. 현재 상태 고정 | `docs/design/phone-design-map/actual/**`, 테마별 캡처 테스트 | 테마마다 4탭의 변경 전 화면·상태·기기·테마 선택값을 기록한다. |
| 1. 공통 시각 계층 | `DUNE/Presentation/Shared/DesignSystem.swift`, `GlassCard.swift`, `ProgressRingView.swift`, `WaveShape.swift`, `AppTheme+View.swift` | 장면·표면·상태 링·그래프의 역할이 재사용 컴포넌트에서 분리된다. |
| 2. 기존 7개 테마 | `*WaveBackground.swift`, `ContourBackground.swift`, `Shared/Resources/Colors.xcassets/` | 각 원본 HTML의 고유 모티프가 T03/A01/H01/L01의 정지 화면과 움직임에서 확인된다. |
| 3. WATER LILIES | `DUNE/Domain/Models/AppTheme.swift`, `AppTheme+View.swift`, `WaveShape.swift`, 신규 배경·색상 asset, `ThemePickerSection.swift` | 새 케이스 선택·저장·복원이 되고 4탭·상세·시트에서 물빛·붓질 군집이 이어진다. 기존 저장값은 그대로 읽힌다. |
| 4. 전체 화면군·플랫폼 | 인벤토리의 T/A/W/H/P/L/S 소스, `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift`, Widget/Vision 테마 진입점 | 106개 진입 가능 화면을 화면군 규칙으로 대조하고 Watch 62상태 및 다른 타깃의 새 테마 참조를 확인한다. |
| 5. 검증·보존 | 관련 UI/단위 테스트, 실제 디자인맵, 테마맵 보존본·manifest·README | 새 빌드의 영향 화면만 다시 캡처하고 출처·시각을 남긴다. 캡처하지 못한 ID는 완료로 표시하지 않는다. |

기존 [4탭 레이아웃 구현 계획](../../plans/2026-10-17-ux-visual-rollout.md)은 정보 구조와 초기 수정의 기록이다. WATER LILIES의 새 앱 테마화와 전체 화면군 전개는 이 맵의 확장 범위다. 앱 코드 구현 작업을 시작할 때는 작업 단위별 계획과 영향 화면 ID를 구체화한다.

## 기기·상태 검증

| 범위 | 최소 확인 |
|---|---|
| iPhone | 4탭의 데이터 있음·없음, 주요 CTA, 상세 1개, 시트 1개를 테마별 밝음·어두움에서 확인. |
| iPad·Duo 접힘·펼침 | 영향받은 루트와 화면군 대표 화면을 새로 캡처. 읽기 폭, 두 열 전환, 접힘 경계, 상태 유지 확인. |
| 접근성 | 큰 글씨·VoiceOver·Increase Contrast·Reduce Motion에서 내용·동작·정지 장면 확인. 한국어·영어·일본어 긴 문구 대조. |
| Watch·Widget·Vision | 테마 선택값 전파와 색상 asset fallback, 의미색과 접근성 대비 확인. Watch 운동 상태의 기존 동작·수치·제어 유지. |

**완료 판정:** 각 테마가 정지 화면에서 구분되고, 4탭의 상태·변화·행동이 읽히며, 상세·입력·운동 흐름까지 같은 시각 언어가 이어진다. 영향받는 기기와 상태의 새 실제 캡처가 있고 주요 행동이 작동해야 한다. 시안과 실제 캡처는 끝까지 별도 자료로 유지한다.

## 갱신

`spec.json`의 테마 구현 계약, 원본 `../theme-map/manifest.json`, `../phone-design-map/screen-inventory.md`를 읽어 `index.html`을 생성한다.

8개 테마의 실제 4탭 캡처는 기본 DUNE 캡처 맵과 분리해 `actual/<기기>/<테마>/<밝음·어두움>/<화면 ID>.png`에 보존한다. 캡처의 테스트·시각·기기·소스 상태는 기기별 `actual/<기기>/capture-index.json`에 기록한다. 인덱스와 PNG가 모두 있는 칸만 인터랙티브 맵에 실제 화면 링크가 나타난다. XCTest 결과가 준비되면 다음처럼 수집한다.

```bash
python3 docs/design/full-redesign-map/collect-theme-captures.py regular <theme-matrix.xcresult> --dry-run
python3 docs/design/full-redesign-map/collect-theme-captures.py regular <theme-matrix.xcresult>
python3 docs/design/full-redesign-map/sync-default-roots.py regular --dry-run
python3 docs/design/full-redesign-map/sync-default-roots.py regular
python3 docs/design/full-redesign-map/build-full-redesign-map.py
```

캡처 테스트는 `ThemeMatrixUITests`의 기존 7개 테마와 `WaterLiliesThemeTests.testFourTabRootsInLightAndDark`를 사용한다. 동일한 결과를 iPad와 Duo 두 자세에서 수집할 때는 기기 인자를 `ipad`, `duo`, `duo-open`으로 지정하고 실제 자세·활성 디스플레이를 먼저 확인한다. 수집기는 기존 파일을 덮어쓰지 않는다. 같은 화면을 다시 캡처할 때는 이전 PNG와 인덱스 항목을 검토해 의도적으로 교체한다.

화면 일부만 변경되어 새 테스트에서 같은 이름의 PNG를 다시 얻은 경우에는 `--replace-existing`을 명시한다. 수집기는 같은 시뮬레이터의 기존 인덱스와 실제 파일이 모두 있고 새 첨부 시각이 더 늦을 때만 교체한다.

`sync-default-roots.py`는 새 테마 매트릭스의 DUNE 밝은 화면 4장을 기존 통합 실제 화면맵의 같은 기기·화면 ID에 반영한다. 네 캡처가 기존 이미지보다 새것인지 검사하고 테스트·결과 번들 출처를 보존한다. Watch는 `WatchThemeMatrixUITests`의 홈·전체 운동 목록·운동 중 화면 24장을 아래 명령으로 별도 보존하며, 이는 운동 62상태 캡처를 대체하지 않는다.
일부 루트만 다시 촬영한 경우 `sync-default-roots.py <기기> --screen-id A01`처럼 해당 ID만 갱신한다.

```bash
python3 docs/design/full-redesign-map/collect-watch-theme-captures.py <watch-theme-matrix.xcresult> --dry-run
python3 docs/design/full-redesign-map/collect-watch-theme-captures.py <watch-theme-matrix.xcresult>
```

`ThemeFlowMatrixUITests`는 8개 테마의 상태 상세·지표 비교 시트·운동 선택 화면을 밝음·어두움에서 확인한다. 48장의 새 iPhone 실제 화면은 루트 64장과 분리해 보존한다.

```bash
python3 docs/design/full-redesign-map/collect-theme-flow-captures.py <theme-flow-matrix.xcresult> --dry-run
python3 docs/design/full-redesign-map/collect-theme-flow-captures.py <theme-flow-matrix.xcresult>
```

```bash
python3 docs/design/full-redesign-map/build-full-redesign-map.py
python3 docs/design/full-redesign-map/build-full-redesign-map.py --check
```

원본 시안의 색·장면·움직임을 수정할 때는 [테마맵 갱신 방법](../theme-map/README.md#갱신-방법)을 먼저 따른다. 화면 배치나 상태를 구현한 작업에서는 [실제 화면 갱신 절차](../phone-design-map/README.md#화면-수정-시-갱신)로 새 PNG를 얻는다.
