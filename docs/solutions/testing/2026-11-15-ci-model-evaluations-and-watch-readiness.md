---
tags: [ci, foundation-models, model-assets, swift-testing, simulator, watchos]
category: testing
date: 2026-11-15
severity: important
related_files: [DUNETests/AIFeatureEvaluationTests.swift, DUNE/Data/Services/AIWorkoutTemplateGenerator.swift, scripts/test-unit.sh, scripts/lib/verify-simulator-ready.py]
---

# Solution: 실제 모델 평가와 단위 CI, Watch 부팅 수명을 분리하기

## Problem

일반 단위 CI가 Foundation Models의 정적인 isAvailable만 믿고 실제 모델 품질 평가를 실행했다. CI에서는 이 값이 true여도 safety asset이 없어 요청이 실패했다. Q&A fallback이 언어·근거·안전 품질 실패처럼 기록됐고 운동 생성3건은 오류로 끝났다. Watch는 테스트 전에 부팅해 둔 기기가 긴 컴파일 뒤 Shutdown/runtime(null)이 되어0개 테스트로 실패했다.

## Solution

- DUNETests 기본 스킴에는 모델 호출 없는6개 실제 운동 intent 경로와9개 Q&A scorer fixture, 기존 negative·locale·safety·fallback 검사를 둔다. live 평가2개는 명시적 DUNEAIEvaluations 스킴의 test-process 환경변수로 활성화한다.
- 전용 실행은 availability와 실제 응답 probe를 모두 요구한다. Q&A fallback과 semantic judge 오류는 실패다. 운동 생성 결과에는 model·intentBuilder·recoveryBuilder 출처를 붙이며 기존 앱 API는 같은 template을 반환한다. 일반 운동3건은 model 출처여야 품질 평가를 통과한다. 이름 문자열로 모델 출처를 추정하지 않는다.
- 기존 품질 임계값과 test identifier를 유지하고 xcresult에서 두 live 메서드가 실제 Passed여야 성공한다. 전용 실행의 skip·누락을 성공으로 취급하지 않는다.
- CI의 Xcode 선택은 작업별 DEVELOPER_DIR로 고정해 xcrun과 xcodebuild가 같은 설치를 사용하게 한다. 전역 xcode-select를 수정하지 않는다.
- Watch CI는 generic simulator build-for-testing 후 부팅하고 즉시 CoreSimulator와 Xcode 양쪽의 준비 상태를 대조한다. 같은 DerivedData의 test-without-building을 사용해 다시 컴파일하지 않는다. jobs2·indexOFF·test직렬화는 Watch 작업에만 적용한다.
- 어떤 suite도 실행 개수0 또는 개수 없는 success 로그로 통과시키지 않는다. bootstatus0만으로 정상 runtime을 추정하지 않는다.

## Prevention

1. 모델 availability, inference readiness, 실제 품질은 별도 조건이다. 일반 unit이 모델 다운로드·비결정적 생성에 의존하지 않게 한다.
2. feature fallback을 model 응답 성공이라고 표시하지 않는다. live의 model-specific sample에는 실제 생성 출처를 요구한다.
3. SDK와 runtime readback에 null·unknown이 있으면 실패다. Xcode destination의 ID·OS·architecture를 CoreSimulator와 함께 확인한다.
4. 컴파일하는 동안 simulator를 미리 오래 부팅해 두지 않는다. 검증·빌드·대기는 각각 소유 프로세스 deadline을 둔다.

## Lessons Learned

원래 실패 로그는 [보존 목록](../../design/full-redesign-map/review/theme-overhaul-2026-11-14/evidence/ci-remediation-files.json)에 남겼다. Python 계약41개와 관련 unit 실행을 분리해 기록하고, 최종 플랫폼 통합 검증은 PR993의 실제 CI 결과를 사용한다. 테마 UI 증거와 단위·live AI·CI 환경 결과를 섞지 않는다.
