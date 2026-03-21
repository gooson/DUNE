---
tags: [version-bump, whats-new, 0.6.0, localization]
date: 2026-03-22
category: plan
status: approved
---

# Plan: 버전 0.6.0 + What's New 카탈로그 업데이트

## Summary

MARKETING_VERSION을 0.5.0 → 0.6.0으로 범프하고, What's New JSON에 6개 신규 기능을 추가한다.

## Affected Files

| # | 파일 | 변경 유형 | 목적 |
|---|------|----------|------|
| 1 | `DUNE/project.yml` | 수정 | MARKETING_VERSION 0.5.0 → 0.6.0 |
| 2 | `DUNE/Data/Resources/whats-new/0.6.0.json` | **신규** | 6개 feature 항목 |
| 3 | `DUNE/Data/Resources/whats-new/catalog.json` | 수정 | 0.6.0 릴리스 엔트리 추가 |
| 4 | `DUNE/project.yml` | 수정 | whats-new/0.6.0.json 리소스 등록 |
| 5 | `Shared/Resources/Localizable.xcstrings` | 수정 | 새 문자열 en/ko/ja 번역 추가 |
| 6 | `DUNETests/WhatsNewManagerTests.swift` | 수정 | 0.6.0 파싱/ID 테스트 추가 |

## Implementation Steps

### Step 1: 버전 범프
- `project.yml`의 `MARKETING_VERSION: &marketingVersion "0.5.0"` → `"0.6.0"`

### Step 2: 0.6.0.json 생성
- 6개 feature 항목 (사용자 승인 완료)

### Step 3: catalog.json 업데이트
- 0.6.0 엔트리를 배열 최상단에 추가

### Step 4: project.yml 리소스 등록
- `Data/Resources/whats-new/0.6.0.json` 추가

### Step 5: xcstrings 번역 추가
- titleKey 6개 + summaryKey 6개 + introKey 1개 = 최대 13개 키
- 기존 키 중복 확인 후 신규 키만 추가

### Step 6: 테스트 업데이트
- WhatsNewManagerTests에 0.6.0 파싱 테스트 추가

## Test Strategy

- WhatsNewManagerTests: 0.6.0 JSON 파싱, feature 수, ID 검증
- 빌드 성공 확인

## Risk / Edge Cases

- xcstrings 43K줄 파일 수동 편집 시 JSON 깨짐 위험 → Python 스크립트 활용
- SF Symbol 이름 오류 시 런타임 nil 반환 → 빌드 후 확인 필요
