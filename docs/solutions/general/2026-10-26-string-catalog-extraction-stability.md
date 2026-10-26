---
tags: [localization, xcstrings, extractionState, stale, xcode, shared-resources]
category: general
date: 2026-10-26
status: implemented
severity: important
related_files:
  - Shared/Resources/Localizable.xcstrings
  - DUNEWatch/Resources/Localizable.xcstrings
  - scripts/tests/test_format_xcstrings.py
related_solutions:
  - xcstrings-extraction-state-warnings.md
  - 2026-10-08-string-catalog-format.md
---

# Solution: Xcode 빌드 후 카탈로그 추출 상태 변경 방지

## Problem

머지 후 Xcode에서 빌드하면 `Localizable.xcstrings`에 `extractionState: stale` 추가·제거가 반복됐다. 첨부 사례의 `CONDITION`, `Seated Cable Row`, `Show fewer exercises`, `Show more exercises`가 해당한다.

### Root Cause

JSON 포맷이 아닌 자동 추출 상태의 변경이다. Shared 카탈로그는 iOS·Widget·visionOS가 함께 사용한다. Debug 전용 문자열과 동적 조회 키도 있어 한 타깃·구성의 추출 결과만으로 전체 카탈로그의 사용 여부를 판단할 수 없다.

Shared 2,628개 중 1,078개, Watch 296개 중 69개가 `manual`이 아니었다. 일부는 `stale`, 일부는 상태 필드가 없었다. 실제 Xcode `xcstringstool sync`에 부분 추출 결과를 전달하면, 자동 관리 항목은 추출 여부에 따라 `stale`이 추가되거나 제거됐다. `manual` 항목은 유지됐다.

## Solution

기존 수동 카탈로그 관리 정책에 맞춰 두 카탈로그의 기존 항목을 `extractionState: manual`로 통일했다. 키, 번역, 보간, 주석, `shouldTranslate`, 그 밖의 JSON 값은 모두 보존했다. 자동 추출 설정은 변경하지 않았으므로 새로운 문자열 발견은 유지된다.

| File | Change | Reason |
|------|--------|--------|
| Shared/Resources/Localizable.xcstrings | 1,078개 추출 상태 수동 관리 | 타깃·구성별 상태 변경 방지 |
| DUNEWatch/Resources/Localizable.xcstrings | 69개 추출 상태 수동 관리 | 동적·조건부 문자열의 상태 변경 방지 |
| scripts/tests/test_format_xcstrings.py | 상태 불변식과 실제 Xcode sync 회귀 테스트 추가 | 이후 자동 관리 항목 재유입 검출 |

formatter는 기존 값 보존 계약을 유지한다. 별도 자동 재작성 hook이나 빌드 후 Git 변경을 숨기는 처리는 추가하지 않았다.

### Validation

- 수정 전 상태 불변식 테스트가 Shared 1,078개·Watch 69개에서 실패했다.
- `python3 -B -m unittest scripts.tests.test_format_xcstrings`: 6개 통과, skip 0.
- 두 카탈로그 복사본에 빈 추출·앞쪽 일부 키·뒤쪽 일부 키를 순차 적용한 실제 `xcstringstool sync` 6회 모두 바이트 동일.
- JSON 비교: 총 2,924개 키 및 `extractionState` 이외 모든 값 동일.
- `xcstringstool compile`: 양쪽 모두 성공. 이전에 컴파일되던 번역 값의 변경·삭제는 0개다. 수동 관리 전환으로 기존에 생략되던 항목이 추가된다(ko/ja: Shared 각 31개, Watch 각 16개; en 기본 언어 항목도 추가).
- `scripts/build-ios.sh`: iOS·embedded Watch·Widget 통합 빌드 성공. 빌드 후 `git status --short`가 비어 있어 두 카탈로그와 프로젝트 파일에 추가 diff 없음.
- UI 판정기는 리소스 경로를 full fallback으로 분류하지만, 실제 변경은 추출 상태뿐이며 앱 코드·문구·키·레이아웃·내비게이션 변경이 없다. 직접 sync·compile·빌드로 영향 범위를 검증하고 UI 실행과 디자인맵 재캡처는 skipped로 기록했다. UI 통과로 간주하지 않는다.
- 9,527줄 diff는 review skill의 대용량 예외로 주 에이전트가 Security·Performance·Architecture·Data Integrity·Simplicity를 직접 검토했다. P1/P2/P3 모두 0개. Agent-Native 및 UI/대량 처리 전문 검토는 해당 변경 없음으로 제외했다.

## Prevention

새 번역을 등록할 때 해당 항목에 `extractionState: manual`을 지정하고 기존 formatter를 실행한다. 위 Python 회귀 테스트로 수동 관리 상태와 Xcode sync 안정성을 함께 검사한다. formatter `--check`는 포맷만 검사하므로 상태 회귀 테스트를 대신하지 않는다.

수동 관리 항목은 코드 삭제 시 자동 stale 경고를 받지 않는다. 미사용 번역 삭제는 전체 타깃과 동적 조회 사용처를 확인한 후 명시적으로 수행한다. 이번 변경에서는 기존 번역을 삭제하지 않았다. `.claude/**`는 변경하지 않았고 기존 정책을 적용했으므로 별도 규칙 추가는 필요 없다.

## Lessons Learned

포맷 차이와 추출 메타데이터 차이는 별개의 원인이다. 포맷을 Xcode와 맞추는 것만으로 공유 카탈로그의 추출 상태 변경은 해결되지 않는다. `stale`은 실제 미사용을 보장하지 않으며 컴파일 출력에도 영향을 줄 수 있으므로 번역 데이터 비교와 실제 Xcode 도구 검증을 함께 수행한다.

Apple 공식 동작 설명: [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).
