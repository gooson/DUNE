tags: [sfsymbols, icons, muscle-map, body-parts, unit-test]
date: 2026-03-08
category: solution
status: implemented
---

# Invalid SF Symbol `figure.rowing` Fix

## Problem

일부 화면에서 콘솔에 `No symbol named 'figure.rowing' found in system symbol set`가 반복 출력됐다.

증상은 아이콘 fallback 렌더링과 디버깅 노이즈로 이어졌고, 근육군/신체 부위 아이콘처럼 자주 그려지는 경로에서 계속 재발했다.

## Root Cause

`MuscleGroup`와 `BodyPart`의 icon mapping이 존재하지 않는 SF Symbol 이름 `figure.rowing`을 반환하고 있었다.

같은 도메인의 다른 경로(`WorkoutActivityType.rowing`)는 이미 유효한 심볼인 `figure.rower`를 쓰고 있었기 때문에, 동일 개념의 아이콘 이름이 파일마다 drift된 상태였다.

## Solution

모든 rowing 관련 icon mapping을 `figure.rower`로 통일하고, 실제 iOS system symbol set에서 해상 가능한지 unit test로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Extensions/MuscleGroup+View.swift` | `back`, `lats`의 icon name을 `figure.rower`로 수정 | invalid SF Symbol 제거 |
| `DUNE/Presentation/Shared/Extensions/BodyPart+View.swift` | `upperBack` icon name을 `figure.rower`로 수정 | body-part icon parity 복구 |
| `DUNETests/DomainModelCoverageTests.swift` | `UIImage(systemName:)` 기반 symbol resolution test 추가 | 재발 방지 |

### Key Code

```swift
#expect(UIImage(systemName: MuscleGroup.back.iconName) != nil)
#expect(UIImage(systemName: MuscleGroup.lats.iconName) != nil)
#expect(UIImage(systemName: BodyPart.upperBack.iconName) != nil)
```

## Prevention

- SF Symbol literal을 새로 추가하거나 바꿀 때는 동일 개념을 쓰는 다른 enum/file과 drift가 없는지 먼저 확인한다.
- `iconName`처럼 문자열 반환 API는 snapshot보다 먼저 `UIImage(systemName:) != nil` 같은 해상도 테스트로 고정한다.
- “보이기만 하면 됨”이 아니라, 존재하지 않는 심볼이 콘솔에 계속 찍히지 않는지도 품질 기준에 포함한다.

## Lessons Learned

문자열 기반 아이콘 매핑은 컴파일 타임에 깨지지 않아서 drift가 오래 숨어 있을 수 있다. 공용 아이콘 계약은 literal review만으로 충분하지 않고, 실제 system symbol resolution을 테스트로 묶는 편이 안전하다.
