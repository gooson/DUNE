# 통합 실제 화면 포털

2026-11-14 [알림 상세 수치 강조의 새 실제 화면](../../full-redesign-map/review/notification-cardio-2026-11-14/index.html)을 보존했다. iPhone 기본·다크 최대 글씨, iPad 기본, Duo 접힘의 T12를 확인하고 해당 세 기기 기본 PNG와 Today 보드를 갱신했다. Duo 펼침은 setter 이후에도 LCD active/LCD-1 inactive로 남아 미갱신이다. Watch C01·C02는 마지막 한 줄 지표 보정을 새40mm PNG2장으로 갱신했고 관련 UI3/3이 통과했다. 큰 글씨·AOD·VoiceOver는 별도 미검증이다.

[포털 열기](index.html)

2026-10-28 Life Flow의 [새 iPhone 네이티브 실제 화면 10장](../../full-redesign-map/review/life-flow-2026-10-28/index.html)을 별도 갤러리에 보존했다. 실행 소스 `19f43ee3`의 XCTest 첨부를 복사했으며, 테스트별 통과와 후속 실패를 이미지마다 구분한다. L01/L09 종합 테스트와 주간 비교 테스트는 후속 단계에서 실패했고, iPad·Duo·L07 차트 최종 검증 및 L08/L09 어두운 모드·최대 글씨 캡처는 없다. 이 링크를 UI 게이트나 최종 병합 검증 완료로 해석하지 않는다. 자세한 범위, 시각 확인, 원본 해시는 [갤러리 기록](../../full-redesign-map/review/life-flow-2026-10-28/README.md)을 따른다.

기존 `regular`, `ipad`, `duo`, `duo-open` 기기별 인덱스와 보드는 이전 실행의 자료로 보존한다. 새 Life Flow PNG로 덮어쓰거나 현행 구현 확인 완료로 표시하지 않았다.

## Life 추가1회 검증

최신 dd18af04의 통과한 캡처 경로에서 원본15장을 추가해 Life 갤러리는총25장이다. L01/L09 밝음·다크·최대글씨와 L07/L08 밝음을 새로 보존했다. 표준 runner는2통과·1실패(exit65)다. 주간/예정 검사는 New Habit 메뉴에서 폼이 열리지 않아 미확인이다. iPad/Duo와 L08 다크·최대글씨도 남아 있으므로 맵 전체나 UI 게이트 완료로 표시하지 않는다.

## Life Flow 최종 갱신 · 2026-10-29

[Life Flow 실제74장](../../full-redesign-map/review/life-flow-2026-10-28/index.html)에 새 iPhone·iPad·Duo 외부/내부 원본을 갱신했다. L01/L09는 밝음·다크·최대글씨, L07/L08은 밝음이며 최대글씨 폼은 스크롤 viewport다. 68장은 통과 실행,6장은 초기 실패 부분 증거로 구분했다. 과거 기기별 인덱스의 PNG는 새 기기 출처로 덮어쓰지 않는다. [검증 범위와 receipt](../../../reviews/2026-10-28-life-flow/README.md)를 따른다. Watch UI는 변경하지 않았다.

- [H09 부상 이력 현재 실제 검토](../../full-redesign-map/review/h09-injury-history-native-2026-11-05/index.html): 611d70b1 네 프로필·다섯 SDK 사례·열 PNG/AX 쌍. 이전 네 PNG는 정체성 참고입니다.

2026-11-14 W34 is the embedded W13 AI state, not a separate route. [Actual positive evidence and failed iPad MAX diagnostics](../../full-redesign-map/review/ai-workout-builder-w34-2026-11-14/index.html) now include approved extra iPad MAX 1/1 positive evidence; two earlier MAX failures remain preserved. Scoped Phone/iPad UI verified; no actual generation was requested.

2026-11-14 W12: [실제 범위 한정 캡처](../../full-redesign-map/review/workout-template-list-w12-2026-11-14/index.html). Phone MAX와 iPad normal/MAX 표적 UI, Phone normal은 Nov 7 역사 기록; 이전 HELD 원본 보존.

2026-11-14 W11: [Phone/iPad normal/MAX 실제 캡처](../../full-redesign-map/review/share-image-w11-2026-11-14/index.html). Share action 표시·도달성 검증; OS 공유 시트는 열지 않았다. Nov 7 HELD 원본 보존.

2026-11-14 W15: [Phone MAX/iPad normal/MAX 실제 캡처](../../full-redesign-map/review/weekly-workout-plan-w15-2026-11-14/index.html). Phone normal은 Nov 7 통과 이력을 별도 표기하며 새 캡처로 간주하지 않는다.

2026-11-14 W31: [Phone·iPad 일반/MAX 실제 캡처](../../full-redesign-map/review/all-sets-done-w31-2026-11-14/index.html). iPad 일반·MAX 검증; Nov 7 HELD 원본은 새 캡처로 간주하지 않는다.


2026-11-14 [P03 Phone/iPad/Duo 일반/MAX 새 원본과 출처](../../full-redesign-map/review/posture-exercise-picker-p03-2026-11-14/index.html). 혼합 배치와 과거 실패는 해당 갤러리에 보존한다.
