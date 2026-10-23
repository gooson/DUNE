---
tags: [design, desert-horizon, actual-capture, comparison]
date: 2026-10-24
category: design
status: in-progress
---

# DESERT HORIZON 최종 구현 화면 비교

[화면별 이전·현재 비교 갤러리](index.html) · [통합 실제 화면맵](../../../phone-design-map/actual/index.html) · [방향 시안](../../../theme-map/themes/dune-final-four-tab.html)

이 갤러리의 **현재 구현** 이미지는 실제 앱 화면의 XCTest PNG다. iPhone 18 Pro (`4990D55E-752C-4E35-8FB4-953F995AB2C2`)에서 소스 `3d9ba7e7`로 만든 4탭 밝음·어두움 8장과 최대 접근성 글씨 4장을 사용한다. `ThemeMatrixUITests/testDesertHeroRingsByInitialTab()`과 `ThemeMatrixUITests/testDesertFourTabHeroesAtMaximumAccessibilityTextSize()`는 각각 개별 실행에서 통과했다. 출처, 결과 번들, 시각, 기기 ID는 [일반 화면 인덱스](regular/capture-index.json)와 [큰 글씨 인덱스](accessibility-capture-index.json)에 있다. 첫 통합 UI 묶음은 15개 중 10개 통과·5개 실패였으며, 그 실패에 대한 후속 검증은 진행 중이다. 이 갤러리는 최종 전체 검증 통과 주장으로 사용하지 않는다.

**이전 기준** 4장은 [별도 인덱스](before/capture-index.json)에 있는 이전 실제 앱 화면이다. 밝은 모드만 있고 캡처 기기·시점도 현재 화면과 다를 수 있다. 갤러리에서 어두움 또는 큰 글씨를 선택해도 왼쪽은 이전 밝은 화면임을 표시한다. 픽셀 위치가 같은 동일 조건 전후 실험으로 해석하지 않는다.

**방향 시안**은 보존된 HTML 문서이며 실제 앱 캡처가 아니다. 시안의 예시 수치·차트를 앱의 실제 데이터 증거로 취급하지 않는다.

## 갱신

새 iPad 또는 Duo 캡처가 준비되면 이 폴더의 `ipad/`, `duo/`, `duo-open/`에 각각 `capture-index.json`과 인덱스가 가리키는 PNG를 넣는다. 인덱스는 기존 `regular/capture-index.json`의 `captures` 구조를 따르고 각 항목에 `screen_id`, `appearance`, `file`, `test_identifier`, `source_revision`, `device`를 기록한다. 큰 글씨 PNG는 루트 `accessibility-capture-index.json`에 기기별 파일 경로로 추가할 수 있다. 갤러리는 **인덱스와 원본 PNG가 모두 있는 조합만** 표시하며, 없는 기기·상태에 다른 기기의 PNG를 채워 넣지 않는다. 각 기기의 기존 `phone-design-map/actual/<device>/capture-index.json`은 별도 UDID의 기록이므로 이 갤러리 갱신을 위해 덮어쓰지 않는다.

```bash
python3 docs/design/full-redesign-map/review/desert-horizon-final-2026-10-24/build-gallery.py
```

생성된 `index.html`은 로컬 파일로 바로 열 수 있다. 기존 실제 화면맵 포털은 이 비교 갤러리로 연결한다.
