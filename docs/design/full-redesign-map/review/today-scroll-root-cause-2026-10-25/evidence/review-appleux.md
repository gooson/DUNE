# Apple UX review — Today scroll root cause

검토일: 2026-10-25
범위: `/tmp/scroll-debug/final-code-review.diff`와 현재 `ContentView`, `DashboardView`, `WaveRefreshIndicator`, `WaveRefreshTaskCoordinator`, `HealthDataQASheet`의 관련 코드. 역할 지침은 `.claude/agents/apple-ux-expert.md`, 설계 기준은 apple-design 스킬의 principles/platforms/layout/accessibility 참조를 적용했다.

## 판정

**새 변경에서 조치가 필요한 P1/P2/P3 UX 결함을 확인하지 못했다.** 이 변경 범위의 Apple UX 검토는 통과한다. 별도 빌드나 시뮬레이터 실행 없이 소스, 제공된 실제 캡처, 완료된 테스트 영수증을 검토했다. 전체 앱 접근성 인증이나 모든 기기/설정 검증을 뜻하지 않는다.

## 근거별 확인

### 소스

- 수동 스크롤의 감속 종료 때 130pt 이내를 강제로 상단 정렬하던 코드를 제거했다. 프로그램 상단 이동은 사용자가 Today 탭을 다시 선택한 신호에서만 수행한다. 작은 드래그의 정지 위치를 존중하고 기본 스크롤 관성을 유지하는 변화다.
- Today `NavigationStack` 외부에 inspector 호스트를 두며, 큰 제목을 숨기거나 시스템 safe area를 고정 수치로 보정하지 않았다. 기존 metric/QA 내용과 열 너비, 별도 metric `NavigationStack`, All Data 목적지는 유지된다.
- metric 열기는 QA 선택을 해제하고, QA 열기는 metric 선택을 해제한다. inspector의 시스템 닫힘 binding은 둘 다 초기화하며, metric Done과 QA의 환경 dismiss 경로가 보존된다. 두 내용의 선택이 동시에 남는 새 경로는 찾지 못했다.
- refresh coordinator는 재렌더링으로 취소된 호출자와 실제 새로고침 작업의 수명을 분리하며, 중복 호출을 같은 작업으로 합친다. 화면이 사라질 때 명시적으로 취소하고 `defer`에서 표시기를 정리한다. native `.refreshable` 제스처와 “Refreshing” 접근성 레이블을 유지한다.
- 파형의 기존 Reduce Motion 분기와 탭 재선택 애니메이션을 유지한다. 새 반복 애니메이션이나 제스처를 추가하지 않는다. 기존 전환 애니메이션/탭 재선택의 모든 Reduce Motion 동작을 이번 정적 검토로 인증하지는 않는다.

### 실제 PNG

직접 `view_image`로 다음 원본을 확인했다.

- iPhone: `/tmp/scroll-debug/owner-fix-iphone-attachments/F75C9899-852E-47B4-83A7-DECE04517DB1.png`
- iPad: `/tmp/scroll-debug/owner-fix-ipad-attachments/A74A2FD7-7BD3-4EB7-910C-53B4A0696C7A.png`

두 화면 모두 큰 Today 제목과 Condition 카드 사이에 명확한 간격이 있고, 카드가 제목/툴바 아래로 파고들지 않는다. iPad는 중앙의 읽기 폭을 유지하고, iPhone은 화면 폭에 맞게 첫 카드가 배치된다. 제목/툴바/카드 내용의 잘림이나 새 중첩은 관찰하지 못했다. 정지 이미지는 스크롤 중 프레임의 매끄러움을 단독으로 입증하지 않는다. 이 두 PNG에는 열린 inspector가 없으므로 열린 패널의 외관을 이 이미지로 검증했다고 주장하지 않는다.

### 기존 런타임 결과 재사용

직접 읽은 `/tmp/scroll-debug/owner-fix-iphone-ui.log.result.json`은 실행 10, 통과 10, 실패/누락 0이다. 수동 복귀, 반복 전체 스와이프, 부분 스크롤 정지 유지, native 새로고침의 hold 유무, 탭 재선택, 탭 왕복, metric 열기/닫기/재열기/All Data, QA 열기, Activity 새로고침이 포함된다.

직접 읽은 `/tmp/scroll-debug/owner-fix-ipad-ui.log.result.json`은 실행 4, 통과 4, 실패/누락 0이다. 수동 복귀, 반복 전체 스와이프, metric 상세 흐름, QA 열기를 포함한다. 이는 부모가 실행한 premerge 결과의 재사용이며, 이 검토자가 새로 실행한 테스트가 아니다.

## 설계 원칙 판정

| 원칙 | 변경 범위 판정 | 근거 |
|---|---|---|
| Purpose | 부합 | 건강 내용을 읽는 핵심 동작인 스크롤 복귀의 불안정을 다룬다. |
| Agency | 부합 | 감속 종료의 자동 상단 이동을 없애 사용자가 멈춘 위치를 보존한다. |
| Responsibility | 해당 없음 | 데이터 수집·권한·개인정보 표시를 변경하지 않는다. |
| Familiarity | 부합 | 기본 ScrollView, 큰 제목, native refresh 및 inspector를 유지한다. |
| Flexibility | 부합(검토 범위 한정) | iPhone/iPad 배치와 핵심 동작 결과가 있고 기존 Reduce Motion 분기를 보존한다. 전체 보조기술 검증은 아니다. |
| Simplicity | 부합 | 별도 보정 제스처/표시를 추가하지 않고 화면 소유 관계를 정리한다. |
| Craft | 부합 | 큰 제목과 첫 카드의 간격, 스크롤 복귀, inspector 상세 연속성을 실제 증거로 확인했다. |
| Delight | 부합 | 기존 파형 피드백을 유지하면서 사용자 스크롤을 방해하던 자동 보정을 제거했다. |

## 검증 한계

QA의 Done, inspector가 열린 동안 외부 알림이 들어오는 조합, VoiceOver/대형 Dynamic Type/Reduce Motion 활성 상태의 실제 실행은 제공된 선택 테스트로 입증되지 않았다. 소스에서 명백한 새 결함을 찾지 못했으므로 이 미검증 조합을 결함으로 보고하거나 차단 요구로 확장하지 않는다. Duo 결과는 이 보고서 근거에 포함하지 않는다. `cannot add handler to 0 from 0 - dropping` 로그의 제거 여부 역시 이 UX 검토의 결론이 아니다.
