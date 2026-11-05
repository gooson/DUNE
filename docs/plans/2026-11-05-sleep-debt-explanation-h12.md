---
tags: [sleep, explanation, accessibility, batch01]
date: 2026-11-05
category: plan
status: done
updated: 2026-11-06
confidence: high
---

# H12 수면 부족 설명 구현 계획

## Context / Requirements

설명의 읽기 순서와 시각적 위계를 개선한다. 기존 제목·설명 원문·네 등급의 범위·색 점·원래 섹션 아이콘·시트 detent와 드래그를 보존한다. 임의 측정 막대나 새 건강 해석은 추가하지 않는다. Close는 기존 번역 키를 사용한다.

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift` | 설명 히어로·구분 카드·원래 표식과 아이콘·닫기·큰 글씨·AX |
| `DUNEUITests/Smoke/SleepDetailSmokeTests.swift` | 기존 진입 보존, 실제 원문/등급/닫기/복귀와 MAX 검증 |
| sleep-debt-explanation-h12 layout/theme/index/manifest/README | 먼저 배치·표현 기준 보존 |
| 실제 디자인맵 H12·새 갤러리 | 네 프로필의 fresh PNG/AX, 명시한 상태만 갱신 |

## Implementation Steps

1. 원래 설명과 임계값, sheet consumer, 기존 키를 대조한다.
2. layout/theme 기준을 먼저 기록하고 고정된 표현을 구현한다. 장식은 측정값처럼 보이지 않게 하며 원래 색 점을 보존한다.
3. 큰 글씨는 등급 행을 세로 배치한다. 긴 문단은 스크롤로 시작과 끝을 읽으며 전체 문단이 한 화면에 들어올 것을 요구하지 않는다.
4. H10/H11/H13과 표준 실행기의 기기별 selector 합집합으로 검증한다. 테스트 attachment와 실제 맵 캡처를 재사용한다.
5. 독립 리뷰·문서·실제 맵 후 화면 PR을 분리하고 통상 머지한다.

## Testing Strategy / Risks

일반 네 프로필과 Duo 접힘 MAX에서 원래 설명·마지막 등급·Close→수면 상세 복귀를 확인한다. 7개 method/8개 화면 상태 후보 중 해당 H12 결과만 증거로 연결한다. 초기 실행 예산 1200초, 한 소유 기기·한 실행만 사용한다. UI 변경이며 도메인/계산/카탈로그 미변경이므로 새 unit/full 회귀는 추가하지 않는다. 기존 medium/large detent를 강제 변경하지 않고 실제 뷰포트에 맞춰 긴 문단의 두 끝을 확인한다. seed 진입 skip는 통과로 세지 않는다.

## 검증 결과

관련 기기·상태의 SDK와 독립 PNG/AX 검토를 완료했다. [실제 화면·원본 출처](../design/full-redesign-map/review/h12-sleep-debt-explanation-native-2026-11-06/index.html)의 실행 소스와 범위를 따른다. PR·머지는 GitHub 기록으로 확인한다.
