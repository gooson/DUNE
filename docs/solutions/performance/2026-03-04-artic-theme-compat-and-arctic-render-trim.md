---
tags: [theme, arctic-dawn, artic-alias, watch-sync, swiftui, render-allocation, performance]
category: performance
date: 2026-03-04
severity: important
related_files:
  - DUNE/Domain/Models/AppTheme.swift
  - DUNE/App/DUNEApp.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNETests/AppThemeTests.swift
related_solutions:
  - design/2026-03-03-arctic-dawn-theme.md
  - performance/2026-03-04-arctic-aurora-lod-frame-stability.md
---

# Solution: Artic Alias Compatibility and Arctic Overlay Render Trim

## Problem

### Symptoms

- 사용자 요청/입력에서 `artic` 오탈자가 들어오면 정식 테마(`arcticDawn`)로 직접 매핑되지 않아 fallback 테마로 보일 수 있었다.
- Arctic 오로라 오버레이에서 `Array(...enumerated())` 패턴과 중복 애니메이션 시작 경로가 있어 프레임당 불필요 오버헤드가 누적됐다.

### Root Cause

- theme rawValue 해석 규칙이 단일 소스로 정리되지 않아 iOS/Watch/WatchConnectivity 각 경로가 제각각 raw string을 처리했다.
- overlay 루프에서 임시 배열 생성이 반복되고, curtain overlay에서 `.task`와 `.onAppear`가 동시에 애니메이션을 시작했다.

## Solution

`AppTheme`에 정규화 유틸리티를 추가해 `artic` 계열 입력을 `arcticDawn`으로 통일했다.
동시에 Arctic overlay 루프를 index 순회로 바꿔 임시 배열 생성을 제거하고, curtain의 중복 애니메이션 시작 경로를 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/AppTheme.swift` | `storageKey`, `resolvedTheme`, `normalizedRawValue` 추가 | 테마 저장/해석 규칙 단일 소스화 |
| `DUNE/App/DUNEApp.swift` | 앱 시작 시 persisted theme 정규화/재저장 | 기존 사용자 데이터(`artic` 오탈자) 자동 복구 |
| `DUNEWatch/DUNEWatchApp.swift` | watch 테마 해석에 정규화 함수 사용 | iOS/watch 파싱 일관성 보장 |
| `DUNEWatch/WatchConnectivityManager.swift` | 수신 theme rawValue 정규화 | watch 동기화 경로에서 alias 호환 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | 송신 theme rawValue 정규화 | watch 전송값 canonical 유지 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | index 기반 루프 + static palette + curtain 중복 시작 제거 | 렌더 시 임시 할당 감소, 애니메이션 시작 경로 단순화 |
| `DUNETests/AppThemeTests.swift` | `artic` alias 정규화 테스트 추가 | 회귀 방지 |

### Key Code

```swift
extension AppTheme {
    static func resolvedTheme(fromPersistedRawValue rawValue: String?) -> AppTheme? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = AppTheme(rawValue: trimmed) { return direct }

        switch trimmed.lowercased() {
        case "artic", "articdawn", "arctic", "arcticdawn":
            return .arcticDawn
        default:
            return nil
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] theme rawValue를 파싱할 때 `AppTheme.resolvedTheme(...)` 단일 경로를 사용하는가?
- [ ] watch 송수신 theme 값은 `AppTheme.normalizedRawValue(...)`를 거쳐 canonical rawValue를 사용했는가?
- [ ] 고빈도 SwiftUI 루프에서 `Array(...enumerated())` 임시 할당을 반복하지 않는가?
- [ ] 동일 뷰에서 애니메이션 시작 트리거(`.task`/`.onAppear`)가 중복되지 않는가?

## Lessons Learned

- 테마명 오탈자 호환은 enum case 추가보다 “정규화 파서 단일화”가 유지보수와 UX 측면에서 안전하다.
- 프레임 품질을 건드리지 않아야 할 때는 레이어 파라미터 변경보다 할당/시작 경로 정리가 더 안정적인 성능 개선 수단이다.
