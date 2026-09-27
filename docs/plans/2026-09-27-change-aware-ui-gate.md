---
tags: [testing, ui-test, run, selective-testing]
date: 2026-09-27
category: plan
status: approved
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
---

# Implementation Plan: 변경 범위 기반 UI 테스트 게이트

## Context

PR CI는 smoke, nightly는 full 회귀로 분리돼 있으나 Codex `/run`은 항상 full UI를 요구한다.
변경 위험에 따라 검증을 선택하고 근거를 남겨 반복 비용을 줄인다. `.claude/**`는 수정하지 않는다.

## Requirements

- 문서만 변경하면 UI 생략, 기능 변경은 관련 suite와 smoke의 합집합, 공유/불명확 변경은 full.
- diff는 merge-base부터 현재 tracked 작업 상태 및 untracked 파일까지 포함한다. 삭제/rename 원본도 놓치지 않는다.
- View 파일명만으로 분류하지 않으며 Domain/Data/Shared 변경은 보수적으로 full 처리한다.
- UI 실행기 기본 full 및 CI/nightly 동작은 유지한다. 명시적 선택과 smoke를 함께 주면 둘 다 실행한다.
- 0개/미확인 실행은 UI 게이트 성공으로 인정하지 않는다.
- 사용자 요청에 따른 Codex 정책 예외를 어댑터에 명시하고 Claude 원본 정책과 구분한다.

## Approach

`scripts/plan-ui-tests.py`가 변경 경로, 이유, 플랫폼별 범위와 argv 명령을 JSON으로 출력한다.
자동으로 테스트를 실행하거나 성공을 선언하지 않는다. 호출자는 결과를 검토해 범위를 상향하고 실행 증거를 기록한다.
초기 매핑은 기존 feature 디렉터리와 suite를 재사용한다. 런타임 의존성을 자동 증명할 수 없으므로
공유 소비자 확인을 요구하고, 불확실하면 full로 상향한다. 순수 로직의 UI 면제는 의존성/단위 테스트 증거를 갖춘 명시적 판단에만 허용한다.

### Alternative Approaches Considered

| 접근 | 장점 | 단점 | 선택 |
|------|------|------|------|
| 항상 full | 단순 | 작은 변경에도 비용 큼 | 고위험/nightly에 유지 |
| 항상 smoke | 빠름 | 변경 기능 누락 | 사용하지 않음 |
| 보수적 범위 선택 | 관련 기능 + 공통 경로 검증 | 매핑 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/test-ui.sh | 수정 | smoke + 명시 선택 병합 및 실행 증거 검증 |
| scripts/lib/* | 필요 시 추가 | 선택 목록/실행 증거 검사 |
| scripts/plan-ui-tests.py | 추가 | 변경 범위와 실행 명령 출력 |
| scripts/tests/* | 추가 | argv, 분류, Git rename/dirty/untracked, 0개 실행 회귀 |
| DUNEUITests/Smoke/ActivitySmokeTests.swift | 수정 | 실데이터 로딩에 의존하던 콘텐츠 smoke를 기존 seed fixture로 고정 |
| DUNEUITests/Smoke/LifeSmokeTests.swift | 수정 | 현재 추가 메뉴를 거쳐 폼에 진입하도록 경로 정정 |
| AGENTS.md | 수정 | 사용자 승인된 Codex UI 게이트 예외 안내 |
| .codex/skill-compat.md | 수정 | `/run` Phase 2.5 범위/증빙 정책 |
| .codex/token-efficiency.md | 수정 | 선택 범위와 결과 재사용 계약 일치 |
| docs/solutions/testing/* | 추가 | 최종 계약과 검증 결과 |

## Implementation Steps

1. 실행기의 smoke와 명시적 선택 합집합을 구현하고 shell argv fixture 테스트로 검증한다.
2. 보수적 변경 분류기를 추가하고 feature/shared/unknown/삭제/rename/mixed 변경을 테스트한다.
3. Codex 어댑터 정책을 갱신하고 parity 검사와 정책 충돌 검색을 수행한다.
4. 실제 iOS 빌드/UI 게이트, 6관점 리뷰, 해결, 문서화, PR/머지를 진행한다.

## Edge Cases

| Case | Handling |
|------|----------|
| base ref 없음 / Git 실패 | 오류로 종료, skip 선언 금지 |
| 신규/삭제/rename 파일 | untracked 포함, rename은 양쪽 경로 포함 |
| 미등록 feature 또는 test helper | full fallback |
| Shared/watch 혼합 변경 | 필요한 플랫폼 full, 지원 외 타깃은 별도 검증 의무 표시 |
| smoke plan이 명시적 suite 제외 | 명시적 선택과 smoke 병합 시 Full plan 사용 |
| 테스트 이름 오타 / 0개 실행 | 실패 처리, 요구 suite 증거 대조 |
| 문서 파일이 앱 리소스에 포함 | 앱 경로의 문서를 일반 docs 면제에 포함하지 않음 |

## Testing Strategy

- Python unittest 및 shell mock 실행: 실제 runner argv를 확인하되 simulator 부팅은 하지 않는다.
- 판정기 fixture와 임시 Git 저장소로 미커밋/신규/rename 회귀를 검증한다.
- `bash -n`, parity 검사, `git diff --check`.
- 실제 `scripts/build-ios.sh`, 실행기의 변경된 `--smoke + --only-testing` 조합 실행. 앱/프로젝트/UI test body/seed/helper 변경이 없는 CLI 선택 변경이므로 도구 fixture와 실제 조합 검증을 필수 게이트로 한다.
- 처음 시도한 full iOS 실행은 환경 복구 후 첫 회귀 케이스가 96초에 통과했으나 전체 완료 전에 범위를 조정했다. 중단한 full은 통과로 보고하지 않는다.
- 실제 smoke 실패 첨부에서 Activity의 ActivityIndicator-only 화면과 Life의 추가 메뉴를 확인했다. 앱 코드를 변경하지 않고 Activity seed 및 Life 테스트 탐색 경로를 수정하며, 변경된 두 클래스 전체와 공통 smoke를 재실행한다. 기대값/timeout 완화나 실패 테스트 제외는 하지 않는다.
- 이후 Phase에서 같은 증거 재사용은 파일/환경 일치 조건을 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 디렉터리와 의존 범위 불일치 | 중 | 회귀 누락 | 수동 소비자 확인 + 불명확 full |
| smoke skip이 명시 선택을 가림 | 중 | 테스트 누락 | 명시 선택 우선, fixture 검증 |
| 시뮬레이터/기존 테스트 실패 | 중 | 게이트 차단 | 환경/제품 실패 분리, 실패 증거 보존 |

## Confidence Assessment

Medium. 기존 실행기와 CI를 재사용하며 정책은 보수적으로 시작한다. 성능 개선률은 측정 전 주장하지 않는다.

## References

- Apple: https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback
- Apple: https://developer.apple.com/library/archive/technotes/tn2339/_index.html
