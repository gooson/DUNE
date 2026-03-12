---
tags: [whats-new, localization, xcstrings, json-catalog, version-bump]
date: 2026-03-12
category: general
status: implemented
---

# What's New 카탈로그 업데이트 (0.4.0)

## Problem

0.3.0 이후 구현된 기능들(Set-Level RPE, Stair Climber, Cardio Fitness, Watch Cardio UX, Workout Rewards, Sleep Deficit Analysis, Life Tab Upgrade)이 What's New 카탈로그에 반영되지 않아 사용자에게 신규 기능이 노출되지 않는 상태.

## Solution

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/Resources/whats-new.json` | 0.4.0 release 엔트리 추가 (7 features) |
| `Shared/Resources/Localizable.xcstrings` | 16개 새 문자열 en/ko/ja 번역 추가 |
| `DUNE/project.yml` | MARKETING_VERSION 0.3.0 → 0.4.0 (5 targets) |
| `DUNETests/WhatsNewManagerTests.swift` | 0.4.0 파싱/ID/L10N 테스트 3건 추가 |

### 핵심 패턴

1. **JSON 카탈로그**: `whats-new.json`에 release 객체 추가. `introKey`, `titleKey`, `summaryKey`는 영어 텍스트 = xcstrings 키
2. **xcstrings 대량 추가**: 30K줄+ 파일은 Python JSON 조작으로 안전하게 수정 (수동 편집 위험)
3. **introKey 일관성**: feature 항목 제거 시 introKey도 동기 업데이트 필수 (리뷰에서 P2로 포착)

## Prevention

- feature 항목 추가/제거 시 introKey 텍스트가 실제 feature 목록과 일치하는지 검증
- xcstrings 대량 수정 시 Python 스크립트 활용 (JSON key 정렬 자동 처리)
- 버전 범프는 `project.yml`의 모든 target에 일괄 적용 (`replace_all` 사용)

## Lessons Learned

- What's New 시스템은 JSON → Model → View 파이프라인이 깔끔하여 데이터만 추가하면 UI 자동 반영
- feature 제거 후 introKey 불일치는 놓치기 쉬운 패턴 — 리뷰에서 Data Integrity 관점으로 포착 가능
