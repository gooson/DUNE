---
tags: [swiftui, detail-redesign, w11, ui-testing, navigation]
category: testing
date: 2026-11-07
severity: minor
status: unresolved-held
---

# W11 Phone 필수 검사 미완료

큰 글씨 후보와 iPad 일반·MAX 실제 PNG/AX는 보존했지만 Phone에서 변경한 목표에 진입하지 못해 머지하지 않는다. 이력 링크 이후 앞쪽 inspector의 빈 셸과 Done이 남았다. 소유 ExerciseView 소스는 변경하지 않았으나 이전 버전 재현이나 단독 원인은 입증하지 않았다.

Phone 최초 전체는 3/6, 같은 ID 원인 대응 후 재검사는 1/3이다. 두 기록 selector는 양쪽 실행에서 모두 실패했다. iPad는 전체 6/6 통과했다. 이는 Phone 목표 통과를 대신하지 않는다. 실행 ID의 두 실패 기록은 닫힌 상태로 보존하며 세 번째 SDK·수동 우회는 하지 않았다. 새로운 Phone 검증 허용과 실제 원인 대응이 확인되기 전까지 필수 게이트는 미완료다.

[보류 갤러리와 원본 결과](../../design/full-redesign-map/review/share-image-w11-2026-11-07/index.html)에 새 iPad 캡처와 진단 자료를 구분했다. 기존 Phone/iPad/Duo 실제 맵의 PNG/index는 변경하지 않았다. W26의 Phone chart라는 진단 첨부는 앞쪽 inspector가 가린 상태여서 보이는 이력 그래프 증거가 아니다. W11 iPad MAX 이미지 미리보기는 84×128pt로 작아 품질 검토도 남았다. 기존 데이터·공유·단위·아이콘·정렬 동작을 유지한다.

검증 소스는 `3d5d685efe2b92ed63d60ef87392a328ca7a1fb2`이며 화면별 앱 SHA·실패·미검증 범위는 갤러리 manifest/HELD.md에 보존했다. Duo 새 캡처는 대기다. 이 문서는 해결 또는 UI 통과 선언이 아니다.
