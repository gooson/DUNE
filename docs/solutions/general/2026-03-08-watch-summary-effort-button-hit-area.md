---
tags: [watchos, swiftui, button, hit-testing, sheet, focus, digital-crown]
date: 2026-03-08
category: solution
status: implemented
---

# Watch Summary Effort Sheet Stability Fix

## Problem

watch workout summary 화면에서 `Workout Intensity` 카드가 간헐적으로 눌리지 않았고, 최종 세트 완료 직후 자동으로 뜨는 effort input sheet가 12초가 지나기 전에 사라질 수 있었다.

## Root Cause

강도 카드는 custom `Button` + `.buttonStyle(.plain)` 조합이었지만, 카드 전체 hit area를 명시하지 않았다.

동시에 effort sheet의 crown focus 상태를 시트가 뜨는 즉시 잡으면서, watchOS sheet presentation 안정화 전에 crown host activation이 개입할 수 있었다.

## Solution

- summary card에 `maxWidth`와 `contentShape`를 추가해 카드 전체를 명시적인 tap target으로 만들었다.
- effort sheet를 전용 subview로 분리해 crown focus 상태를 sheet 내부에 한정했다.
- 12초 auto-dismiss 타이머는 유지하되, crown focus는 `Task.yield()` 뒤에 붙여 시트가 먼저 안정적으로 표시되도록 했다.

## Prevention

- watchOS에서 카드형 plain button은 항상 `frame(maxWidth: .infinity)`와 `contentShape(...)`를 같이 검토한다.
- 시트 전용 focus/crown 상태는 부모 화면이 아니라 sheet 전용 subview에 둔다.
- 자동 표시되는 watch sheet에서 crown focus가 필요하면 즉시 활성화하지 말고 한 프레임 defer한다.
