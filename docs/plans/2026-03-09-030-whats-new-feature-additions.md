---
tags: [whats-new, 0.3.0, health-data-qa, ai-workout-generation]
date: 2026-03-09
category: plan
status: draft
---

# Plan: 0.3.0 What's New에 신규 머지 기능 추가

## Summary

최근 머지된 PR #430 (Health Data Q&A)과 PR #431 (AI Workout Generation)을 0.3.0 What's New 항목에 추가한다. JSON 수정 + xcstrings 번역 추가만 필요하며 코드 변경은 없다.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/Resources/whats-new.json` | 0.3.0 features에 2개 항목 추가, introKey 업데이트 |
| `Shared/Resources/Localizable.xcstrings` | 새 titleKey/summaryKey/introKey에 대한 en/ko/ja 번역 |

## Implementation Steps

### Step 1: whats-new.json 수정

0.3.0 features 배열에 2개 항목 추가:

1. **healthDataQA** (Health Data Q&A)
   - id: "healthDataQA"
   - titleKey: "Health Q&A"
   - summaryKey: "Ask questions about your health data and get instant answers powered by on-device intelligence."
   - symbolName: "bubble.left.and.text.bubble.right.fill"
   - area: "today"

2. **aiWorkoutGeneration** (AI Workout Generation)
   - id: "aiWorkoutGeneration"
   - titleKey: "AI Workout Builder"
   - summaryKey: "Describe your ideal workout in natural language and get a ready-to-use template instantly."
   - symbolName: "wand.and.stars"
   - area: "activity"

introKey 업데이트: 새 기능 2개를 포함하도록 문구 갱신.

Verification: `python3 -c "import json; d=json.load(open('...')); print(len(d['releases'][0]['features']))"` → 8

### Step 2: xcstrings 번역 추가

새로 추가되는 키에 대해 en/ko/ja 3개 언어 등록:

| Key | en | ko | ja |
|-----|-----|-----|-----|
| Health Q&A | Health Q&A | 건강 Q&A | ヘルスQ&A |
| (summaryKey) | Ask questions about... | 건강 데이터에 대해 질문하면... | 健康データについて質問すると... |
| AI Workout Builder | AI Workout Builder | AI 운동 빌더 | AIワークアウトビルダー |
| (summaryKey) | Describe your ideal workout... | 원하는 운동을 자연어로... | 理想のワークアウトを自然言語で... |
| (introKey) | (updated intro) | (updated intro) | (updated intro) |

Verification: xcstrings에 모든 키가 3개 언어로 존재

## Test Strategy

- `scripts/build-ios.sh` 빌드 성공 확인
- JSON 구문 검증: `python3 -c "import json; json.load(open(...))"`
- 테스트 면제: UI View 변경 없음

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| xcstrings 키 불일치 | titleKey/summaryKey 문자열이 xcstrings 키와 정확히 일치하는지 확인 |
| JSON 파싱 실패 | python3 검증 + 빌드 테스트 |
| introKey가 길어져 UI 깨짐 | 기존과 동일한 길이 수준 유지 |
