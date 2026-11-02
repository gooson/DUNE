---
source: pr879-current-ci-scope-assessment
priority: p2
status: pending
created: 2026-11-02
updated: 2026-11-02
---

# 라이브 AI 평가 CI의 모델 파일 사전 조건

[T06 iOS CI 작업](https://github.com/gooson/DUNE/actions/runs/41398695641/job/125125562561)에서 2,733개 검사·302개 suite를 실행했으나 라이브 AI 평가 두 개가 9개 issue로 실패했다. 실제 오류는 Foundation Models의 `com.apple.gm.safety_embedding_deny.all`과 `com.apple.gm.safety_deny.input.foundation_models_framework.api`가 Model Catalog에 없다는 내용이다.

`AIFeatureEvaluationTests`는 `SystemLanguageModel.default.isAvailable`일 때 실제 모델 평가를 켠다. 이번 환경에서는 이 조건이 켜졌지만 safety asset이 준비되지 않아 Q&A의 fallback과 템플릿 생성 오류가 평가 목표를 충족하지 못했다. 이 실패만으로 실제 모델의 언어·안전·grounding 품질을 평가할 수 없다. 정상 환경에서의 AI 품질 통과로도 표시하지 않는다.

T06의 7개 관련 suite와 Watch 213개 검사는 별도로 통과했다. 변경 없는 AI 평가 파일·서비스·자료의 소스 동등성은 T06 최종 품질 검토에 기록한다. 이전 T05 iOS 통과 로그에서 두 라이브 AI 평가는 skip이었으며 AI 생성 회귀 통과 근거가 아니다. 원래 실패 로그와 CI 상태를 보존한다.

후속 작업은 실제 모델 asset 사전 조건과 실행 환경을 분리하고, 건강한 모델 환경에서 라이브 평가를 검증하는 것이다. 평가 assertion을 약화하거나 모델 오류를 성공으로 바꾸지 않는다. T06 화면 변경 안에서 unrelated AI 테스트나 공통 실행기를 수정하지 않았다.
