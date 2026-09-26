---
tags: [rpe, progression, workout, watch, persistence]
date: 2026-09-27
category: plan
status: approved
confidence: high
related_solutions:
  - architecture/2026-09-19-watch-summary-persistence-parity.md
  - architecture/2026-03-12-set-rpe-integration.md
related_brainstorms:
  - 2026-03-07-workout-procedure-levelup-progression.md
---

# Implementation Plan: RPE와 목표 기반 운동 추천 통합

## Context

실제 reps를 목표 reps로 다시 비교하는 증량 판정, 세트 RPE와 분리된 무게 추천, 최종 effort 이전에 계산되는 자동 강도를 순서대로 수정한다. `/run` 요청으로 구현·검증·리뷰·문서화·ship까지 승인되었다.

## Requirements

- 계획 반복 횟수와 실제 수행 횟수를 별도로 저장하고 draft/Watch 전송에서 보존한다.
- 작업 세트의 목표 달성 및 사용자 확인 RPE를 공통 정책으로 평가한다. RPE/목표가 없는 legacy 기록은 증량하지 않는다.
- 다음 세트는 기본 유지, 높은 RPE/목표 미달이면 감량 후보를 제공한다. 다음 운동의 증량은 전체 작업 세트 완료 및 목표 달성, RPE 여유가 있을 때만 허용한다.
- 사용자가 입력한 무게를 추천이 몰래 덮어쓰지 않도록 iPhone에서 명시적 적용을 제공한다.
- 세트 RPE 출처(user/estimated), 세션 effort 출처(user/setAverage)를 보존한다. 사용자가 선택한 세션 effort가 최종 우선이다.
- 자동 강도는 세트 기반 effort 적용 후 계산하고 최종 사용자 effort 변경 시 갱신한다. 현재 기록을 과거 이력에서 제외한다.
- iPhone/Watch에서 같은 순수 Domain 정책을 사용한다. Watch 추정 RPE만으로 증량하지 않는다.

## Approach

현재 automatic lightweight migration 구조를 유지하며 optional metadata를 추가한다. 척도나 기존 필드명을 파괴적으로 변경하지 않는다. raw source가 없는 과거 값은 unknown으로 해석한다. 공통 순수 서비스는 장비 증가폭, 10% 상한, 유효 범위, 세트 종류 및 RPE 판정을 담당한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 실제 reps를 목표로 재사용 | 변경 적음 | 목표 미달을 판정할 수 없음 | 제외 |
| optional 목표/출처 추가 | 기존 데이터 보존, 기기 간 일치 | DTO와 저장소 검증 필요 | 채택 |
| 새 staged migration 체계 도입 | 버전별 전환 명시 | 기존 unknown checksum 문제 재도입 위험 | 제외 |
| 추정 RPE로 자동 증량 | 입력 부담 적음 | 추정 오차가 처방에 누적 | 제외 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| Domain/UseCases/WorkoutProgressionService.swift | Add | 공통 증량/유지/감량 판단 |
| Data/Persistence/Models/{WorkoutSet,ExerciseRecord}.swift | Modify | 목표, 출처, 계획 세트 수 |
| Data/Persistence/Migration/AppSchemaVersions.swift | Modify | additive schema 버전 |
| Domain/Models/WatchConnectivityModels.swift | Modify | optional 전송 metadata |
| Presentation/Exercise/WorkoutSessionViewModel.swift | Modify | 목표 스냅샷·draft·추천 |
| Presentation/Activity/ActivityView.swift | Modify | 단일 운동 템플릿의 목표·무게·세트 수 전달 |
| Presentation/Exercise/{WorkoutSession,TemplateWorkout,CompoundWorkout}View.swift | Modify | 최종 effort 저장·추천 표시 |
| Presentation/Shared/Extensions/ExerciseRecord+SetRPE.swift | Modify | 명시적 effort 보존 |
| DUNEWatch/Managers 및 Helpers, Views/MetricsView.swift | Modify | 목표·RPE 출처 저장 및 공통 정책 |
| Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift, App/DUNEApp.swift | Modify | 송수신 필드 보존 |
| DUNE/project.yml | Modify | Watch 공유 서비스 등록 |
| DUNETests, DUNEWatchTests, DUNEUITests | Modify/Add | 회귀·저장·UI 검증 |
| Shared/Resources/Localizable.xcstrings | Modify | 신규 사용자 문구 번역 |

## Implementation Steps

### Step 1: 목표/출처 및 공통 정책
- optional 목표/출처 필드와 DTO를 추가한다. 세트 RPE의 user/estimated 출처는 기존 기록에 소급 추정하지 않는다.
- 순수 Domain 서비스에 동일 세션 유지/감량 및 다음 세션 증량 조건을 구현한다.
- Verification: 경계값, 누락값, 미달, RPE 10, warmup/drop/failure, 10% 반올림 상한 단위 테스트.

### Step 2: iPhone/Watch 연결
- 생성/템플릿/이전 기록에서 목표를 정하고 실제 reps 변경 시 목표가 변하지 않게 한다.
- draft, 완료 기록, Watch recovery·전송·절차 이력까지 metadata를 전달한다.
- 부분 완료 기록도 원래 계획 세트 수를 유지하고, Activity 단일 템플릿 시작 경로에서 template entry를 보존한다.
- Verification: VM/DTO/Watch roundtrip 및 기존 legacy decode, 저장소 재오픈 테스트.

### Step 3: 강도 저장 순서와 사용자 표시
- 세트 평균과 직접 선택한 세션 effort를 구분하고 사용자 값이 우선되도록 한다.
- 자동 강도 계산은 최종 effort와 동일 history를 사용한다. 새 기록 제외를 ID로 고정한다.
- 추천 이유/적용 및 목표 표시를 기존 화면에 통합하고 번역·접근성 ID를 추가한다.
- Watch 다음 세트 감량도 공통 정책으로 판단해 입력 시트에서 명시적으로 적용한다. RPE 시트의 임시 조절은 확정 전까지 저장하지 않는다.
- Verification: effort 재계산/사용자 override 테스트, UI 시나리오.

### Step 4: 전체 검증·리뷰·문서화·배포
- scripts/build-ios.sh, scripts/test-unit.sh, scripts/test-ui.sh 전체 회귀 실행.
- 리뷰 및 품질 에이전트 결과 수정 후 재검증한다. 해결책 문서, PR, merge 및 정리까지 진행한다.

## Edge Cases

| Case | Handling |
|---|---|
| legacy 목표/출처 없음 | 기존 값 유지, 증량 자격 없음 |
| RPE 미입력/추정값만 있음 | 증량하지 않음 |
| 목표 미달·높은 RPE | 증량 차단, 다음 세트 감량 후보 |
| 부분 완료 | 다음 운동 증량 차단 |
| warmup/drop/failure | 일반 작업 세트와 별도 취급 |
| kg/lb, 가벼운 중량 | kg에서 계산, 반올림 이후에도 10% 상한 보장 |
| draft 복원 | 목표/RPE/출처 보존, legacy draft 안전 fallback |
| 직접 입력한 세션 effort | 자동 평균으로 덮어쓰지 않음 |

## Testing Strategy

- Unit: 공통 정책, VM 목표 고정, draft roundtrip, effort 우선순위/재계산, Watch local/sync 일치.
- Persistence: optional 필드/관계 검증, legacy schema → current reopen 및 새 필드 저장 후 두 번째 reopen.
- UI: seeded 운동 시작 → 실제 reps 변경 → 목표 유지 → 높은 RPE → 무단 증량 없음, 추천 적용.
- Full gates: iOS build, iOS/watch unit suite, 기존 DUNEUITests 전체. 환경 차단 시 실제 오류/로그와 미통과 게이트를 명시한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| SwiftData 기존 데이터 손실 | Low | High | additive optional, migration/reopen 검증, 삭제 복구 금지 |
| 구버전 Watch DTO 누락 | Medium | Medium | optional decode, unknown 보수 처리 |
| 과도한 추천/체감 강도 오해 | Medium | Medium | 명시 적용, 출처 분리, 보수적 유지 |
| 시뮬레이터/UI 환경 실패 | Medium | Medium | 표준 스크립트·로그 기반 복구, 실패 게이트를 통과로 처리하지 않음 |

## Research / Confidence

- 기존 RPE 통합, Watch summary parity, progression brainstorm과 현재 코드 흐름을 확인했다.
- Apple 공식 자료: https://developer.apple.com/documentation/swiftdata/schema 및 https://developer.apple.com/videos/play/wwdc2023/10195/ . 새 API 없이 기존 SwiftData schema/optional 속성 패턴을 재사용한다.
- 전용 Serena/Context7 대신 rg/파일 읽기 및 공식 문서 검색을 사용했다.
- Overall: High. 운동 처방의 임상 최적화를 주장하지 않고, 데이터 정합성과 보수적인 제품 정책을 검증한다.
