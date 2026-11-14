---
tags: [review, ci, foundation-models, watchos]
date: 2026-11-15
status: reviewed
---

# CI 후속 수정 리뷰

Security·Performance·Architecture·Data Integrity·Simplicity·Agent-Native6관점을 변경분에 적용했다. 최종 코드의 미해결 P1/P2/P3는 없다. 이 판정은 최종 원격 CI 통과를 대신하지 않는다.

- Data P2: 암묵적 전체 Watch suite 요청에도 양의 실행 개수를 요구하도록 수정했다. 성공 exit와0개/unknown 로그를 거절하는 회귀 계약을 추가했다.
- Agent-Native P2: 운동 fallback을 모델 응답으로 오인하지 않도록 실제 생성 출처를 반환한다. 모델·intentBuilder·recoveryBuilder의5개 성공 경로를 확인했고, 일반 운동3개 live sample은 model 출처를 요구한다. 기존 앱 API는 같은 template을 반환한다.
- Security: argv 배열·경로 quoting, 환경변수 opt-in, 두 실제 Passed 결과 요구 확인. 인증·개인정보 동작은 변경하지 않았다.
- Architecture·Simplicity: 기본 unit과 live 모델 품질 평가를 구분하고, 기존 표준 실행기·캐시·소유권·deadline을 재사용한다. 결과 출처 API는 평가에 필요한 범위로 한정한다.
- Performance: 모델 호출·재시도·fallback 계산은 그대로다. Watch는 한 번만 컴파일하고 같은 DerivedData로 test-without-building을 수행한다.

Python 계약41개, shell 구문, generated live-scheme 환경변수와 default scheme 비활성을 확인했다. iOS관련3suite의37개 등록 테스트 실행은 완료했고 live2개는 기본 실행에서 비활성이다. 이후 추가한 생성 출처의 최종 컴파일·회귀와 Watch 플랫폼 통합은 최신 PR993 CI 결과로 확정한다. 로컬 Watch는 공용 실행권 대기 중 실제 테스트 전에 종료했고 성공으로 계산하지 않았다.
