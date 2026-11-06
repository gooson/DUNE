---
tags: [swiftui, detail-redesign, w25, accessibility, ui-testing]
category: testing
date: 2026-11-07
severity: minor
status: unresolved-held
---

# W25 최대 글씨의 가려짐 검증 보류

iPad 최대 글씨의 마지막 Running 캡처에서 Cadence 문구(y858–909)가 고정 Save(y815.5–893)에 일부 가려졌다. 스크롤 위치는 73%였으나 더 내린 통과 캡처가 없어 전체 가독성은 미입증이다. 선택자 통과와 문구 중점의 ScrollView 포함 검사는 가려짐 검사를 대신하지 않는다. 앱 결함이나 이번 변경의 도입 여부를 확정하지 않는다.

공유 증분 컴파일과 정확한 유산소 선택자를 실행했다. Phone 원본은3/7, 같은ID 실패분 재검사는3/4로 닫혔다. iPad는6/7 뒤 실패한 Stair Climber 하나만1/1 통과했다. 이는 Running MAX 하단 문구가 완전히 보인다는 증거가 아니다. 이미 통과한 Running을 다시 실행하거나 실행 ID를 바꿔 우회하지 않았다.

스크롤 중점 포함과 isHittable만으로 고정 footer의 가림을 배제할 수 없다. 다음 허용된 원인 대응 검증에서는 실제 footer 위쪽의 안전 영역과 문구 전체 프레임을 함께 확인해야 한다. 현재 후보는 초안으로 보존하고 통상 머지는 하지 않는다.

[PNG/AX, 실행 결과, 독립 리뷰](../../design/full-redesign-map/review/cardio-summary-w25-2026-11-07/index.html). 검증 소스`324b0b30033583cc8a218805afb6e4b609e55137`와 원본 소스412e를 구분한다. 실제 맵의4개 프로필은 기존 값을 유지한다. 원래 기간·아이콘·저장 로직은 유지했고 Save는 누르지 않았다. Duo 현재 소스 캡처는 대기다.
