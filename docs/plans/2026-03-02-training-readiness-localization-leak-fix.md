---
topic: training-readiness-localization-leak-fix
date: 2026-03-02
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
  - docs/solutions/general/2026-03-01-localization-completion-audit.md
related_brainstorms:
  - docs/brainstorms/2026-03-01-full-localization-xcstrings.md
---

# Implementation Plan: Training Readiness Localization Leak Fix

## Context

`TrainingReadinessDetailView`에서 일부 항목이 한국어 로케일에서도 영어로 노출되고, 하단 탭(`Today/Activity/Wellness/Life`)도 영어로 고정 노출됩니다. 원인은 (1) `Localizable.xcstrings` 키 누락과 (2) `Text(verbatim:)`/`Text(String)` 경유로 localization lookup이 우회되는 leak pattern입니다.

## Requirements

### Functional

- Training Readiness 상세 화면에서 영문 고정 문구가 ko/ja 로케일에서 번역되어 표시되어야 한다.
- 하단 탭 타이틀이 ko/ja 로케일에서 번역되어야 한다.
- 기존 UI 구조/계산 로직/데이터 흐름은 변경하지 않는다.

### Non-functional

- 기존 localization 규칙(`.claude/rules/localization.md`)을 준수한다.
- `String` 파라미터 기반 leak pattern 재발을 방지하는 방향으로 최소 수정한다.
- 변경 후 빌드 및 관련 테스트가 통과해야 한다.

## Approach

문구 소스별로 두 가지 대응을 병행한다.

1. **카탈로그 누락 보완**: `DUNE/Resources/Localizable.xcstrings`에 누락된 키(가중치 섹션/계산 방법/약어)를 ko/ja 번역과 함께 추가.
2. **Leak 경로 차단**:
   - `ContentView`에서 `Text(verbatim:)` 제거.
   - `TrainingReadinessDetailView`의 계산 방법 라인을 `LocalizedStringKey` 기반으로 렌더링.
   - `DetailScoreHero`가 `String` 파라미터를 요구하는 항목은 `String(localized:)` 상수로 전달.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| xcstrings만 추가 | 변경 범위 최소 | `Text(verbatim:)`, `Text(String)` 경로는 계속 번역 우회 | Rejected |
| UI 전체를 `LocalizedStringKey`로 전환 | 일관성 높음 | `DetailScoreHero` 등 공용 컴포넌트 시그니처 확장 필요 | Rejected |
| 누락 키 + leak 지점만 최소 수정 | 문제 원인 직접 해결, 회귀 리스크 낮음 | 일부 String 기반 컴포넌트는 `String(localized:)` 유지 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | Modify | 누락/우회 문자열 로컬라이즈 경로 정리 |
| `DUNE/App/AppSection.swift` | Modify | 탭 제목을 로컬라이즈 가능한 타입으로 변경 |
| `DUNE/App/ContentView.swift` | Modify | 탭 라벨 `Text(verbatim:)` 제거 |
| `DUNE/Resources/Localizable.xcstrings` | Modify | 누락 키 ko/ja 번역 추가 |

## Implementation Steps

### Step 1: Training Readiness 문자열 경로 수정

- **Files**: `TrainingReadinessDetailView.swift`
- **Changes**:
  - `DetailScoreHero` 전달 문자열을 `String(localized:)` 상수화
  - `calculationMethodLine` 파라미터를 `LocalizedStringKey`로 변경
  - 가중치 섹션 라벨의 누락 키 사용부 유지(카탈로그 추가 전제)
- **Verification**:
  - 컴파일 에러 없음
  - 기존 레이아웃/정보 구조 동일

### Step 2: 탭 타이틀 localization leak 제거

- **Files**: `AppSection.swift`, `ContentView.swift`
- **Changes**:
  - `AppSection.title`을 `LocalizedStringKey`로 변경
  - `ContentView`의 탭 라벨에서 `Text(verbatim:)` 제거
- **Verification**:
  - 탭 선택/재선택(스크롤 탑 이동) 동작 유지
  - ko/ja 로케일에서 탭 타이틀 번역 노출

### Step 3: String Catalog 누락 키 추가

- **Files**: `DUNE/Resources/Localizable.xcstrings`
- **Changes**:
  - `HRV Variability`, `Recovery Status`, `Trend Bonus`, `RHR`
  - 계산 방법 4개 설명 문구
- **Verification**:
  - 키 조회 시 ko/ja 모두 존재
  - Xcode string catalog 파싱 에러 없음

### Step 4: Quality Check

- **Files**: 전체 변경 파일
- **Changes**:
  - 빌드/테스트 실행
  - 변경 diff 기반 6관점 리뷰 + UI 품질 관점 점검
- **Verification**:
  - P1/P2 이슈 0건
  - 결과 문서화 가능 상태

## Edge Cases

| Case | Handling |
|------|----------|
| `DetailScoreHero`의 String-only 인터페이스 | `String(localized:)` 상수 전달로 localization 유지 |
| 계산식 문구가 동적 문자열로 바뀌는 경우 | `String(localized:)` + interpolation 패턴으로 전환 |
| watchOS 카탈로그 동기화 필요 여부 | 이번 변경은 iOS 화면 기준이므로 iOS 카탈로그만 수정, watch 노출 시 별도 반영 |

## Testing Strategy

- Unit tests: 변경 영향이 UI 문자열 경로 중심이라 신규 단위 테스트는 생략, 기존 테스트 회귀 확인
- Integration tests: `xcodebuild` 빌드/테스트로 컴파일 + 주요 시나리오 회귀 확인
- Manual verification:
  - Activity 탭 > Training Readiness 상세 진입
  - 가중치 섹션/계산 방법 문구 ko 로케일 노출 확인
  - 하단 탭 타이틀 ko/ja 로케일 노출 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| xcstrings 수동 수정 중 JSON 구조 손상 | Medium | High | 최소 범위 패치 + 변경 후 빌드 검증 |
| `LocalizedStringKey` 타입 변경으로 호출부 타입 불일치 | Low | Medium | 컴파일러 에러 기반 즉시 보정 |
| 기존 영어 유지 정책과 충돌 | Low | Medium | localization 규칙의 면제 항목 재검토 후 범위 제한 적용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 solution 문서에 동일 leak pattern 해결 레퍼런스가 있으며, 변경 범위가 UI 문자열/카탈로그로 한정되어 회귀 위험이 낮다.
