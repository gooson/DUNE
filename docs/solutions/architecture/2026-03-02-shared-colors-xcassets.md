---
tags: [asset-catalog, colors, shared, watchOS, xcodegen, multi-target]
date: 2026-03-02
category: solution
status: implemented
---

# Shared Colors.xcassets로 iOS/watchOS 색상 통합

## Problem

색상 asset이 iOS(`DUNE/Resources/Assets.xcassets/Colors/`)와 watchOS(`DUNEWatch/Resources/Assets.xcassets/Colors/`)에 **중복 정의**되어 있었다. watchOS 시뮬레이터에서 `"No color named 'ForestAccent' found in asset catalog"` 런타임 에러 반복 발생.

**근본 원인**: 색상 추가/변경 시 양쪽 동기화 누락. watchOS 62개 색상 모두 iOS의 부분집합이었으나 6개는 값이 달랐음.

## Solution

### 구조

```
Shared/Resources/Colors.xcassets/    ← 63개 공유 색상 (NEW)
DUNE/Resources/Assets.xcassets/Colors/  ← 43개 iOS 전용 (KEEP)
DUNEWatch/Resources/Assets.xcassets/    ← Colors/ 폴더 삭제 (CLEAN)
```

### project.yml 변경

```yaml
targets:
  DUNE:
    sources:
      - path: Resources
        group: DUNE
      # Shared Colors
      - path: ../Shared/Resources/Colors.xcassets
        group: Shared/Resources

  DUNEWatch:
    sources:
      - path: ../DUNEWatch
      # Shared Colors
      - path: ../Shared/Resources/Colors.xcassets
        group: Shared/Resources
```

### 값 충돌 해결 (6개 색상)

| 색상 | 차이 | 결정 |
|------|------|------|
| Caution, Negative, Positive | watchOS: universal only / iOS: light+dark (동일 값) | iOS 값 → universal only로 정리 (Correction #120) |
| ForestDeep, ForestMid, ForestMist | dark 값 상이 | iOS 값 사용 (source of truth) |

## Key Decisions

1. **colorset은 .xcassets 루트에 직접 배치**: `provides-namespace: true` 불필요. 이름 충돌 없으므로 `Color("ForestAccent")` 그대로 동작
2. **iOS 값이 source of truth**: watchOS 값은 수동 동기화 누락으로 인한 차이
3. **light/dark 동일이면 universal만**: Correction #120 적용

## Prevention

1. **새 공유 색상 추가**: `Shared/Resources/Colors.xcassets/`에 추가하면 양쪽 자동 적용
2. **iOS 전용 색상 추가**: `DUNE/Resources/Assets.xcassets/Colors/`에 추가
3. **watchOS에서 "color not found"**: `Shared/` 또는 iOS-only 에 있는지 확인 → 공유 필요 시 Shared로 이동
4. **테마 색상 추가 시**: Forest/Ocean/Desert 3개 테마 + watch 공유 여부 체크

## Related

- Correction #119: xcassets 색상은 Colors/ 하위 배치
- Correction #120: light/dark 동일이면 universal만
- Correction #159: Asset catalog 폴더에 provides-namespace: true (단, .xcassets 루트에는 해당 없음)
- `docs/plans/2026-03-02-shared-colors-xcassets.md`: 원본 계획서
