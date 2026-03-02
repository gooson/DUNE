---
topic: title-and-watch-localization-audit
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
  - docs/solutions/general/2026-03-02-training-readiness-localization-leak-fix.md
related_brainstorms: []
---

# Implementation Plan: Title/Watch Localization Audit

## Context

사용자 제보 스크린샷에서 하단 탭/네비게이션 타이틀 영어 고정 정책과 별개로, iOS/Watch 콘텐츠 라벨에 localization 누락이 반복 노출됨.

## Requirements

### Functional

- iOS 탭 이름/네비게이션 타이틀은 영어 고정 정책으로 일관화
- Watch 홈/빠른 시작/운동 프리뷰의 사용자 노출 라벨을 locale 기반으로 표시
- 상대 날짜 라벨(`Today`, `Yesterday`, `N days ago`)이 locale 번역을 사용
- 누락된 string catalog 키(`Active Indicators`, `Physical`, `Routine`, `Browse`, `Browse All`, `Search`, sync 안내 문구) 추가

### Non-functional

- 기존 동작(정렬, 분류, 네비게이션 흐름)은 유지
- 문자열 포맷은 locale-safe(`String(format:..., locale: .current, ...)`)로 처리

## Approach

- iOS: `englishNavigationTitle(_:)` 공통 API + `AppSection.title` 고정값으로 정책 코드화
- Watch: 하드코딩 문자열을 `String(localized:)`로 치환, 날짜 문자열은 포맷 키를 통한 로컬라이즈 처리
- `Localizable.xcstrings`에 누락 키를 보강

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 화면별 개별 패치 | 빠른 임시 조치 | 재발/누락 가능성 높음 | 기각 |
| 공통 정책 API + key 보강 | 재발 방지, 일관성 확보 | 수정 파일 수 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/AppSection.swift` | update | tab title 영어 고정 |
| `DUNE/App/ContentView.swift` | update | tab label verbatim 렌더링 |
| `DUNE/Presentation/Shared/Extensions/View+NavigationTitlePolicy.swift` | add | 영어 고정 네비 타이틀 공통 API |
| `DUNE/Presentation/**` 다수 | update | `.navigationTitle` -> `.englishNavigationTitle` 통일 |
| `DUNE/Presentation/Shared/Extensions/Date+Validation.swift` | update | 상대 날짜 라벨 localize/format 정리 |
| `DUNEWatch/Views/CarouselHomeView.swift` | update | popular/recent/routine/browse/daysAgo localize |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | update | category/header/search localize |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | update | indoor/outdoor/start/error/count localize |
| `DUNE/Resources/Localizable.xcstrings` | update | 누락 키/번역 보강 |
| `CLAUDE.md` | update | 영어 고정 UI 규칙 추가 |

## Implementation Steps

### Step 1: 정책 고정

- **Files**: `AppSection.swift`, `ContentView.swift`, `View+NavigationTitlePolicy.swift`, `CLAUDE.md`
- **Changes**: 탭/네비 타이틀 영어 고정 규칙 코드+문서화
- **Verification**: `rg`로 direct `.navigationTitle(` 제거 확인

### Step 2: 누락 로컬라이즈 수집/수정

- **Files**: `Date+Validation.swift`, `WellnessView.swift`, `Localizable.xcstrings`, Watch 3개 뷰
- **Changes**: 하드코딩 문자열을 localization 경로로 치환 및 키 추가
- **Verification**: 사용자 제보 문자열(`days/min/today/popular/outdoor/indoor/strength`) 경로 점검

### Step 3: 품질 확인 및 릴리스 준비

- **Files**: 전체 변경 파일
- **Changes**: 리뷰 이슈 정리, 문서화, 커밋/PR
- **Verification**: 빌드 시도, grep 기반 정책 검증, diff self-review

## Edge Cases

| Case | Handling |
|------|----------|
| `String(localized:)` interpolation 키 매칭 실패 | 포맷 키(`%@ days ago`) + `String(format:locale:)` 사용 |
| watch/iOS 타겟별 문자열 누락 | xcstrings 키를 공통 catalog에 수동 추가 |
| locale별 대문자 처리 | `Browse`는 번역 후 `.uppercased()` 적용(표시 스타일 목적) |

## Testing Strategy

- Unit tests: 없음(문자열/표시 정책 변경)
- Integration tests: `xcodebuild` build 시도
- Manual verification: 사용자 제보 화면 문자열 체크리스트 기반 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| watch 빌드 환경 이슈로 자동 검증 불가 | high | medium | 로그 첨부 + 수동 QA 체크포인트 명시 |
| xcstrings 수동 편집 오타 | medium | high | `jq empty`로 JSON 유효성 검사 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 제보 문자열 경로를 직접 수정했고, grep/json 검증으로 정책/키 누락을 재확인함.
