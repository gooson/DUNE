---
tags: [mapkit, swiftui, accessibility, app-intents, deprecation]
category: general
date: 2026-11-21
severity: minor
related_files:
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasPlaceSearch.swift
  - DUNE/Presentation/HealthQuery/HealthQueryResultCard.swift
  - DUNE/Presentation/Wellness/Components/WellnessSleepSummaryCard.swift
  - DUNEWatch/Views/Cardio/CardioSecondaryPage.swift
  - DUNE/project.yml
---

# 장소 검색과 접근성 레이블의 SDK 경고 정리

## 원인과 해결

- Cardio Atlas는 검색 결과의 좌표와 주소를 모두 `placemark`에서 읽었다. 좌표는 `item.location.coordinate`에서 읽고, 화면과 한글 검색에는 `addressRepresentations`의 한 줄 전체 주소를 사용한다. 표현이 없는 결과에는 `item.address?.fullAddress`를 사용한다. 주소가 없는 합성 결과도 이름과 좌표만으로 선택할 수 있다.
- 고정된 접근성 문장을 여러 `Text`로 이어 붙이면 번역자가 문장 전체의 어순을 지정할 수 없다. 운동 레벨과 경과 시간처럼 값이 있는 문장은 전체 문장을 키로 등록한다. 수면 날짜에는 `Text(day, format:)`를 그대로 보간해 화면의 locale과 달력 설정을 반영한다. 사용자 메모처럼 일치 개수가 가변적인 텍스트는 `AttributedString`으로 조립해 일치한 부분에만 강조를 적용한다.
- 건강 조회 인텐트의 `@Parameter`는 `let`으로 선언한 snippet에서도 답변 ID를 설정할 수 있다. Watch 앱은 자체 인텐트가 없어 해당 타깃에서만 메타데이터 추출을 건너뛴다. Watch에 인텐트를 추가하면 이 타깃 설정도 제거한다.

## 회귀 확인

주소를 포함하는 테스트 데이터는 `MKMapItem(location:address:)`와 `MKAddress(fullAddress:shortAddress:)`로 생성한다. 행정구역과 시설 이름을 조합한 검색, 초성 검색 및 거리 정렬은 `CardioAtlasPlaceSearchTests`에서 검증할 수 있다. 문자열 카탈로그는 iOS·Watch 양쪽의 보간 타입 및 수동 추출 상태를 확인한다. 기기용 빌드에서 건강 조회 앱과 위젯의 `Metadata.appintents/extract.actionsdata`가 생성되는지도 확인한다.
