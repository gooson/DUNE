---
tags: [design, desert-horizon, actual-capture, comparison]
date: 2026-10-24
category: design
status: in-progress
---

# DESERT HORIZON 최종 구현 화면 비교

[화면별 이전·현재 비교 갤러리](index.html) · [통합 실제 화면맵](../../../phone-design-map/actual/index.html) · [방향 시안](../../../theme-map/themes/dune-final-four-tab.html)

이 갤러리의 **현재 구현** 이미지는 실제 SwiftUI 앱과 WidgetKit·ActivityKit 시스템 화면의 PNG다. 데이터는 명시된 UI 테스트의 mock fixture이며 앱에 가짜 데이터를 추가한 것이 아니다. iPhone 밝음·어두움과 최대 접근성 크기, iPad, Duo 접힘 세로·펼침 가로의 루트와 선택한 상세를 포함한다. 각 이미지의 커밋·기기·테스트·결과 번들은 개별 capture-index.json을 기준으로 한다. 제품 변경과 무관한 과거 테스트 실패도 [검증 보고서](../../../../reviews/2026-10-24-desert-horizon-final.md)에 남긴다. 전체 회귀 또는 모든 화면·상태의 캡처 완료를 뜻하지 않는다.

시스템 Widget 갤러리는 실제 extension의 placeholder 표시이며 Home에 설치된 timeline과 구분한다. ActivityKit은 기기 밝은 설정에서도 시스템의 어두운 표면으로 렌더링한 캡처가 있으므로, 해당 PNG를 밝은 표면 검증으로 표시하지 않는다. Dynamic Island·Watch small·실제 페어링·잠금/개인정보 가림 상태는 캡처 미검증이다.

**이전 기준** 4장은 [별도 인덱스](before/capture-index.json)에 있는 이전 실제 앱 화면이다. 밝은 모드만 있고 캡처 기기·시점도 현재 화면과 다를 수 있다. 갤러리에서 어두움 또는 큰 글씨를 선택해도 왼쪽은 이전 밝은 화면임을 표시한다. 픽셀 위치가 같은 동일 조건 전후 실험으로 해석하지 않는다.

**방향 시안**은 보존된 HTML 문서이며 실제 앱 캡처가 아니다. 시안의 예시 수치·차트를 앱의 실제 데이터 증거로 취급하지 않는다.

## 남은 검증

Duo 펼침 Today(T03)의 최종 상단 배치는 미검증이다. 물리 방향 landscapeLeft와 달리 simulator 표시 컨트롤러가 rot0, AX669×951, native2007×2853로 남았다. 기존 가림 PNG를 현재 구현으로 재사용하지 않는다. 현재 Mac 잠금 때문에 Device Hub UI를 확인할 수 없어 잠금 해제 후 표시 회전과 실제 가로 viewport를 먼저 확인해야 한다. 이 UI 게이트를 통과하기 전에는 PR·머지를 진행하지 않는다.

## 갱신

새 기기 캡처를 갱신할 때는 이 폴더의 `ipad/`, `duo/`, `duo-open/`에 각각 `capture-index.json`과 인덱스가 가리키는 PNG를 넣는다. 인덱스는 기존 `regular/capture-index.json`의 `captures` 구조를 따르고 각 항목에 `screen_id`, `appearance`, `file`, `test_identifier`, `source_revision`, `device`를 기록한다. 큰 글씨 PNG는 루트 `accessibility-capture-index.json`에 기기별 파일 경로로 추가할 수 있다. 갤러리는 **인덱스와 원본 PNG가 모두 있는 조합만** 표시하며, 없는 기기·상태에 다른 기기의 PNG를 채워 넣지 않는다. 통합 실제 화면맵에는 갱신한 항목만 개별 출처와 함께 연결하며 역사적 인덱스 전체를 최신 검증으로 바꾸지 않는다.

```bash
python3 docs/design/full-redesign-map/review/desert-horizon-final-2026-10-24/build-gallery.py
```

생성된 `index.html`은 로컬 파일로 바로 열 수 있다. 기존 실제 화면맵 포털은 이 비교 갤러리로 연결한다.
