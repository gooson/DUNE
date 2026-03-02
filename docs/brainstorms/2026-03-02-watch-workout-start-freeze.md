---
tags: [watchos, simulator, healthkit, workout-start, freeze]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: Watch Workout Start Freeze (Simulator)

## Problem Statement
워치 시뮬레이터에서 운동 시작 버튼(카디오 Outdoor/Indoor 포함, 근력 Start 포함)을 누르면 로딩 스피너가 계속 돌고 세션이 시작되지 않는다.

## Target Users
- 주요 사용자: 워치 앱 사용자(특히 개발/QA 단계에서 워치 시뮬레이터 사용자)
- 핵심 니즈: 버튼 탭 후 즉시 운동 시작 또는 실패 사유가 명확히 표시되어야 함

## Success Criteria
- 운동 시작 버튼 탭 후 지정 시간(예: 10초) 내에 반드시 다음 중 하나가 발생:
- 세션 시작 화면 진입
- 사용자에게 원인 기반 에러 메시지 표시(권한 미부여/권한 요청 타임아웃/세션 시작 타임아웃)
- 무한 로딩 상태(스피너 고정) 0건

## Proposed Approach
- 공통 시작 경로(`requestAuthorization` + `startHKSession`)에 타임아웃 가드 추가
- 실패 원인을 구분 가능한 도메인 에러로 표준화
- UI에서 도메인 에러를 사용자 메시지로 노출해 재시도/설정 확인이 가능하도록 개선
- 로그를 통해 권한 단계/세션 시작 단계에서 어디가 지연되는지 구분

## Constraints
- 실기기(Apple Watch) 미검증 상태
- 정확한 Xcode/watchOS 빌드 번호 미기록(“최신”)
- HealthKit 권한/시뮬레이터 프라이버시 상태가 환경별로 편차 가능

## Edge Cases
- 권한 대화상자가 OS에서 지연/미표시되는 경우
- 권한은 승인됐지만 `beginCollection`이 반환되지 않는 경우
- 사용자가 권한을 거부한 상태에서 반복 시도하는 경우
- iPhone 연동 상태/시뮬레이터 상태 불안정으로 HealthKit 콜백이 늦는 경우

## Scope
### MVP (Must-have)
- 공통 운동 시작 경로 무한 대기 제거(타임아웃)
- 에러 타입 분리 + 사용자 메시지 노출
- 근력/카디오 모두 동일하게 적용

### Nice-to-have (Future)
- 실기기/시뮬레이터 분리 진단 로그 수집 체계
- 시작 실패 자동 복구(재시도 제안/재시도 버튼)
- 시작 경로 자동화 테스트(시뮬레이터 환경 제한 고려)

## Open Questions
- 실기기에서도 동일 증상이 재현되는가?
- 특정 시뮬레이터 런타임 버전에서만 재현되는가?
- 권한 요청 단계 vs 세션 수집 시작 단계 중 실제 병목 비율은?

## Next Steps
- [ ] 공통 시작 경로에 timeout + 원인별 에러 분기 적용
- [ ] 워치 시뮬레이터에서 근력/카디오 시작 경로 재검증
- [ ] /plan watch-workout-start-freeze 로 후속 개선 계획 구체화
