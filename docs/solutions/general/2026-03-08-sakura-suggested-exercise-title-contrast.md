---
tags: [swiftui, theme, sakura, activity, suggested-workout, contrast]
date: 2026-03-08
category: solution
status: implemented
---

# Sakura Suggested Exercise Title Contrast

## Problem

Sakura theme에서 Activity 탭의 추천운동 카드 제목이 거의 보이지 않았다.

## Root Cause

추천운동 카드 제목이 `theme.sandColor`를 사용하고 있었다.

`sandColor`는 원래 장식용 muted text 토큰인데, Sakura의 밝은 card/material 배경 위에서는 대비가 너무 낮아 운동명이 사실상 사라져 보였다.

## Solution

추천운동 카드의 운동명은 장식용 theme text 대신 surface-aware semantic text를 사용하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/Components/SuggestedExerciseRow.swift` | 운동명 foreground를 `theme.sandColor`에서 `.primary`로 변경, unused `appTheme` environment 제거 | 밝은 테마 카드에서도 제목 가독성 확보 |

## Prevention

- light material/card surface 위의 핵심 제목에는 decorative theme text를 쓰지 않는다.
- `theme.sandColor`는 muted/decorative copy, axis label, 보조 텍스트에만 사용한다.
- theme-specific screenshot에서 본문 제목이 희미하면 먼저 semantic text와 decorative text가 뒤바뀌지 않았는지 확인한다.
