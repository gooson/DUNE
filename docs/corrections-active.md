---
tags: [corrections, active, project-specific]
date: 2026-03-07
category: general
status: approved
---

# Active Corrections (프로젝트 특화 교정 사항)

> 안정화된 패턴은 `.claude/rules/`로 졸업합니다.
> 전체 이력(#1~#184)은 `docs/corrections-archive.md`에 보존됩니다.
> 아래는 rules로 졸업하지 않은 **프로젝트 특화** 교정 사항입니다.

<!-- Rules 졸업 현황:
  - swiftui-patterns.md: #28-31, #47-49, #52, #65-66, #70-71, #74, #93, #106, #143-146, #150, #179-183
  - performance-patterns.md: #8, #16-17, #35, #80, #83, #102, #105, #111, #118, #132, #152-153, #165, #169, #184
  - swift-layer-boundaries.md: #1, #2, #7, #20, #36, #62, #73, #86, #103, #117, #155
  - input-validation.md: #3, #4, #6, #11, #18, #21, #22, #38-39, #41-42, #84-85, #101
  - healthkit-patterns.md: #5, #107-110, #130-131
  - swiftdata-cloudkit.md: #32-33, #40, #50, #65, #71, #164, #188
  - watch-navigation.md: #57-61
  - build-pipeline.md: #95-96, #185
  - watch-ios-parity.md: #46, #69, #72, #138, #147, #154, #170-171, #189-195, #197-200
  - design-system-rules.md: #119-120, #127-129, #136-137, #139-140, #163, #176-178
  - asset-catalog.md: #121, #123-126, #159-162, #166, #201, #203
  - localization.md: #36 (Leak Pattern 4)
-->

### Data & Score 로직

- **historical fallback 시 change=nil**: 비인접일 비교는 의미 없음 (#24, #51)
- **partial failure 보고 필수**: async let 4+개 시 "N of M sources" 형태 (#25, #92)
- **Hashable: == 와 hash 프로퍼티 일치**: content-aware Hasher 사용 (#26, #87, #175)
- **RHR fallback을 condition "today"로 전달 금지**: nil이면 보정 스킵 (#112)
- **Score 추가 시 `{Type}ScoreDetail` + `{Type}CalculationCard` 세트**: 중간 계산값 디버깅 (#113, #116)
- **통계 파라미터 변경 시 3+개 실데이터 시나리오 검증** (#114)
- **Fetch window >= 필터 threshold x 2**: dateComponents 시간 truncation 보상 (#115)
- **Sleep stage 분류: Display와 Score 일관성 필수** (#110)
- **시계열 regression 입력은 oldest-first 정렬** (#156)
- **Dedup 필터 빈 문자열 ID 방어**: `!id.isEmpty` 검증 (#63)
- **HK ID 캡처 -> SwiftData 삭제 -> HK 삭제 순서** (#67)

### DRY & 구조

- **동일 로직 3곳+ 즉시 추출** / 복잡하면 2곳부터 / 같은 파일이면 file-scope (#37, #64, #167, #173)
- **공유 DTO -> `Presentation/Shared/Models/`** / VM 내부 struct 2곳+ 사용 시 추출 (#86, #155)
- **3개+ 파일 참조 enum은 전용 파일 분리** (#149)
- **Popover/inline 중복은 `isInline: Bool` 파라미터로 통합** (#151)
- **모드별 dispatch 함수보다 튜플 반환 단일 함수** (#148)
- **`Dictionary(uniqueKeysWithValues:)` 사용 금지 -> `uniquingKeysWith`** (#104)

### Launch & Permissions

- **launch permission 완료 플래그는 요청 전에 영구 저장 금지**: cross-launch persisted state와 same-launch attempt state를 분리하고, system request가 정상 반환된 뒤에만 completion 저장 (#201)
- **secondary CloudKit consumer도 `isCloudSyncEnabled` 우회 금지**: watch/vision/mac mirror reader가 별도 `ModelContainer`를 만들더라도 iOS sync opt-in 계약을 그대로 재사용 (#205)

### UI 표시 규칙

- **탭 이름/네비게이션 타이틀은 영어 고정**: `AppSection.title` + `englishNavigationTitle(_:)` 사용 (#190)
- **Watch 사용자 라벨 하드코딩 금지**: 캐러셀/퀵스타트/운동시작 라벨은 `String(localized:)` 경유 (#191)
- **Watch confirmationDialog `.destructive` 테마 tint 대비 실기기 검증** (#192)
- **화면 숫자 표기는 `formattedWithSeparator` 경유** (#97)
- **`changeFractionDigits` 단일 소스: `HealthMetric+View`** (#98)
- **`HealthMetric.Category` 추가 시 10+ 파일 수정 체크리스트** (#94)
- **UI 컴포넌트 삭제 시 기능 이관 체크리스트** (#99)
- **`TodayPinnedMetricsStore` 빈 배열 fallback 주의** (#100)
- **`Sendable` struct 내 튜플 사용 금지** (#90)

### 프로세스

- **workflow paths에 `scripts/**` 대신 개별 스크립트 경로 지정** (#186)
- **새 UI 테스트 파일은 `BaseUITestCase` 상속** (#187)
- **`/ship` 머지 전략은 `--merge` 기본** (#54)
- **`/run`에서 `/ship` 호출 전 Pre-Ship 게이트 강제** (#196)
- **`.claude/settings.local.json`은 기본적으로 `{}` 유지** (#203)
- **`/run` 최종 출력 계약은 상태 기반으로 작성** (#204)
- **리뷰 적용은 파일별 batch, dead code는 같은 커밋에서 삭제** (#27, #55, #133)
- **리뷰 에이전트 output 크기 제어: max_turns 6, diff 2000줄+은 직접 리뷰** (#91)
- **에이전트 리서치 3개 이하, 80% 품질 + 빠른 전달** (#13-15)
- **버그 수정 -> 빌드 -> 사용자 확인 -> 다음 단계** (#134, #135)
- **효과 확인된 수정은 즉시 커밋** (#180)
- **새 기능 구현 후 관련 Correction 항목 재검증** (#81)
- **UI 구조 변경 시 UI 테스트 동시 갱신** (#158)
- **문자열 키워드 매칭 false-positive 테스트 필수** (#89, #157)
- **Launch Splash 최소 노출: CancellationError 명시 처리** (#141-142)
- **앱 시작 fetch는 값 반환과 persist/sync side effect를 분리** (#202)
- **`throws` 함수에서 silent `guard...return` 금지** (#77)
- **새 필드 추가 시 전체 파이프라인 점검** (#34)
- **방어 코드도 비즈니스 로직 고려 + 테스트 검증** (#44)
- **`Swift.max()` 명시적 호출 (Collection.max 충돌)** (#45)
- **Deprecated API 즉시 교체 (Xcode warning 0)** (#19)
- **`isSaving` 리셋은 View에서 insert 완료 후** (#43)
- **Cross-VM static 프로퍼티 참조 금지 -> 중립 enum** (#73)
- **UserDefaults: bundle prefix + garbage collection** (#75-76)
- **`personalizedPopular(limit:)`에 실제 필요 수량 전달** (#174)
