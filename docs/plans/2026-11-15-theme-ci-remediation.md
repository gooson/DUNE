---
topic: theme-ci-remediation
date: 2026-11-15
status: implemented
related_pr: https://github.com/gooson/DUNE/pull/993
---

# 테마 PR CI 실패 수정과 최종 머지

사용자가 실패 원인 수정부터 리뷰·머지·정리까지 완료하도록 요청했다. 기존 테마 작업과 실제 캡처는 보존하며 CI 실패 원인에 범위를 확장한다.

1. 원본 실패를 격리한다. iOS2784개 실행에서 live AI 평가2개가9개 assertion에 실패했다. `isAvailable`은 true였지만 Foundation Models safety assets가 없어 실제 생성이 실패했다. Watch는 컴파일 중 기기가 Shutdown/runtime(null)이 되어 단위 테스트를0개 실행했다.
2. 기본 unit과 실제 모델 품질 평가를 분리한다. 기본 unit은6개 운동 intent 경로,9개 Q&A positive scorer fixture, 기존 adversarial negative와 locale/safety/fallback seam을 항상 검증한다. 전용 DUNEAIEvaluations 스킴에서만 live를 opt-in하며 실제 모델 요청·일반 운동3개의 model 출처·Q&A non-fallback·기존 품질 기준·두 테스트의 positive Passed를 모두 요구한다.
3. Watch CI는 jobs2·indexOFF·test직렬화로 generic build-for-testing을 마친 뒤 전용 기기를 부팅한다. CoreSimulator 상태와 runtime, 선택된 Xcode의 destination ID·OS·architecture를 확인하고 test-without-building을 실행한다. 양의 테스트 실행 개수가 없으면 모든 요청 suite를 실패 처리한다.
4. Python 실행기/상태/strict-result 계약41개를 통과했다. 관련 iOS3suite 실행37개는 통과했으며 기본 스킴의 live2개는 의도적으로 비활성이다. 생성 출처 추가 후 최종 컴파일과 unit 검증은 최종 PR CI 결과로 확정한다. 로컬 Watch 통합은 공용 실행권 대기 중 실제 테스트 시작 전에 종료해 전용 CI 실행과 중복하지 않는다.
5. 기존5관점 리뷰를 변경분에 재적용하고 Agent-Native를 추가한다. zero-count P2와 model provenance P2를 수정한다. 최종 compile·CI·PR 리뷰를 확인하고 GitHub merge commit으로 머지한다. 완료된 검증은 재사용하며 앱 화면·테마 렌더러는 이번 후속 변경에서 수정하지 않는다.
6. 머지 후 현재 작업의 원본 증거를 별도 보존하고 소유 simulator·DerivedData·worktree만 정리한다. 기존 primary Watch scheme3개와 다른 활성 Today 작업은 보존한다.

원격 CI의 최종 결과와 merge 상태는 [PR993](https://github.com/gooson/DUNE/pull/993)를 기준으로 확인한다. 실패를 skip·임계값 완화·빈 실행 성공으로 바꾸지 않는다. 단위 CI 통과를 실제 모델 품질 통과로 보고하지 않는다.
