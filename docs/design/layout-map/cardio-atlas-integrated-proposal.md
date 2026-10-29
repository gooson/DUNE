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
