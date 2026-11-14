---
title: iPad accessibility-size AI form viewport check
tags: [ios, swiftui, xctest, dynamic-type, scroll-kinetics, ai-workout-builder]
---

# iPad AI form viewport check

## Problem
The W34 iPad MAX test had two failed captures: one clipped the availability text and the conditional retry left the Generate button 11.5pt under the navigation bar. The test’s short high-velocity drag continued scrolling after release, so a geometry check could observe a different final position.

## Solution
The W34 test’s bounded drag uses 80px/s and a 0.35s end hold, while retaining the full prompt, Generate, and availability frame assertions. The approved extra iPad MAX selector passed 1/1 at integration source `15450f83d`. Native empty and filled PNG/AX evidence is preserved in the W34 gallery. The app’s Generate label and availability message use accessibility-size wrapping; generation behavior is unchanged.

## Prevention
For dynamic-type scroll audits, check the final settled position and the entire relevant control frame inside the visible viewport. Keep failure captures and same-ID retry receipts separate from later positive runs.

## Lessons Learned
A hittable SwiftUI control can still be partially covered by navigation. Slow, settled gestures give the geometry assertion the state a user would see.
