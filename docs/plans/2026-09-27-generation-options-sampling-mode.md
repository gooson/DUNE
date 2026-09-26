---
topic: GenerationOptions samplingMode 전환
date: 2026-09-27
status: approved
confidence: high
related_solutions: [architecture/2026-03-09-health-data-qa-tool-calling.md]
related_brainstorms: [2026-03-08-apple-on-device-ml-sdk-research.md]
---

# Implementation Plan: GenerationOptions 경고 제거

## Context / Requirements
HealthDataQAService의 deprecated `sampling:` 초기화 인자를 `samplingMode:`로 교체한다. 기존 greedy, temperature 0.2, 최대 220 토큰을 유지한다.

## Approach
컴파일러와 Apple 공식 문서가 안내하는 인자명 교체를 적용한다. 경고 억제나 별도 래퍼는 불필요하다.

## Affected Files
- `DUNE/Data/Services/HealthDataQAService.swift`: 초기화 인자명 한 곳 수정
- 본 계획서 및 해결책 문서

## Implementation Steps
1. 작업 브랜치 생성 후 인자명을 교체하고 diff 확인 및 커밋.
2. 표준 iOS 빌드와 기존 UI 회귀 테스트 실행.
3. 리뷰, 해결책 기록, 검증 성공 시 PR 생성 및 머지.

## Testing Strategy
새 동작이 없는 인자명 변경이므로 신규 단위 테스트는 추가하지 않는다. SDK 컴파일 검증과 기존 테스트로 회귀를 확인한다.

## Risks / Edge Cases
설치된 SDK에 새 초기화가 없을 수 있으므로 실제 빌드로 확인한다. UI, 모델 저장, HealthKit 쿼리 동작은 변경하지 않는다. 검증 실패 시 게이트를 통과 처리하지 않는다.

## Confidence Assessment
High: 컴파일러가 대체 API를 명시하고 있으며 호출이 한 곳이다.
