---
tags: [ios, ipados, iphone-duo, watchos, screen-capture, design-map]
date: 2026-10-12
category: plan
status: in-progress
---

# DUNE 전체 디자인맵

[폰·패드·Duo·Watch 통합 디자인맵 열기](actual/index.html)

[4탭 레이아웃 기준맵](../layout-map/index.html)은 화면 정보 순서와 반응형 배치의 시안이다. 이 문서의 PNG는 실제 앱 캡처다.

[폰·패드·Duo의 같은 화면 비교](actual/compare.html)

[테마 방향 시안 8개와 공통 시각 언어 맵](../theme-map/index.html)은 별도로 보존한다. 테마 맵은 구현된 앱 화면의 캡처가 아니다.

통합 맵에서 폰·패드·Duo·Watch는 **현재 구현된 앱 화면을 시뮬레이터에서 실제로 열어 캡처**한 결과를 보여준다. Watch의 기존 운동 재작업 디자인 보드는 실제 캡처와 별도 구역에 있다. 자료의 성격은 각 갤러리에 명시했다. [폰 화면 인벤토리](screen-inventory.md)의 108개 항목 중 W17·W18은 현재 앱 진입 경로가 없는 소스 잔여 View이므로 캡처 대상에서 제외한다. 일반 iPhone 105/105, iPad 106/106, Duo 접힘 105/105, Duo 펼침 105/105 화면을 실제 이미지로 채웠다.

| 기기 | 실제 화면 갤러리 | 증거 |
|---|---|---|
| 일반 iPhone | [캡처 맵](actual/regular/index.html) | [화면별 캡처 출처](actual/regular/capture-index.json) |
| iPad | [캡처 맵](actual/ipad/index.html) | [화면별 캡처 출처](actual/ipad/capture-index.json) |
| iPhone Duo · 접힘 | [외부 화면 캡처 맵](actual/duo/index.html) | [화면별 캡처 출처](actual/duo/capture-index.json) |
| iPhone Duo · 펼침 | [내부 화면 캡처 맵](actual/duo-open/index.html) | [화면별 캡처 출처](actual/duo-open/capture-index.json) |
| Apple Watch · 운동 | [62개 상태별 실제 화면 맵](actual/watch/index.html) | [신규 캡처 출처](actual/watch/capture-index.json) · [기존 검증 출처](../watch-workout/simulator-evidence/manifest.json) |

2026-10-15 T10 일간 요약의 권한 준비 중 상태를 수정한 뒤 일반 iPhone과 iPad의 T10을 다시 캡처했다. Duo 접힘·펼침의 T10 이미지는 이전 구현의 캡처이며 이번 변경의 확인 증거가 아니다. 기존 Duo의 `devicectl` 화면 조회가 응답하지 않았고 새 임시 Duo도 부팅을 완료하지 못해 두 자세의 갱신은 보류했다. 시뮬레이터 서비스가 정상화되면 두 자세의 실제 표시를 다시 확인하고 T10을 갱신한다.

2026-10-17 4탭 레이아웃 개편 후 영향받은 12개 화면을 다시 캡처했다: 일반 iPhone A01·H01, iPad T03·A01·H01·L01, Duo 접힘 A01·H01, Duo 펼침 T03·A01·H01·L01. 각 화면의 새 출처와 캡처 시각은 기기별 `capture-index.json`에 기록했다. Duo는 활성 LCD/LCD-1과 내부 화면 native PNG를 확인한 뒤 자세별로 수집했다. 이전에 미검증이던 Duo 펼침 T03도 이번 캡처로 갱신했다.

2026-10-17 테마 적용 계약에 따라 히어로 링 광택과 보조 문구·추세선 대비를 조정한 뒤 일반 iPhone, iPad, Duo 접힘, Duo 펼침의 T03·A01·H01을 각각 새로 캡처했다(총 12장). 네 기기 형태에서 해당 UI 테스트 3개씩 통과했고, Duo는 외부 LCD와 내부 LCD-1 활성 상태 및 캡처 크기를 대조했다. 각 `capture-index.json`의 `source_revision`은 캡처 당시의 기준 커밋이며 `source_worktree_dirty: true`는 이번 앱 변경을 빌드한 작업 트리 상태를 나타낸다. 이 실제 화면맵의 12장은 기본 DUNE 테마이며, 나머지 테마의 방향 기준은 [7개 테마 앱 적용 맵](../theme-map/app-contract.md)에 기록한다.

T01 앱 시작은 `simctl io recordVideo`의 실제 앱 시작 프레임과 원본 영상으로 기록했다. 나머지 갤러리 화면 이미지는 XCTest의 `XCUIScreen.screenshot()` 결과다. 각 카드에서 원본 PNG를 열 수 있다. `boards/`의 7개 PNG는 같은 실제 이미지의 축소 모음이다. 앱 상태와 데이터는 테스트 시나리오의 mock fixture를 사용한다. 일부 테스트는 영어 언어를 지정한다. 원래 최대 접근성 글자 크기 테스트에서 선택됐던 23개 이미지는 기본 글자 크기의 실제 캡처로 교체했고, 현재 인덱스에는 강제 최대 접근성 크기 테스트 출처가 없다. 각 카드 아래에 테스트와 캡처 동작을 기록했다. 인덱스의 `source_revision`은 캡처 시점의 기준 커밋이며, `source_worktree_dirty: true`는 미커밋 앱·테스트 변경을 포함해 빌드했음을 뜻한다.

Duo는 전용 시뮬레이터에서 접힌 상태의 외부 LCD(1398×2034)와 펼친 상태의 내부 LCD-1(2007×2853)을 `devicectl device info displays`의 활성 표시 및 native PNG로 확인했다. 펼친 화면의 원본 PNG에는 회전 메타데이터가 있어 보드 축소본에만 EXIF 방향을 적용했다. 원본 PNG는 그대로 보관한다.

Watch의 [62개 상태별 맵](actual/watch/index.html)에는 기본 글자 크기의 실제 앱 캡처 **59개 상태**와 미캡처 3개 상태를 표시한다. 대부분은 Apple Watch SE 3 (40mm)에서 캡처했고, H01·H02·H03 홈 카드는 Apple Watch SE 3 (44mm)에서 2026-10-19에 갱신했다. 기존 접근성 XXXL 검증 캡처 3장은 별도 구역에 보존했다. 12개 대표 상태의 디자인 보드도 실제 앱 캡처와 구분했다. H01 루틴 이름 잘림, P02 조작 가림, F02·F05·F06·F07의 하단 지표 및 오류 내용 가림을 실제 화면에서 확인했다. [Watch 상태표와 구현 계획](../../plans/2026-10-12-watch-workout-redesign.md)은 별도로 유지한다. 새 디자인 작업은 현재 화면의 캡처 현황을 확인한 뒤 시작한다.

2026-10-19 Watch 홈 H01·H02·H03은 44mm 시뮬레이터의 `testCaptureHomeCardsDesignMap()` 통과 결과에서 다시 캡처했다. 별도의 스크롤 복귀·미리보기 이동 UI 테스트도 최신 코드에서 통과했다. 각 이미지의 기기와 결과 번들은 `capture-index.json`에 기록했다.

미캡처 상태는 S08 이전 세트, S11 휴식 AOD, C12 유산소 AOD다. S08은 완료한 세트 뒤 버튼이 표시되지 않았고 재현 테스트가 응답 없이 멈춰 원인을 분리해야 한다. AOD 2개는 시뮬레이터 화면 전원 전환으로 실제 저휘도 프레임을 얻지 못했다. S16은 이후 실제 화면을 재캡처해 등록했다. 화면 이미지를 다른 상태나 시안으로 대체하지 않았다. C08은 알림이 실제로 보이는 실패 첨부 화면을 확인해 등록했다. watchOS 접근성 계층이 그 화면을 `alert`로 분류하지 않아 테스트의 요소 판정만 실패했으며, 이 경위를 인덱스에 기록했다.

## 화면 수정 시 갱신

화면 배치, 글자, 상태, 내비게이션이 바뀌는 작업에서는 같은 작업 안에서 영향받는 화면 ID와 기기를 확인하고 **실제 앱 화면을 다시 캡처**한다. 폰 ID는 [화면 인벤토리](screen-inventory.md), Watch ID는 [Watch 상태표](../../plans/2026-10-12-watch-workout-redesign.md)에서 찾는다. 새 화면이나 분기는 상태표와 캡처 테스트를 먼저 추가한다. 수정된 화면이 어느 기기에 나타나는지 확인한 뒤 해당 기기만 갱신한다.

기존 캡처 테스트가 있는 화면은 한 화면씩 실행할 수 있다:

```bash
python3 docs/design/phone-design-map/refresh-actual-screen.py regular W04 <iPhone-UDID>
python3 docs/design/phone-design-map/refresh-actual-screen.py ipad W04 <iPad-UDID>
python3 docs/design/phone-design-map/refresh-actual-screen.py duo W04 <Duo-UDID>
python3 docs/design/phone-design-map/refresh-actual-screen.py duo-open W04 <Duo-UDID>
python3 docs/design/phone-design-map/refresh-actual-screen.py watch S16 <Watch-UDID>
```

위 명령은 각 `capture-index.json`의 테스트 출처를 사용해 해당 UI 테스트 하나를 실행하고, 새 PNG를 수집해 갤러리·보드·[통합 포털](actual/index.html)을 갱신한다. `--dry-run`으로 실행 명령만 먼저 확인할 수 있다. Duo는 먼저 목적 자세로 전환해야 하며, 명령이 실행 전후 `devicectl device info displays`에서 활성 외부/내부 화면을 확인한다. 새 테스트 파일을 추가했다면 프로젝트를 재생성한 뒤 실행한다. 테스트 출처가 없는 화면은 진입 경로와 캡처 테스트를 마련한다. 여러 상태를 한 흐름에서 캡처해야 할 때는 `run-and-collect-group.sh`의 관련 그룹만 실행한다. 이 스크립트는 테스트가 실패하면 캡처 추출 여부와 무관하게 실패로 종료한다.

완료 전에 새 PNG의 화면 내용과 글자 크기·잘림·겹침을 확인하고, 수정된 화면 ID의 캡처 시간이 이전보다 새로운지 확인한다. 화면 수가 바뀌면 이 문서의 기기별 개수도 고친다. 테스트 통과만으로 화면 갱신을 완료했다고 보지 않는다. 해당 상태를 열 수 없거나 시뮬레이터가 막히면 기존 이미지를 새 구현의 증거로 제시하지 않고 미갱신 화면 ID와 기기, 원인, 재개 조건을 작업 결과에 남긴다. 다른 화면까지 일괄 재캡처하지 않는다.

## 수집과 대조

1. `python3 docs/design/phone-design-map/build-phone-design-maps.py`로 SwiftUI 화면 타입과 프레젠테이션 대상을 대조하고 인벤토리를 갱신한다. 이 스크립트는 더 이상 도식 화면을 생성하지 않는다.
2. `DUNEUITests-DesignCapture.xctestplan`의 `DUNE_VISUAL_AUDIT`로 실제 화면 PNG와 접근성 계층을 XCTest 결과에 첨부한다. 기기는 명시적 UDID로 분리한다.
3. `bash docs/design/phone-design-map/run-capture-group.sh regular today <UDID>`처럼 화면 경로 묶음을 실행한다. 묶음은 `today`, `activity`, `activity-extra`, `activity-info`, `wellness-life`, `additional`, `recovery`다.
4. `python3 docs/design/phone-design-map/collect-real-captures.py regular <xcresult> [추가 xcresult...]`로 캡처의 화면 식별자를 인벤토리와 연결하고 갤러리·보드를 만든다. 매칭되지 않는 첨부 파일은 `capture-index.json`의 `unmatched`에 기록한다.
5. Watch는 `python3 docs/design/watch-workout/collect-actual-captures.py <watch-xcresult>`로 이름이 붙은 UI 테스트 첨부 화면을 추출하고 상태별 갤러리를 갱신한다.

캡처 출처 테스트의 후속 조작이 실패한 경우에도 화면별 실제 PNG와 접근성 계층이 생성됐는지 확인한 뒤 해당 화면만 채웠다. `capture-index.json`에는 선택된 화면마다 테스트 이름과 캡처 동작을 기록했다.
