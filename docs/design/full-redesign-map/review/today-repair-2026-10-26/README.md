# Today 실제 피드백 수정 캡처

테스트용 데이터로 새로 실행한 네이티브 앱 원본 PNG다. [갤러리](index.html), [출처·해시](evidence.json), [실행 기록](../../../../reviews/2026-10-26-today-repair.md)을 함께 확인한다.

폰·iPad·Duo 외부 T03은 최종 코드에서 각1/1 통과했다. 폰의 기본/최대 글씨·수면·스트레스·지표 상세 복귀 검증은 기록에 명시한 selector 범위다. X 클릭은 추가 실행하지 말라는 사용자 선택에 따라 미검증으로 남긴다. Duo 내부는 실제 active LCD-1을 확인했지만 XCTest의 스트레스 상세 hittability 오류와 검은 캡처로 갱신 미완료다. 수치 힌지 각도 조회도 제공되지 않았다.

`diagnostics/duo-open-rejected-black.png`는 실패 진단이며 앱 화면 완료 증거가 아니다. 원본 테스트 번들은 Xcode 보존 정책으로 정리될 수 있으므로 추출 PNG·SHA-256·실행 receipt를 함께 보존했다.
