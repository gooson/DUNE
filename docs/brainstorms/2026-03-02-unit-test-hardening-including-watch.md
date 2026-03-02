---
tags: [unit-test, watchos, quality, coverage, regression]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: 유닛 테스트 전면 강화 (Apple Watch 포함)

## Problem Statement
현재 iOS 앱(`DUNETests`)은 유닛 테스트가 폭넓게 존재하지만, Watch 앱(`DUNEWatch`)은 상대적으로 UI Smoke 테스트 중심으로 구성되어 있다.  
이로 인해 Watch 로직 회귀가 늦게 발견되거나, 릴리즈 직전 수동 확인 부담이 커질 수 있다.

## Target Users
- iOS/watchOS 개발자
- 리뷰어/릴리즈 담당자
- QA 담당자

핵심 니즈:
- iPhone + Apple Watch 핵심 로직이 PR 단계에서 안정적으로 검증될 것
- 회귀 탐지 시간을 단축하고 수동 테스트 의존도를 줄일 것

## Success Criteria
- iOS/Watch 공통 핵심 도메인 로직에 대한 유닛 테스트 매트릭스 정의 완료
- Watch 핵심 로직(Manager/Helper/Validation)의 유닛 테스트 커버리지 확보
- PR 기준 테스트 실패 시 원인 역추적 가능한 로그 확보
- 새 로직 추가/변경 시 테스트 동반 작성 규칙을 팀 표준으로 고정
- 릴리즈 안정성을 최우선 지표로 운영

## Proposed Approach
1. **테스트 인벤토리 작성**
   - `DUNE`/`DUNEWatch`의 로직 단위를 UseCase, Service, ViewModel, Manager로 분류
   - 각 단위별 기존 테스트 유무/중요도/리스크를 매핑
2. **Watch 테스트 가능 구조 정리**
   - Watch 전용 로직 중 순수 계산/검증 코드를 우선 추출해 테스트 가능한 단위로 분리
   - 의존성(시간, 저장소, 연결 상태)을 프로토콜 기반으로 주입 가능하게 정리
3. **우선순위 기반 테스트 추가**
   - High Risk: 데이터 변환, 동기화 상태 판단, 입력 검증
   - Medium Risk: 화면 상태 계산, 포맷팅/표시 규칙
4. **실행 체계 통합**
   - 로컬/CI에서 iOS + Watch 테스트를 분리 실행하되, PR 게이트에서 핵심 세트는 필수화
   - 실패 리포트 형식을 통일해 디버깅 시간을 단축

## Constraints
- watchOS 타깃은 UI/시뮬레이터 안정성 이슈로 E2E 자동화 비용이 높을 수 있음
- HealthKit/WatchConnectivity 실제 연동은 완전한 단위 테스트로 대체하기 어려움
- 기존 코드가 테스트 가능하도록 분리되지 않은 경우 구조 개선 비용이 발생함

## Edge Cases
- WatchConnectivity 지연/끊김 상황에서 상태 계산이 잘못되는 케이스
- 데이터가 비어 있거나 부분 손상된 경우 (nil, NaN, 음수, 범위 초과)
- 앱 버전 차이로 iPhone/Watch 데이터 스키마가 어긋나는 경우
- 백그라운드 전환/재개 시 상태 동기화 순서 역전

## Scope
### MVP (Must-have)
- iOS/Watch 로직 테스트 갭 분석표 작성
- Watch 핵심 로직(최소 3~5개 타입)에 유닛 테스트 추가
- 경계값/에러/빈 데이터 케이스를 포함한 방어 테스트 보강
- PR 체크리스트에 “로직 변경 시 테스트 동반” 규칙 명시
- PR 게이트에 iOS + Watch 유닛 테스트를 모두 필수화

### Nice-to-have (Future)
- Watch 전용 Unit Test 타깃 표준화 (예: `DUNEWatchTests`)
- 변경 파일 기반 테스트 셀렉션(Selective Test) 도입
- 커버리지 리포트 시각화 및 임계치 게이팅

## Decisions (사용자 확정)
- 우선 목표: 릴리즈 안정성
- 커버리지 목표: 100%
- PR 게이트: 필수
- 우선순위: iOS/Watch 동시 강화
- 구현 범위: 테스트 추가 중심 (리팩터링 제외)
- 제외 범위: HealthKit 실연동 등 실기기 필요 시나리오

## Next Steps
- [ ] 사용자 답변 반영 후 `/plan unit-test-hardening-including-watch`로 구현 계획 구체화
