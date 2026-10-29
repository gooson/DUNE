---
tags: [cardio, atlas, map, sharing, journey, passport, indoor, outdoor]
date: 2026-10-29
category: brainstorm
status: draft
---

# 유산소 아틀라스 통합 시안

사용자가 아틀라스를 기본으로 공유 스타일 선택, 저니 진행, 패스포트 업적을 합친 단일 시안을 요청했다. 기존 다섯 방향 비교는 보존하고 이번 문서를 현재 통합 방향으로 사용한다. 시안이며 네이티브 앱 적용 승인이 아니다.

## 화면 흐름

1. **운동 상세**: 운동명·날짜·종목별 수치 → Atlas의 실제 경로/장소 지도 → 이번 운동이 더한 Journey 진행 → 이번에 얻은 Passport 업적 → 공유 진입.
2. **공유 카드**: 같은 기록에 Atlas / 페이스 리본 / 시그니처 중 표현을 선택한다. Journey 진행과 Passport 업적을 각각 포함/제외한다. 스타일 변경은 원본 기록이나 업적을 변경하지 않는다.
3. **Journey 상세**: 실제 거리 또는 운동 시간의 누적 목표, 이번 운동의 기여, 남은 양과 가상 진행의 의미를 표시한다. 실제 운동 지도와 가상 여정을 합쳐 실제 방문으로 해석하게 하지 않는다.
4. **Passport 상세**: 획득한 업적과 다음 업적의 기준/진행을 표시한다. 수동 선택한 장소를 검증된 방문 업적으로 만들지 않는다.

새 루트 탭이나 다섯 상세 디자인 선택기를 만들지 않는다. 기본 상세의 정보 위계는 다른 상세 개편 브랜치의 공통 헤더·통계를 존중하고 지도·목표·업적·공유를 연결한다.

## 전체 유산소 범위

- 실내·실외 모든 유산소에 공통 장소 모델을 적용한다. 이동 경로가 기록되면 경로 지도, 제자리 운동이나 실내 머신이면 장소 핀을 기본으로 한다.
- 경로 유무는 실제 기록 데이터가 결정한다. 특정 종목 목록으로 제품의 경로 지원을 제한하지 않는다. 시안의 공개 지도 경로 fixture는 러닝/걷기/자전거 예시에서만 사용하며 로잉·수영에 공원 보행 경로를 그리지 않는다.
- km/m/floors/count/timeOnly를 구분한다. 자전거 속도, 러닝 /km, 로잉 /500m, 수영 /100m 등은 해당 데이터가 있을 때만 표시한다. 거리 없는 운동의 Journey는 운동 시간으로 진행하며 층수·횟수를 km로 바꾸지 않는다.
- 실내 위치는 단발 위치 후보나 직접 선택/보정으로 연결한다. 위치 미지정·경로 미수신은 운동 수치와 별개 상태다.

## 공유 계약

- 원본 상세는 개인 기록의 전체 경로/장소를 표시한다. 공유 공개 범위는 별도다.
- 경로 공유에서 출발·도착 숨김은 geometry와 S/F 표식에 적용한다. 장소 제외는 지도 배경·핀·시설명 모두 제거한다. 수치는 원본 전체 기록 기준이다.
- 페이스 리본은 구간 데이터가 있는 예시에서만 선택할 수 있다. 없는 구간의 페이스를 생성하지 않는다. 실제 경로가 없는 시그니처는 큰 수치와 운동명을 사용하며 가짜 경로선을 만들지 않는다.
- Journey/Passport 포함 선택은 공유 카드의 출력만 바꾼다. 목표 기록이나 획득 업적을 삭제하지 않는다.
- 브라우저 시안은 상세·공유 편집과 목표/업적 상세의 탐색을 보여 준다. 실제 사진 보관함 저장·SNS 게시·GPS 수집·HealthKit 저장을 수행하지 않는다.

## 반응형과 검증

iPhone·접힌 Duo는 순서대로 읽는 한 열, iPad·펼친 Duo 폭은 지도와 Journey/Passport를 두 열로 배치한다. 큰 글씨는 한 열로 돌아간다. 320px부터 넓은 폭까지 지도·수치·배지·버튼의 잘림을 확인한다. 브라우저 시안의 검사와 실제 앱 디자인맵/시뮬레이터 캡처를 구분한다.

## 보존본

[통합 시안](../theme-map/themes/dune-cardio-atlas-integrated.html), 편집 원본 `../theme-map/themes/assets/cardio-atlas-integrated-fragment.html`, 검사 `../theme-map/themes/assets/cardio-atlas-integrated-qa.json`. 지도 데이터는 기존 `running-map-seoul-forest.geojson`, `running-map-route.json`, `running-map-venues.json`과 출처 파일을 재사용한다. 통계·목표·업적은 예시이며 실제 사용자 기록이 아니다.

## 브라우저 확인 결과

320/736/1024px, 밝음·어두움, 실외 이동/실내/실외 제자리/경로 미수신의 상세·공유·저니·패스포트, 실내11종목과 큰 글씨를 포함한111개 배치/조작 검사를 수행했다. 공유 스타일3종·경로 geometry 숨김·Journey/Passport 포함 선택·공유 위치 제외와 개인 지도 보존을 확인했다. 하단 평균 심박의 종목별 바인딩 수정 후3개 값 상태를 한정 확인했다. 실패/잘림/브라우저 오류는 없었다. 소스 해시와 재사용 범위는 `cardio-atlas-integrated-qa.json`에 있다. 초기 공유 옵션 검사에서 조작 중인 체크박스까지 교체되는 문제를 수정해 현재는 카드 콘텐츠만 갱신한다. 실제 센서·권한·네이티브 앱·고정 크기 PNG 내보내기 검증은 수행하지 않았다.


## Native implementation contract · 2026-10-29

Accepted by user invocation of `/run`. This section supersedes proposal-only status for the native work in progress; browser PNGs remain concept evidence. Existing local and HealthKit detail headers lead into Atlas, then existing metrics/analysis. New IDs: `cardio-atlas-section`, `cardio-atlas-map`, `cardio-atlas-share`, `cardio-atlas-place`, `cardio-atlas-journey`, `cardio-atlas-passport`. Journey/Passport destinations: `cardio-atlas-journey-detail`, `cardio-atlas-passport-detail`. Native routes are segmented actual GPS; indoor/stationary location is an editable selected place, never a generated route. No location is a valid editable state.

Target states: phone compact, tablet regular, Duo folded/unfolded, larger text; light/dark follow existing theme tokens. Header actions wrap vertically when necessary; progress pages center within readable widths. Place editor is a cancellable native search sheet. Location sharing starts OFF. Explicit location sharing can trim first/last300m; private detail does not change. Online map errors provide retry and block incomplete Atlas export. Signature/private cards work without network. Source units remain actual meters or elapsed seconds. Native captures are collected separately after build/UI validation. Watch UI is unchanged; shared schema builds and imported authorized Watch routes are supported.

Native implementation is present, including Watch outdoor GPS recording. Focused domain/history/Watch route tests passed. Final UI and native captures remain blocked by simulator/AX failures; see the [native verification status](../full-redesign-map/review/cardio-atlas-2026-10-29/index.html). This is not a native visual approval.

### Native destination ownership correction · 18:00 retry

The native exercise list opens records in an inspector. Actual screenshots showed Atlas NavigationLinks pushing Journey/Passport/Share beneath that inspector. Atlas now owns one enum-driven secondary sheet with a local NavigationStack and Done action, matching the existing visible place editor presentation. Journey and Passport capture their progress value at entry; goal bindings continue to update the Journey target. Closing an Atlas destination returns to the same workout detail. The parent exercise inspector and other detail redesign remain intact. Visibility checks must confirm hittable destination roots and fresh native PNGs; existence in an obscured underlying stack is insufficient.

Map snapshots in native share previews preserve their full aspect ratio within the sheet width. A fixed image height must not expand the card or crop the route. Style buttons expose the selected accessibility trait; native checks verify actual selection and that preview/selector frames stay within the sheet.

At accessibility sizes, the native Atlas heading and actions use a vertical layout, with full-width Place/Share buttons. Action words must remain readable as words rather than stacking individual Korean syllables.

Pace Ribbon must remain visually distinct from Atlas in the default theme. Its measured speed bands use the existing activityWater/activityStrength chart tokens and its card includes the existing localized Pace Ribbon style label. Distinct chart tokens keep pace bands separate from the Atlas accent stroke.

Compact non-accessibility headers also measure the horizontal heading/actions candidate at its uncompressed ideal width. If it does not fit, ViewThatFits chooses the stacked header instead of splitting the Place action into syllables.

The inline workout map is a preview: pan/zoom gestures are reserved for Expand map. This lets vertical drags reach the surrounding workout detail and its Passport row on short wide viewports. Expanded maps retain full interaction.

Place search uses the native navigation-bar drawer with always-visible search placement, keeping results and their empty state above the search field in short landscape sheets.

### 장소 선택·가까운 검색 보완 · 2026-10-29

- 검색 결과 선택 시 검색 키보드를 닫고 목록 상단의 선택 장소명·지도로 이동한다. 같은 결과를 다시 누르거나 다른 장소를 선택해도 해당 지도 중심을 갱신한다. 저장 전 선택 상태이며 취소하면 원래 기록을 유지한다.
- 선택 후에는 하단 고정 `저장` 버튼으로 기록 반영을 완료한다. 검색 모드가 상단 toolbar를 가려도 선택·저장 경로를 찾을 수 있게 한다.
- 이미 위치 권한이 있으면 단발 현재 위치를 검색 기준으로 받는다. 검색을 위해 새 권한 창을 띄우거나 그 위치를 운동 장소로 자동 저장하지 않는다. 현재 위치가 없으면 기존 운동 장소, 둘 다 없으면 지도 검색 기본 순서를 사용한다.
- 기준점 주변을 우선 검색하되 먼 지역의 명시적 검색을 차단하지 않는다. 받은 결과는 기준점과 가까운 순으로 정렬하며 같은 거리에서는 원래 검색 순서를 유지한다.
- 단독 초성·조합 중인 모음은 완성될 때까지 원격 검색을 보류한다. 두 글자 이상 초성·완성형/초성 혼합 검색은 주변 후보의 한글 음절 초성을 대조한다. `헬스` 같은 일반 시설 검색은 피트니스 시설을 대상으로 하며, 한글 이름·주소 단어와 무관한 해외 유사음 결과는 제외한다.
- 영향 화면은 CA02 장소 편집이다. 일반 iPhone·iPad·Duo 접힘/펼침이 같은 편집기를 사용하며 Watch UI는 영향이 없다. 새 실제 캡처·검증 결과는 별도 기록한다.

이번 장소 검색 보완의 [새 실제 화면·상태별 검증·미완료 경로](../full-redesign-map/review/cardio-place-search-2026-10-29/index.html)를 통합 실제 화면맵에서 연결한다. 테마 시안은 변경하지 않았다.

### 공유 스타일 버튼 밀도 보완 · 2026-10-30

CA05–CA07 공유 편집의 스타일 선택은 큰 아이콘/이름 2단 pill 대신 아이콘과 이름을 한 줄에 둔 작은 시스템 버튼을 사용한다. 기본 글씨는 같은 너비의 3열, 접근성 글씨는 전체 너비의 3행이다. 상단 여백은 8pt, 미리보기까지는 16pt로 줄여 컨트롤과 카드의 연결을 분명하게 한다. 실제 터치 영역은 44pt 이상으로 확인한다. 선택 강조·사용할 수 없는 Pace Ribbon·기존 스타일별 식별자와 공유 공개 범위는 유지한다. iPhone·iPad·Duo의 같은 공유 편집기가 영향 대상이며 Watch는 소비자가 없다. 색/테마 방향과 공유 카드 출력 자체는 변경하지 않는다.

공유 버튼 간격 보완은 [새 실제 원본 8장과 관련 UI 3건](../full-redesign-map/review/cardio-share-spacing-2026-10-30/index.html)으로 iPhone 기본/최대 글씨와 iPad를 확인했다. Duo 접힘·펼침은 기존 AX/러너 기동 장애가 해결되지 않아 갱신 대기다.

### 공유 모달 배경·드래그 보완 · 2026-10-30

CA05–CA07 공유 편집은 알파 1의 `surfacePrimary`를 모달 바탕과 내비게이션 바에 사용하고 본문에는 `SheetWaveBackground`를 겹친다. 스크롤 영역 밖이나 bounce 중에도 아래 운동 상세가 모달 안으로 비치지 않게 한다. 공유 목적지에만 page sizing·large detent·본문 scroll 우선·닫기 손잡이를 지정하고 본문은 제안된 전체 영역을 채운다. 위아래 본문 드래그 후 내용이 빈 시트가 되지 않아야 하며, 드래그 닫기는 같은 운동 상세로 정상 복귀해야 한다. 다시 열기와 완료 버튼 닫기도 검증한다. Journey/Passport 목적지의 표시 설정은 유지한다.

공유 모달 배경·드래그 보완은 [새 실제 20장·관련 UI 4건 통과](../full-redesign-map/review/cardio-share-modal-2026-10-30/index.html)로 검증했다. iPhone 밝음/어두움/최대 글씨와 iPad만 새로 촬영했고, 두 Duo 상태는 기존 실행 장애가 남아 갱신 대기다.

### Passport 운동 횟수 업적 확장 · 2026-10-30

CA04의 횟수 업적은 기존 1·5·10·20·50·100회를 유지하고, 이후 200·300·400회처럼 100회마다 계속 생성한다. 선택한 운동까지의 유효하고 중복 없는 같은 종목 기록을 기준으로 하며, 달성일과 연결 기록은 해당 횟수를 처음 채운 실제 세션이다. `다음 업적`은 100회에서 끝나지 않고 다음 100회 단위 목표와 현재 진행률을 표시한다. 기록 수정·삭제·과거 기록 선택에도 다시 계산한다. 그리드와 번역 문구는 유지하며 새로 늘어난 업적/다음 목표 상태를 캡처한다.

횟수 업적 확장의 [새 CA04 실제 화면·검증 범위·미갱신 기기](../full-redesign-map/review/cardio-count-milestones-2026-10-30/index.html)를 통합 실제 화면맵에서 연결한다. 이번 변경은 데이터 상태 확장이며 테마 시안은 변경하지 않았다.


2026-10-30 리뷰 후속: 기존 실패/재시도 이력은 보존한다. 새 native 단일 드래그 진단에서 추천 영역 밖의 y490→350 조작과 실제 목록 이동을 확인한 뒤, 원래 긴 목록 선택·재선택·저장/재열기 selector가 정상 종료·통과했다. 저장은 하단 하나로 정리했고 지역+시설 단어 카테고리 매칭도 보완했다. 최신 증거는 docs/design/full-redesign-map/review/cardio-atlas-polish-2026-10-30/를 따른다. 다른 기기의 기존 시작 장애를 복구 또는 통과로 바꾸지 않는다.
