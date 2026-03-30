---
tags: [whats-new, localization, xcstrings, json-catalog, version-bump, 0.7.0]
date: 2026-03-30
category: general
status: implemented
---

# What's New 카탈로그 업데이트 (0.7.0)

## Problem

0.6.0 이후 구현된 주요 기능들(Personal Records Revamp, Advanced Sleep Analysis, Today Dashboard Upgrade, Live Set Timer, Template Exercise Control)이 What's New 카탈로그에 반영되지 않은 상태.

## Solution

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/project.yml` | MARKETING_VERSION 0.6.0 → 0.7.0 |
| `DUNE/Data/Resources/whats-new/0.7.0.json` | 5 feature 항목 추가 |
| `DUNE/Data/Resources/whats-new/catalog.json` | 0.7.0 릴리스 엔트리 추가 |
| `Shared/Resources/Localizable.xcstrings` | 11개 새 문자열 en/ko/ja 번역 추가 |
| `DUNETests/WhatsNewManagerTests.swift` | 0.7.0 파싱/ID/L10N 테스트 3건 + 릴리스 수 업데이트 (6→7) |

### 핵심 패턴

1. **Per-version JSON**: `whats-new/0.7.0.json` 파일 생성
2. **catalog.json**: 배열 최상단에 새 release 객체 추가
3. **xcstrings Python 조작**: 11개 키를 안전하게 추가
4. **extractionState: manual**: 수동 추가 키에 필수

## Prevention

- **SF Symbol 검증**: 모든 symbolName은 코드베이스에서 기존 사용 확인된 심볼만 사용
- **extractionState: manual**: xcstrings에 수동 추가하는 모든 키에 포함 필수
- **xcstrings 편집은 Python**: JSON 구조 보존을 위해 수동 편집 금지
- **테스트 3종 세트**: 파싱, ID 매칭, L10N 키 비어있지 않음 검증

## Lessons Learned

- 0.4.0~0.6.0과 동일한 패턴. 데이터만 추가하면 UI 자동 반영
- git log --no-merges + grep "feat"으로 릴리스 노트 후보를 빠르게 추출 가능
