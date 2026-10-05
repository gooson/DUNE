---
tags: [watchos, theme, contrast]
category: plan
topic: contour-watch-color-contrast
date: 2026-10-05
status: implemented
confidence: high
related_solutions: [2026-09-20-contour-atlas-theme, 2026-10-05-contour-watch-color-contrast]
---

# Contour Atlas 워치 가독성 수정

## Context / Requirements

워치에서 흰 글씨 뒤에 밝은 Contour 배경이 표시된다. 워치 전용 어두운 팔레트를
명시하고 기존 iOS universal light/dark 값과 테마 동기화 동작을 보존한다.

## Research / Approach

- `WatchWaveBackground` → 공유 `ContourBackground` → `ContourBackground` named color 경로 확인.
- 기존 Contour 구현 문서와 이번 해결 문서, Apple Dark Mode 지침 확인.
- 관련 brainstorm/활성 TODO 검색 결과 이번 버그에 해당하는 항목 없음.
- 색상 26개에 appearance 조건 없는 watch idiom을 추가한다.
- 대안인 전역 colorScheme 강제는 플랫폼 자산 선택을 명확하게 보장하지 못하고
  다른 테마에도 영향을 줄 수 있어 채택하지 않는다.

## Affected Files

| File | Change | Purpose |
|------|--------|---------|
| Shared/Resources/Colors.xcassets/Contour*.colorset/Contents.json | watch 변형 26개 | 배경/전경 팔레트 일치 |
| scripts/tests/test-contour-watch-colors.py | 회귀 검사 | 변형 누락 및 대비 검사 |
| DUNEWatch/WatchConnectivityManager.swift | UI fixture 한정 테마 입력 | 재현 가능한 테마 UI 검증 |
| DUNEWatchUITests/Smoke/WatchContourThemeTests.swift | 테마 UI 테스트 | 홈/운동 목록 표시 및 캡처 |
| docs/solutions/general/2026-10-05-contour-watch-color-contrast.md | 검증 결과 갱신 | 재발 방지 |

## Implementation Steps

1. 기존 수정의 watch variant 값과 universal 값 보존을 검사하고 커밋한다.
2. 기존 watch UI fixture에 명시적 테마 실행 인자를 추가하고 UI 테스트를 작성한다.
3. iOS/embedded Watch 빌드, 색상 회귀 검사, watch UI suite 및 테마 캡처를 검증한다.
4. 전문 리뷰 결과를 해결하고 문서/PR을 생성해 머지한다.

## Testing Strategy

- Python 검사: 26개 변형, 흰색/ink/accent/sand/bronze 대 배경/카드의 대비 ≥ 4.5:1.
- 자산 컴파일 및 `scripts/build-ios.sh` 통합 빌드.
- `scripts/plan-ui-tests.py --base origin/main` 결과를 저장한다. 공용 자산 경로는 기본적으로
  iOS/watch full 판정 대상이나 universal 항목이 byte-equivalent이고 watch idiom만
  추가되는 것을 구조적으로 증명하면 iOS UI를 면제한다. watch full은 유지한다.
- watch 테마 테스트가 홈과 운동 목록을 렌더링하며 스크린샷을 보존하는지 확인한다.
- 실제 캡처를 열어 밝은 배경이 사라졌는지 확인한다. 요소 존재 검사를 픽셀 검증으로 보고하지 않는다.

## Edge Cases / Risks

| Case / Risk | Handling |
|-------------|----------|
| watchOS가 dark appearance를 선택하지 않음 | unconditional watch idiom 사용 |
| 배경만 어두워져 전경도 어두운 채 남음 | 전체 테마 팔레트를 함께 지정 |
| fixture가 실제 동기화에 영향 | UI testing argument 경로 안에서만 적용 |
| simulator 환경/무관한 기존 UI 실패 | 원인 변화 없이 재시도하지 않고 게이트 실패 기록 |
| iOS/다른 플랫폼 회귀 | 기존 universal 값 보존 검사와 통합 빌드 |

## Confidence

높음: 실제 워치용 자산 컴파일과 대비 검사 통과. 실제 화면 확인은 파이프라인에서 추가한다.

## 최종 검증 범위

사용자의 핵심 작업·속도 우선 요청으로 추가 전체 재실행은 취소했다. 기존 13개 UI 테스트 통과와 수정한 테마 테스트 1개 통과, 화면 캡처 확인을 최종 증빙으로 유지한다.
