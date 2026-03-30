---
tags: [whats-new, version-bump, 0.7.0, localization]
date: 2026-03-30
category: plan
status: draft
---

# 0.7.0 What's New 카탈로그 업데이트 및 버전 범프

## 목표

0.6.0 이후 구현된 주요 기능 5개를 What's New 카탈로그에 등록하고, MARKETING_VERSION을 0.7.0으로 올린다.

## 영향 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/Resources/whats-new/0.7.0.json` | 신규 — 5개 feature 항목 |
| `DUNE/Data/Resources/whats-new/catalog.json` | 0.7.0 릴리스 엔트리 추가 (최상단) |
| `DUNE/project.yml` | MARKETING_VERSION 0.6.0 → 0.7.0 |
| `Shared/Resources/Localizable.xcstrings` | 11개 새 문자열 en/ko/ja (5 title + 5 summary + 1 intro) |
| `DUNETests/WhatsNewManagerTests.swift` | 0.7.0 파싱/ID/L10N 테스트 + 릴리스 수 업데이트 |

## Feature 목록

1. **Personal Records Revamp** (activity) — trophy.fill
2. **Advanced Sleep Analysis** (wellness) — moon.stars.fill
3. **Today Dashboard Upgrade** (today) — square.grid.2x2.fill
4. **Live Set Timer** (activity) — timer
5. **Template Exercise Control** (activity) — forward.fill

## 구현 단계

### Step 1: 0.7.0.json 생성
- `DUNE/Data/Resources/whats-new/0.7.0.json` 파일 생성
- 0.6.0.json 구조 동일하게 5개 feature 작성

### Step 2: catalog.json 업데이트
- releases 배열 최상단에 0.7.0 엔트리 추가

### Step 3: project.yml 버전 범프
- MARKETING_VERSION anchor를 "0.7.0"으로 변경

### Step 4: xcstrings 번역 추가
- Python 스크립트로 11개 키 (en/ko/ja) 안전하게 추가
- extractionState: manual 필수

### Step 5: 테스트 업데이트
- WhatsNewManagerTests에 0.7.0 검증 추가
- 릴리스 총 수 업데이트 (6→7)

### Step 6: xcodegen + 빌드 검증
- `scripts/build-ios.sh` 실행

## 테스트 전략

- WhatsNewManager 파싱 테스트 (0.7.0 feature 수, ID 유일성)
- 번역 키 존재 검증
- 빌드 통과

## 리스크

- SF Symbol 이름 검증 필요 (모두 기존 사용 심볼)
- xcstrings 수동 편집 시 JSON 깨짐 → Python 사용
