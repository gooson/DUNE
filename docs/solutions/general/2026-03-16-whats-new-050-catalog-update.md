---
tags: [whats-new, localization, xcstrings, json-catalog, version-bump, 0.5.0]
date: 2026-03-16
category: general
status: implemented
---

# What's New 카탈로그 업데이트 (0.5.0)

## Problem

0.4.0 이후 구현된 주요 기능들(Posture Analysis, Morning Briefing, RPE Trend, 3D Muscle Map Overhaul, Watch Exercise Reorder, Hourly Condition, Template Nudge)이 What's New 카탈로그에 반영되지 않아 사용자에게 신규 기능이 노출되지 않는 상태.

## Solution

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/project.yml` | MARKETING_VERSION 0.4.0 → 0.5.0 (5 targets) |
| `DUNE/Data/Resources/whats-new.json` | 0.5.0 release 엔트리 추가 (7 features) |
| `Shared/Resources/Localizable.xcstrings` | 14개 새 문자열 en/ko/ja 번역 추가 (1개 기존 재사용) |
| `DUNETests/WhatsNewManagerTests.swift` | 0.5.0 파싱/ID/L10N 테스트 3건 추가 |

### 핵심 패턴

1. **JSON 카탈로그**: `whats-new.json` 배열 최상단에 새 release 객체 추가
2. **xcstrings 대량 추가**: Python JSON 조작으로 안전하게 키 추가 (수동 편집 시 43K 줄 파일 깨짐 위험)
3. **기존 키 재사용**: "Morning Briefing"은 이미 xcstrings에 존재하여 추가 불필요
4. **버전 범프**: `replace_all`로 project.yml 내 5개 target 일괄 적용

## Prevention

- feature 항목 추가/제거 시 introKey 텍스트가 실제 feature 목록과 일치하는지 검증
- xcstrings 대량 수정 시 Python 스크립트 활용 (JSON key 정렬 자동 처리)
- 기존 키 존재 여부 먼저 확인하여 중복 방지

## Lessons Learned

- 0.4.0과 동일한 패턴. JSON → Model → View 파이프라인이 안정적이어서 데이터만 추가하면 UI 자동 반영
- xcstrings에 이미 존재하는 키(예: "Morning Briefing")를 재확인하는 습관이 중요
