# Code Review Report

> Date: 2026-03-06
> Scope: 전체 코드베이스(앱/워치/위젯) 정적 점검 + 핵심 고위험 파일 심층 리뷰
> Files reviewed: 434개(자동 패턴 스캔), 심층 8개

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | Must fix before merge |
| P2 - Important | 3 | Should fix |
| P3 - Minor | 2 | Nice to fix |

## P1 Findings (Must Fix)

- 없음

## P2 Findings (Should Fix)

### [Security Sentinel + Data Integrity Guardian] WatchConnectivity 메시지로 원격 삭제가 즉시 수행됨

- **File**: `DUNEWatch/WatchConnectivityManager.swift:318`
- **Category**: security, data
- **Issue**: `deleteWorkoutUUID` 값이 들어오면 별도 사용자 확인, 출처 검증, 재실행 방지 토큰 없이 바로 `deleteWorkoutFromHealthKit`를 호출합니다.
- **Risk**: 페어링된 iPhone 경로가 오동작하거나 메시지 재전송/오염 시 의도치 않은 HealthKit workout 삭제 가능성이 있습니다.
- **Suggestion**:
  - 삭제 명령에 대해 `requestId` + 짧은 유효기간 + 최근 처리 ID dedupe를 추가하세요.
  - 최소한 watch 측에서 최근 N초 내 중복 UUID 삭제를 차단하고, 세션 상태(활성 운동 중/종료 직후) 기반 가드를 두세요.
  - 고위험 경로는 사용자 확인 UX(토글 또는 1회 승인)도 검토하세요.

### [Localization Verification] 일부 사용자 노출 문자열이 `Localizable.xcstrings`에 누락됨

- **File**: `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift:124`, `DUNEWatch/Views/SessionSummaryView.swift:166`
- **Category**: data (i18n consistency)
- **Issue**: 문자열 리터럴이 UI에 직접 사용되지만 로컬라이제이션 리소스에 키가 존재하지 않는 케이스가 확인되었습니다(예: `Cardio Metrics`, `Workout Intensity`).
- **Risk**: 다국어 빌드에서 영어 fallback 노출/번역 누락/QA 누락이 반복될 수 있습니다.
- **Suggestion**:
  - 누락 키를 `DUNE/Resources/Localizable.xcstrings`, `DUNEWatch/Resources/Localizable.xcstrings`에 en/ko/ja 3개 언어로 등록하세요.
  - PR 체크에 “신규 사용자 노출 문자열 → xcstrings 키 동시 추가”를 강제하는 린트 스크립트를 추가하세요.

### [Architecture Strategist + Simplicity Reviewer] 치명 경로에서 `fatalError`로 앱/워치 즉시 종료 가능

- **File**: `DUNE/App/DUNEApp.swift:83`, `DUNEWatch/DUNEWatchApp.swift:27`
- **Category**: architecture, simplicity
- **Issue**: 영속 스토어 실패 후 in-memory fallback마저 실패하면 `fatalError`로 프로세스를 즉시 종료합니다.
- **Risk**: 드문 환경 이슈(스토리지/마이그레이션/권한 꼬임)에서 복구 가능한 장애가 강제 크래시로 전환됩니다.
- **Suggestion**:
  - 최소 기능 safe mode(읽기 전용/온보딩 리셋 안내)로 degrade하고, 사용자에게 복구 액션을 제시하세요.
  - 크래시 대신 telemetry + 재시도 제한(backoff)으로 장애 관찰 가능성을 확보하세요.

## P3 Findings (Consider)

### [Performance Oracle] `autoAchievementInputSignature`가 body 경로에서 반복 해시 계산

- **File**: `DUNE/Presentation/Life/LifeView.swift:181`
- **Category**: performance
- **Issue**: `exerciseRecords.prefix(200)` 전체를 순회해 시그니처를 계산하고 `onChange` 트리거에 사용합니다.
- **Suggestion**:
  - ViewModel에서 증분 계산 캐시를 두거나, SwiftData fetch 자체를 필요한 필드/기간으로 축소하세요.
  - `@Query` 결과 변화당 1회 계산되도록 명시적 메서드 트리거로 이동하세요.

### [Architecture Strategist + Simplicity Reviewer] 대형 View 파일로 책임 집중

- **File**: `DUNE/Presentation/Life/LifeView.swift` (750 lines), `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` (417 lines), `DUNEWatch/Views/MetricsView.swift` (412 lines)
- **Category**: architecture, simplicity
- **Issue**: 단일 파일에 레이아웃/상태/비즈니스 분기/유틸 포맷팅 로직이 함께 존재해 변경 영향 범위가 큽니다.
- **Suggestion**:
  - 섹션 단위 하위 View + ViewState DTO로 분리하고, 계산 로직은 ViewModel/Service로 이동하세요.
  - 우선순위는 재사용 빈도 높은 카드/메트릭 섹션부터 점진 분리하는 방식이 안전합니다.

## Positive Observations

- `LifeView`에서 `@Query` 관찰 범위를 분리해 부모 리레이아웃을 줄이려는 구조적 최적화가 반영되어 있습니다.
- WatchConnectivity 처리가 `ParsedWatchMessage/ParsedWatchContext`로 Sendable 필드만 추출하도록 정리되어 actor 경계를 의식한 구현이 돋보입니다.
- 입력값 범위 검증(예: rest seconds 15...600)이 존재해 비정상 데이터 유입을 일부 방어하고 있습니다.

## Next Steps

- [ ] P2(삭제 명령 가드, localization 누락, fatalError 대체) 우선 수정
- [ ] `/triage` 로 P3 항목(성능/구조 리팩토링) 우선순위 확정
- [ ] `/compound` 로 재발 방지 규칙(문자열/삭제명령/앱기동 fallback) 문서화
