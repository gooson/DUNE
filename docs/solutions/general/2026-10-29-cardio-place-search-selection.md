---
tags: [cardio-atlas, mapkit, place-search, hangul, initial-consonants, scroll, keyboard]
category: general
date: 2026-10-29
severity: important
status: implemented
related_files:
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasPlacePicker.swift
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasPlaceSearch.swift
  - DUNETests/CardioAtlasPlaceSearchTests.swift
  - DUNEUITests/Visual/CardioAtlasUITests.swift
---

# 유산소 기록 장소 검색·선택 복귀

## Problem

사용자 영상에서 검색 결과를 선택한 뒤 선택 장소의 지도 일부만 위에 걸리고 검색 키보드가 남았다. 검색 중 숨겨진 상단 저장 toolbar가 복구되지 않아 저장 경로도 찾기 어려웠다. `헬스` 입력에는 헝가리 호텔이 표시됐다.

검색 요청에는 지역 기준이나 결과 거리 정렬이 없었다. 이름·주소와 무관한 MapKit 유사음 결과를 그대로 표시했고, 한글 조합·단어·초성에 대한 검증도 없었다. 장소 선택은 값만 바꿨으며 검색 종료·스크롤 복귀를 처리하지 않았다.

## Solution

- 선택할 때 검색 모드를 종료하고 `ScrollViewReader`로 선택 장소명에 복귀한다. 선택 revision을 사용해 같은 결과 재선택도 처리하고, 지도 identity를 장소 값에 맞춰 중심을 갱신한다. 미리보기 지도는 목록 스크롤을 가로채지 않는다.
- 하단 고정 저장 버튼과 기존 toolbar가 같은 저장 함수를 호출한다. 저장 실패는 선택 상태를 유지하며, 취소는 기존 기록을 바꾸지 않는다.
- 기존 위치 권한이 있으면 단발 현재 위치를 검색 기준으로만 받는다. 새 권한 요청은 현재 위치 버튼에 한정한다. 현재 위치가 없으면 기존 장소로 fallback한다. 좌표 초기화도 기존 검색을 취소·갱신한다.
- 기준점 주변 20km의 검색 region을 설정하고 받은 결과를 거리 오름차순으로 정렬한다. 먼 지역의 명시적 검색을 region으로 차단하지 않는다. 동거리 결과는 MapKit 순서를 유지한다.
- 한글을 NFC로 정규화하고 공백을 정리한다. 단독 초성·미완성 모음은 검색을 보류하며, 두 글자 이상 초성·완성형/초성 혼합은 음절 초성으로 대조한다. 모든 검색 단어가 이름·주소에 대응하는지 검사해 무관한 해외 유사음 결과를 제외한다.
- `헬스` 등 일반 시설 검색은 피트니스 시설을 대상으로 한다. 알려진 초성은 완성형 검색어로 확장하며, 그 외 초성은 기준점 주변의 POI 후보를 대조한다. 기준점도 확장어도 없으면 현재 위치 사용 또는 장소명 입력을 안내한다. MapKit이 제공한 후보 범위 안에서 검색하며 전체 지도 데이터의 완전성을 보장하지 않는다.

## Verification

- 실제 앱의 검색 헬퍼·위치 모델·Swift Testing 파일을 복사한 독립 macOS Swift Package에서 관련 19개 테스트가 통과했다. 전체 iOS unit suite 실행 결과가 아니다.
- 단위 검증 범위: 미분류 장소의 초성 검색 요청, 현재 위치 우선·기존 장소 fallback, 거리·동거리 정렬, 잘못된 좌표 제외, 요청 region·시설 분류, 한글 조합/NFC/공백, 단어·주소·초성·혼합 검색, 무관한 해외 호텔 제외.
- 전용 iPhone의 한글 단어·초성 검색→선택→키보드 닫힘→저장은 실제 UI 테스트가 통과했다. 기존 장소를 변경한 후 취소하는 검사도 통과했다. iPad의 한글·초성 검색과 저장은 1/1 통과했다. [새 실제 화면과 상태별 결과](../../design/full-redesign-map/review/cardio-place-search-2026-10-29/index.html)에 캡처·출처·미완료 범위를 보존한다.
- 초기 UI 두 건은 결과 선택 전 테스트 스와이프가 키보드 영역에 걸려 실패했다. 키보드·하단 버튼 위의 실제 목록 영역에서 드래그하도록 보정했다. 재실행 중 발생한 MapKit C API의 Swift 이름 차이는 `maxRadius`·`MKLocalSearch(request:)`로 수정했다. 후속 실행에서 기존 장소가 없는 긴 목록 검사는 keyboard AX 시작점보다 위에 있는 추천 영역을 드래그해 선택 전 실패했다. 시작점 여백을 보완했지만 같은 원인 최대 1회 재시도 제한에 따라 이 selector를 추가 실행하지 않았다. 해당 초기 빈 장소의 긴 목록·재선택·재열기 전체 경로는 미검증이며, 통과한 한글 선택·저장과 기존 장소 변경·취소로 전체 UI 통과를 주장하지 않는다.

## Prevention

선택 결과가 화면 위쪽에 생기는 검색 UI는 선택 상태뿐 아니라 키보드 종료, 선택 영역 노출, 저장 행동의 가시성을 함께 검사한다. 위치 bias와 저장 위치를 구분하고 비동기 위치가 사용자 선택을 덮어쓰지 않게 한다. 검색은 서비스 응답을 그대로 신뢰하지 말고 입력 언어·단어·시설 분류와의 관련성을 확인한다.

## Lessons Learned

일반 텍스트 검색에 적합한 지도 API의 유사음 확장은 짧은 한글 장소 검색에서 잘못된 국가의 결과를 만들 수 있다. 지역 bias와 한글 대조는 별도 역할이며 함께 검증해야 한다. UI 회귀는 화면 키보드를 실제로 띄운 상태에서 수행해야 한다.

### 최종 기기 범위 · 2026-10-30

iPhone 2건·iPad 1건·Duo 외부 1건의 관련 UI가 통과했고 새 실제 11장(진단 1장 포함)을 보존했다. Duo 내부는 활성 LCD-1을 확인했으나 앱 테스트 기동 증거 없이 실행 deadline 900초/124로 종료됐다. CA02 Duo 내부의 새 캡처는 미완료다. Device Hub AX도 unknown을 반환해 앱 assertion 실패로 분류하지 않는다. 기존 이미지는 새 증거로 사용하지 않는다. 전용 기기의 앱/AX/러너 정상화 근거 뒤 해당 selector만 재개한다.


2026-10-30 리뷰 후속: 기존 실패/재시도 이력은 보존한다. 새 native 단일 드래그 진단에서 추천 영역 밖의 y490→350 조작과 실제 목록 이동을 확인한 뒤, 원래 긴 목록 선택·재선택·저장/재열기 selector가 정상 종료·통과했다. 저장은 하단 하나로 정리했고 지역+시설 단어 카테고리 매칭도 보완했다. 최신 증거는 docs/design/full-redesign-map/review/cardio-atlas-polish-2026-10-30/를 따른다. 다른 기기의 기존 시작 장애를 복구 또는 통과로 바꾸지 않는다.
