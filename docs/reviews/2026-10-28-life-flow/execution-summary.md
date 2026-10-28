# Life Flow /run · 실행 증거

구현 계획과 Astra 자문을 통합해 네이티브 Life를 개편했다. 각 단계의 실제 산출물과 검증 범위를 아래에 기록한다. PR 머지·정리 결과는 최종 실행 응답과 GitHub PR 상태를 따른다.

| Phase | 완료 근거 |
|---|---|
| 0 Init | 제공된 worktree·codex/life-flow·전용 기기 소유권 및 지침 확인 |
| 1 Plan | docs/plans/2026-10-28-life-flow-native.md와 두 계획 통합 문서, 화면 배치·테마 계약 |
| 2 Work | 네이티브 히어로/카드/분류·지난 기록·공통 로그 해석, 단계별 커밋, main 통합 |
| 2.5 UI | Life 최신26통과·옵트인3skip, iPad1통과, Duo외부/내부 각3통과; verification.json와 원본 receipts |
| 3 Review | security/performance/architecture/data/simplicity 및 후속 agent-native/delta review, 미해결P1/P2/P3=0 |
| 3.5 Quality | SwiftUI·UX·app-quality 리뷰, 관련unit113/9suite, generic iOS build 성공, 원본 증거와 소스 일치 확인 |
| 4 Resolve | findings.json의 기존 발견사항 전부Resolved; 키보드·Form·주간/예정 regression 실제 완료 |
| 5 Compound | architecture/2026-10-28-life-daily-totals-and-accessibility.md와 testing/2026-10-29-simulator-keyboard-and-visible-form.md |
| 5.5 Pre-Ship | 카탈로그·테마맵·parity·PNG SHA 검증, 문서 링크/최종 diff, PR base/원격 head/CI 확인 |
| 6 Ship | 대상 PR#854. GitHub merge API 머지 → 원격/로컬 feature branch·소유 simulator·build artifacts 정리 → 표준 Xcode 프로젝트 재생성. 최종 완료는 PR 상태와 실행 응답에서 확인 |

UI 표는 전체 suite가 아니라 변경 영향 Life 범위의 최종 결과다. 최초 실패·추가 허용 실행 실패·SDK screenshot 타임아웃을 유지한다. 앱·unit·Shared 소스는62d3c097 이후 동일하며 이후 테스트 helper/host appearance split 변경에 대응한 별도 컴파일·선택 실행을 보존한다. 문서 fingerprint 변경을 이유로 과거 자동 테스트 receipt를 새 성공으로 위장하지 않는다.

## 변경 확인 방법

1. Life에서 골드 능선/링/남은 수와 오늘 카드, 목적 필터를 확인한다. 필터를 바꿔도 hero 분모는 그대로다.
2. 오늘 습관의 ±/시간 편집과 취소를 확인한다. 완료 목록을 접고 펼친다.
3. 지난 기록에서 어제 총합을 바꾸고 같은 날짜 재저장 시 덧셈되지 않는지 확인한다. 미래/등록 이전/자동 기록/잘못된 입력은 저장되지 않아야 한다.
4. 오늘·주간·다가오는 일정이 분리되고 예정 습관이 오늘 분모에 들어가지 않는지 확인한다.
5. 실제 기록 기반7일·28일 리듬, Activity Detail 히트맵/완료율, Weekly Report를 확인한다.
6. 실제 화면 갤러리의 기기별 기본·다크·최대글씨와 원본 소스/해시를 대조한다. 큰 글씨 폼은 스크롤 viewport이며 전체 VoiceOver·전체 테마·CloudKit 실전 전송 검증을 의미하지 않는다.
