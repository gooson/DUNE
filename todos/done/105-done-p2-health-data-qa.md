---
source: brainstorm/apple-on-device-ml-sdk-research
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# 건강 데이터 Q&A (Foundation Models)

## 설명

사용자가 자연어로 건강 데이터에 대해 질문하면 Foundation Models가 shared snapshot과 compact HealthKit 요약을 바탕으로 답변합니다.

## 구현 범위

- Tool Calling 프로토콜로 condition, sleep, workout, recovery 요약 도구 정의
- `LanguageModelSession` 기반 멀티턴 대화 지원
- Today 탭 Dashboard 진입 카드 + Q&A sheet UI 추가
- unsupported device / 추론 실패 fallback 처리
- Swift Testing 기반 서비스/뷰모델 회귀 테스트 추가

## 결과

- `DUNE/Data/Services/HealthDataQAService.swift`에 compact summary 기반 Q&A 서비스 구현
- `DUNE/Presentation/Dashboard/*`에 Q&A 카드, 시트, view model 추가
- `DUNETests/HealthDataQAServiceTests.swift`, `DUNETests/HealthDataQAViewModelTests.swift`로 요약/상태 전이 회귀 고정

## 검증 메모

- 로컬 빌드/테스트는 여러 차례 실행했지만 이 환경에서는 `xcodebuild`/스크립트 프로세스가 `Terminated: 15`로 중단되어 완료 로그를 끝까지 확보하지 못함
- 중단 전 로그에는 추가 `error:`가 남지 않았고, 리뷰 중 발견한 draft 유실/day-window 버그는 코드와 테스트로 보강함

## 참고

- `docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md` Section 7.2
- `docs/plans/2026-03-09-health-data-qa.md`
- `docs/solutions/architecture/2026-03-09-health-data-qa-tool-calling.md`
