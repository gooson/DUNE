---
tags: [theme, architecture, refactor, automation, design-system, testing]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 새로운 테마 추가를 위한 테마 코드 구조 리팩토링

## Problem Statement

현재 테마 구조는 iOS/Watch 각각에 `switch self` 기반 매핑이 분산되어 있어, 새 테마 추가 시 누락 위험이 높고 반영 속도가 느려진다.
목표는 다음 3가지를 동시에 만족하는 구조다.

- 개발 속도: 새 테마 추가를 빠르게 진행
- 안정성: 테마 누락/불일치가 빌드 단계에서 즉시 검출
- 무하드코딩: View/Extension 레이어의 분산된 수동 매핑 제거

## Target Users

- 1차 사용자: 개발자
- 주요 니즈: 테마 추가/수정 시 수정 포인트를 최소화하고, 누락을 자동으로 차단하는 구조

## Success Criteria

- 새 테마 추가 시 단일 입력 소스(테마 정의 파일)만 추가/수정하면 iOS/Watch 모두 자동 반영된다.
- 테마 토큰 누락, 잘못된 asset 참조, 플랫폼 간 불일치가 빌드/CI에서 실패 처리된다.
- `AppTheme+View.swift`, `AppTheme+WatchView.swift`의 반복 `switch` 매핑이 제거되거나 생성 코드로 대체된다.
- 색상뿐 아니라 gradient/typography/animation까지 동일한 규칙으로 구조화된다.
- 스냅샷 테스트가 테마별로 자동 생성/실행되어 회귀를 빠르게 검출한다.

## Proposed Approach

### 1. 단일 소스 기반 테마 정의

- `Shared/Resources/Themes/` 아래에 테마 manifest를 둔다. (예: `desert-warm.json`, `ocean-cool.json`)
- manifest에는 아래를 모두 포함한다.
- 필수 색상 토큰 매핑 (accent, score, metric, tab, weather, surface 등)
- gradient 정의 (토큰 조합 + 방향)
- typography/animation 값(또는 DS preset key)
- picker 메타데이터(displayName, swatch)

### 2. 코드 생성(Codegen) 기반 자동 반영

- build 전 스크립트가 manifest를 읽어 생성 파일을 만든다.
- `AppTheme` case 목록
- `ThemePalette` / `ThemeRegistry` / `ThemeToken` 접근 코드
- ThemePicker용 swatch/display 데이터
- iOS/Watch 공용 타깃에서 동일 생성 파일을 참조해 동시 반영을 강제한다.

### 3. 접근 패턴 표준화

- View는 `@Environment(\\.appTheme)` + `theme.palette.token(.accent)` 같은 통일 API만 사용한다.
- 직접 `Color("...")` 호출과 분산 `switch`는 금지한다.
- 새 토큰이 생기면 manifest schema와 생성 코드에서 강제되도록 만든다.

### 4. 누락 방지 검증 레이어

- Validator를 codegen 단계에 포함한다.
- 모든 theme가 필수 토큰 집합을 충족하는지 검사
- 참조 asset 존재 여부 검사
- iOS/Watch 양쪽에서 접근 가능한 리소스인지 검사
- 실패 시 빌드 실패 처리

### 5. 스냅샷 테스트 자동 생성

- 테마 x 화면 조합을 기반으로 스냅샷 케이스를 생성한다.
- 최소 커버리지: 핵심 화면(탭 루트, 대표 카드/차트, 설정 ThemePicker) x 모든 테마 x 라이트/다크
- baseline 갱신은 명시적 커맨드로만 허용해 의도치 않은 변화 반영을 막는다.

## Constraints

- 명시된 제약 조건: 없음
- 운영상 권장 제약:
- 기존 사용자 저장값(`AppTheme.rawValue`)과의 하위호환 유지
- 빌드 시간 증가를 최소화하는 코드 생성 방식 유지

## Edge Cases

- 특정 테마에 일부 토큰이 누락된 상태로 머지되는 경우
- 토큰은 존재하나 asset 이름 오타/삭제로 런타임 색상 로드 실패가 발생하는 경우
- iOS에는 반영됐지만 Watch에는 누락되는 비대칭 반영
- 구버전에서 저장된 rawValue가 더 이상 존재하지 않는 경우
- 새 토큰 추가 후 기존 테마 manifest 갱신 누락

## Scope

### MVP (Must-have)

- 모든 테마 관련 코드의 규칙화 (color/gradient/typography/animation 포함)
- 테마 단일 소스(manifest) 도입
- 코드 생성 기반 iOS/Watch 동시 반영
- 필수 토큰 누락/asset 누락 자동 검증
- 기존 수동 `switch` 매핑 제거 또는 generated code로 치환
- 스냅샷 테스트 자동 생성 파이프라인 구축

### Nice-to-have (Future)

- 디자이너 친화적 테마 편집 입력 포맷/도구
- 토큰 변경 diff 리포트 자동 생성
- 테마 추가 템플릿 CLI (`make theme <name>`) 제공

## Open Questions

- manifest 포맷은 JSON/YAML 중 무엇으로 고정할지
- codegen 실행 시점: Xcode Build Phase vs 별도 사전 커맨드
- 스냅샷 baseline 저장/갱신 정책 (PR에서 자동 생성 허용 여부)
- rawValue 하위호환 전략: theme rename/deprecate 시 매핑 정책

## Next Steps

- [ ] `/plan theme-architecture-refactor`로 구현 계획 생성
- [ ] 필수 토큰 스키마(초안) 확정
- [ ] codegen + validator 최소 프로토타입 작성
- [ ] 스냅샷 자동 생성 범위(화면 목록) 확정
