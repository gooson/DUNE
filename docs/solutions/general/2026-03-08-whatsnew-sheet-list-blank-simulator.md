tags: [swiftui, whats-new, list, scrollview, simulator, sheet]
date: 2026-03-08
category: solution
status: implemented
---

# What's New Sheet Blank Simulator Fix

## Problem

시뮬레이터에서 자동 `What's New` 시트가 간헐적으로 본문 없이 하얗게 보일 수 있었다.

증상은 navigation title과 `Close` 버튼만 보이고, release header와 feature rows가 통째로 사라지는 형태였다.

## Root Cause

`WhatsNewView`가 launch 시점 sheet 안에서 `List` 기반으로 렌더링되고 있었다.

이 화면은 정적 release content인데도 `List`의 UIKit-backed virtualization, custom wave background, automatic sheet presentation이 겹치면서 시뮬레이터에서 간헐적으로 본문 렌더링이 비는 현상이 있었다.

## Solution

정적 공지 surface에 맞게 `List`를 `ScrollView + LazyVStack`으로 교체했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | `List` 제거, `ScrollView + LazyVStack`으로 재구성 | simulator blank body 회피, static release surface 안정화 |

### Key Code

```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
        ForEach(releases) { release in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                releaseHeader(release: release)
                ...
            }
        }
    }
}
```

## Prevention

- launch 시점 자동 sheet처럼 정적 announcement surface에는 `List`보다 `ScrollView + LazyVStack`을 우선 검토한다.
- row reuse, section chrome, edit interaction이 필요 없는 read-only 콘텐츠는 UIKit-backed `List`를 피하는 편이 안전하다.
- simulator-only blank screen도 데이터 문제와 렌더링 컨테이너 문제를 먼저 분리해서 본다.

## Lessons Learned

`List`는 편하지만, static presentation surface에서는 오히려 과한 컨테이너일 수 있다. 특히 automatic sheet + custom background + launch timing이 겹치면 simulator 쪽 렌더링 불안정성이 드러나기 쉬워서, 단순 스택 기반 구성이 더 견고하다.
