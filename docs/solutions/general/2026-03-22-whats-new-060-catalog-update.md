---
tags: [whats-new, localization, xcstrings, json-catalog, version-bump, 0.6.0, sf-symbols]
date: 2026-03-22
category: general
status: implemented
---

# What's New 카탈로그 업데이트 (0.6.0)

## Problem

0.5.0 이후 구현된 주요 기능들(Exercise Form Coach, Corrective Exercises, Life Tab Overhaul, Watch Posture Monitor, Auto-Linked Achievements, Watch Bedtime Reminder)이 What's New 카탈로그에 반영되지 않은 상태.

## Solution

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/project.yml` | MARKETING_VERSION 0.5.0 → 0.6.0, 0.6.0.json 리소스 등록 |
| `DUNE/Data/Resources/whats-new/0.6.0.json` | 6 feature 항목 추가 |
| `DUNE/Data/Resources/whats-new/catalog.json` | 0.6.0 릴리스 엔트리 추가 |
| `Shared/Resources/Localizable.xcstrings` | 13개 새 문자열 en/ko/ja 번역 추가 |
| `DUNETests/WhatsNewManagerTests.swift` | 0.6.0 파싱/ID/L10N 테스트 3건 + 릴리스 수 업데이트 |

### 핵심 패턴

1. **Per-version JSON**: `whats-new/0.6.0.json` 파일 생성 (0.5.0 이후 per-version 구조)
2. **catalog.json**: 배열 최상단에 새 release 객체 추가
3. **xcstrings Python 조작**: 13개 키를 안전하게 추가 (수동 편집 시 JSON 깨짐 위험)
4. **extractionState: manual**: 수동 추가 키에 필수 — 누락 시 Xcode가 auto-extracted로 처리

## Prevention

- **SF Symbol 검증**: 새 symbolName 사용 시 코드베이스에서 동일 심볼 사용 여부 확인. `applewatch.motion` 같은 존재하지 않는 심볼은 런타임에 nil 반환
- **extractionState: manual**: xcstrings에 수동 추가하는 모든 키에 포함 필수
- **xcstrings 편집은 Python**: JSON 구조 보존을 위해 수동 편집 금지

## Lessons Learned

- 0.4.0, 0.5.0과 동일한 패턴. 데이터만 추가하면 UI 자동 반영
- SF Symbol 이름은 코드베이스 내 기존 사용 사례로 검증하는 것이 가장 안전
- `extractionState` 누락은 즉각적 문제를 일으키지 않지만 향후 localization export 시 데이터 손실 위험
