# Today support cards `/run` 검증 기록

기준f4d56f63, 제품 코드2c1380d4, 최신 검사 수정330dd2eb. 자동 재시도 한도 이후 추가 실행 승인 대기.

## 소스 검토 준비 결과

전체 텍스트 diff가2000줄 이상이어서 parent가 Security·Performance·Architecture·Data Integrity·Simplicity 관점을 직접 검토했다. 새 외부 전송·저장 변경·View body 조회·레이어 의존성 위반은 확인하지 않았다. Agent-Native는 관련 지침 변경이 없어 제외했다. en/ko/ja 및 카탈로그 형식을 확인했다.

Work의 SwiftUI 검토에서 지표보다 먼저 공개한 수면 단계 P2를 찾아 Sendable 결과로 함께 반환하고 request guard 뒤 함께 반영했다. 회귀4건이 통과했다. Apple UX의 단계 의미를 색에만 의존하는 P2와 Hours 누락P3는 범례/구간 접근성/단위로 해결했다. 앱 품질의 브리핑 존재 검사 누락P2는 필수 assertion으로 해결했다. 별도 source 재검토에서 모두 확인했다. 대량 데이터 처리 변경이 없어 perf-optimizer 전문가는 적용하지 않았다.

새 코드 findings는 P1=0, open P2=0, P3=0이다. 기존 날씨 실패→위치 권한 안내와 수면 결손 보존은 기준 코드에도 있어 별도 기존 항목으로 구분한다.

## 실행 결과와 게이트

iOS 빌드 성공. 단위4/4 통과. 최초 단위0개 실행은 증거에서 제외했다. 첫 UI32개 중29개 통과3개 실패, Today 재검증2개 중1개 통과1개 실패. 실제 실패 프레임은 카드(16,257.667,370,533.333), 실제 탭바 상단791pt, 검사 뷰포트 아래787pt다. 임의4pt 여유를 제거한330dd2eb는 구문·diff 검사를 통과했으나 아직 UI 재실행 결과가 없다.

알림 실패 화면은 자동 브리핑 시트였으며 기준 DashboardView의 동일한 자동 표시 predicate를 확인했다. 기준 소스2건 비교는 다른 worktree의 저장소 잠금으로 시작하지 못했다. 이를 기준 테스트 통과나 실행으로 계산하지 않는다.

필수 UI 게이트 미완료로 정식 Review 이후 게이트·Compound·Ship는 완료 처리하지 않는다. iPad·Duo와 전체 회귀는 미실행이다. 실 캡처와 기기·revision·결과 번들은 [실제 화면 출처](../design/full-redesign-map/review/today-support-cards-2026-10-24/capture-index.json)에 있다.
