---
source: review/baseline-axis-scope-assessment
priority: p2
status: pending
created: 2026-10-31
updated: 2026-11-02
---

# 기존 공통 DotLine 차트의 날짜 눈금 누락

Xcode 27.2 / iOS 27.2 실제 실행에서 Y 눈금과 수직 grid는 보이지만 X 날짜 글자가 보이지 않는다. 개편 전 clean `0dc77dc4` HRV 캡처에서도 확인했고, baseline·T05·T06의 해당 공통 경로가 같다. 신규 상세 개편의 회귀로 단정하지 않는다.

- 기간 선택·이동·가시 구간 요약·차트 선택은 별도 기능 검증이다. 이들의 통과나 이슈 범위 분리는 날짜 축 해결 또는 전체 개편 완료를 뜻하지 않는다.
- 사용자가 추가 승인한 마스크 한 줄 제외 진단은 2026-11-02 전용 iPhone에서 한 번 실행했다. 월간 plot은 원본과 RGB가 완전히 같았으며 날짜 글자는 나타나지 않았다. 가설은 기각했다.
- 임시 변경은 복원했다. `DotLineChartView.swift` 원본 SHA256은 `a25967703e401bc80311c836aecbcbde88cfa2bee2ca3363ec1e050937da6e14`다. 승인된 추가 진단 잔여 횟수는 0이다.
- 정적 후속 검토에서도 검증 가능한 최소 수정은 찾지 못했다. 원인 불명의 clipping·충돌·가짜 날짜 label을 추가해 해결됐다고 표시하지 않는다.
- 원본 실행·PNG·실패 기록·음성 진단과 복원 증거는 validation checkout의 `.codex-checks/t05/evidence/approved-axis-mask-probe-once-2026-11-02` 및 작업 트리 외부 `native-detail-evidence/pr878-axis-mask-probe-once-2026-11-02`에 보존했다.

재개 조건은 새로 확인한 원인 해결 근거 또는 구체적인 추가 실행 승인이다. 검사 ID·화면·워크트리·턴 변경으로 진단 예산을 우회하지 않는다. 이 문서는 이전 startup snapshot의 같은 TODO를 복구하고 실제 승인·진단 결과를 갱신한 것이다.
