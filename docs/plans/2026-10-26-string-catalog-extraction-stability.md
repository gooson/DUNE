---
topic: string-catalog-extraction-stability
date: 2026-10-26
status: implemented
confidence: high
related_solutions:
  - ../solutions/general/xcstrings-extraction-state-warnings.md
  - ../solutions/general/2026-10-08-string-catalog-format.md
related_brainstorms: []
---

# Implementation Plan: 빌드 후 문자열 추출 상태 변경 방지

## Context

머지 후 Xcode 빌드마다 `extractionState: stale`이 추가/제거된다. Shared 카탈로그는 iOS·Widget·visionOS가 공유하며, Shared 1,078개와 Watch 69개 항목이 수동 관리 상태가 아니다. 포맷 정규화만으로는 타깃/구성별 추출 결과에 따른 의미 변경을 방지하지 못한다. 기존 해결책의 수동 카탈로그 관리 정책을 전체 기존 항목에 적용한다.

## Requirements

- 기존 키, 번역, 보간·복수형, 주석, 번역 제외 설정을 보존한다.
- 기존 항목은 추출 결과에 포함되거나 빠져도 상태가 바뀌지 않는다.
- 신규 문자열 자동 발견은 유지한다. 새 번역 등록 시 manual 상태를 사용한다.
- `.claude/**`는 수정하지 않는다.

## Approach

기존 카탈로그 항목의 `extractionState`만 `manual`로 통일한다. formatter는 값 보존 계약을 유지하고 회귀 테스트로 상태 불변식과 실제 Xcode sync 동작을 검증한다.

| Alternative | Decision |
|-------------|----------|
| 포맷만 정리 | 상태 변경 원인을 해결하지 못함 |
| 자동 추출 전체 비활성화 | 새 키 발견까지 사라지므로 제외 |
| 타깃마다 번역 사본 분리 | 번역 중복과 관리 비용 때문에 제외 |

## Affected Files

| File | Description |
|------|-------------|
| Shared/Resources/Localizable.xcstrings | 기존 항목 수동 관리 |
| DUNEWatch/Resources/Localizable.xcstrings | 기존 항목 수동 관리 |
| scripts/tests/test_format_xcstrings.py | 기존 카탈로그 상태 및 Xcode sync 회귀 검증 |
| docs/solutions/general/2026-10-26-string-catalog-extraction-stability.md | 원인·검증·관리 방법 기록 |

## Implementation Steps

1. Xcode `xcstringstool sync`로 자동 상태 항목의 재변경과 manual 상태의 안정성을 재현한다.
2. 회귀 테스트를 추가하고 두 카탈로그의 상태만 변경한 뒤 기존 formatter를 실행한다.
3. formatter 테스트, 카탈로그 compile, 표준 iOS 통합 빌드를 실행하고 빌드 전후 바이트 동일성을 확인한다.
4. diff 기반 다관점 리뷰 후 해결책을 기록하고 PR을 생성·머지한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 동적으로 조회되는 키, Debug 전용 키, 다른 타깃 키 | 추출 여부와 무관하게 manual 유지 |
| 복수형·번역 제외·주석 | extractionState 이외의 JSON 동일성 비교 |
| 새 자동 추출 키 | 자동 추출을 유지하고 번역 등록 시 manual로 관리 |
| 삭제된 코드의 번역 | 자동 정리 대신 명시적 미사용 키 검토 필요 |

## Testing Strategy

- Python 기존 formatter 테스트 + 실제 Xcode sync 회귀 테스트.
- 두 카탈로그 `xcstringstool compile`, 포맷 검사, 상태 외 JSON 동일성 검증.
- `scripts/build-ios.sh`로 iOS·embedded Watch·Widget 통합 빌드.
- UI/디자인맵: 문구·키·레이아웃·내비게이션·런타임 로직 변경 없음. 추출 메타데이터만 변경하므로 UI 및 재캡처는 skipped로 기록한다.

## Risks

수동 관리 항목은 코드 삭제 시 stale 경고가 자동 발생하지 않는다. 카탈로그 삭제는 사용처를 확인해 명시적으로 수행한다. 과거 번역은 이번 수정에서 삭제하지 않는다.

## Confidence Assessment

High: 기존 정책과 일치하며 Xcode 실제 sync 도구와 빌드 후 파일 동일성으로 검증한다.
