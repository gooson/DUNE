---
tags: [ui-test, ci, nightly, regression, automation]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: UI Test 야간 풀 회귀 강화

## Problem Statement
현재 UI 테스트는 PR 머지 후에만 실행되어, 하루 단위 회귀를 빠르게 탐지하기 어렵다.  
또한 일부 테스트가 UI 문구(텍스트)에 의존해 copy/localization 변경 시 false failure가 발생할 수 있다.

## Target Users
- iOS 앱 개발자
- PR 리뷰어/릴리즈 담당자
- QA/운영 담당자

핵심 니즈:
- 새 기능 추가 이후에도 기존 핵심 플로우가 매일 자동 검증될 것
- flaky test를 줄여 신뢰 가능한 신호를 받을 것

## Success Criteria
- 매일 새벽 1회 자동 UI 회귀 테스트 실행
- 실패 시 로그 artifact로 즉시 원인 추적 가능
- 핵심 smoke 테스트가 접근성 식별자(AXID) 기반으로 동작

## Proposed Approach
1. Nightly 전용 GitHub Actions workflow 추가 (`schedule` + `workflow_dispatch`)  
2. `scripts/test-ui.sh`를 확장해 full/nightly 시나리오 실행 유연성 확보  
3. 앱 코드에 누락된 `.accessibilityIdentifier()` 보강  
4. UI 테스트를 식별자 기반 assertion으로 강화하고 `Thread.sleep()` 의존 제거

## Constraints
- GitHub Actions cron은 UTC 기준으로 동작 (KST 변환 필요)
- HealthKit 권한 테스트는 manual 성격으로 완전 자동화에 부적합
- macOS runner 시간/비용 제한으로 테스트 안정성과 실행 시간을 균형화해야 함

## Edge Cases
- 시뮬레이터 부팅 지연/실패로 인한 false failure
- copy/localization 변경으로 텍스트 기반 selector 실패
- 수동 권한 테스트가 자동 파이프라인에 섞여 불안정성 유발

## Scope
### MVP (Must-have)
- Nightly Full UI Tests workflow 추가 (매일 새벽 실행)
- UI smoke 테스트의 문자열 의존 구간을 AXID 중심으로 치환
- teardown의 고정 sleep 제거

### Nice-to-have (Future)
- iPhone + iPad matrix nightly 실행
- flaky test quarantine/retry 정책 도입
- 테스트 결과 요약 Slack/PR 코멘트 자동화

## Open Questions
- 새벽 실행 시간 고정값(예: 04:00 KST) 유지 여부
- nightly 범위에 iPad 시뮬레이터를 즉시 포함할지 단계적으로 도입할지
- 실패 알림 채널(Slack, email, GitHub only) 우선순위

## Next Steps
- [ ] /plan ui-test-nightly-hardening 으로 상세 구현 계획 정리
