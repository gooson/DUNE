---
tags: [review, notification, watch, cardio]
date: 2026-11-14
category: solution
status: reviewed
---

# Code Review Report

> Scope: 실제 origin/main 기준 알림 T12 수치 강조와 Watch C01·C02 존 통합. 기존 운동 카테고리3개 커밋 제외.
> Files reviewed: 원본68개 + 최종 캡처·문서 갱신. committed/staged/unstaged/untracked 포함.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | Open 없음 |
| P2 | 1 | Resolved1, Open0 |
| P3 | 0 | Open 없음 |

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Apple UX] Watch40mm 존 막대와 페이지 표시점 겹침

- **File**: `DUNEWatch/Views/Cardio/CardioMainMetricsPage.swift:178`
- **Category**: architecture / UX
- **Issue**: 앞선 두 실행에서 막대가 페이지 표시점과 겹쳤으며 최종 한 줄 행 보정은 native 미검증이었다.
- **Status**: Resolved. 사용자 추가1회 승인 뒤 관련3개 UI 모두 통과. 주 에이전트와 독립 최종 리뷰어가 새 C01·C02 원본 PNG의 간격과 레벨·거리/페이스·심박·존·칼로리 가독성을 확인했다.

## P3 Findings (Consider)

없음.

## Positive Observations

- 주 에이전트가 2000줄 초과 diff를 보안·성능·구조·데이터·단순성5관점과 localization 기준으로 직접 리뷰했다. agent-native는 관련 지침 변경이 없어 제외했다.
- 별도 최종 PR 리뷰어가 통합/크래시/데이터와 SwiftUI·Apple UX·UI 계약을 읽기 전용 검토했고 새 결함은 없었다.
- 저장된 값·단위·순서가 보존되고 혼합 문장은 전체 원문으로 표시한다. 새 로컬라이즈 키 없이 기존 en 원문·ko/ja 번역을 사용한다. 카탈로그 포맷/manual 검사와 테마맵 동기화도 통과했다.

## Checks and Limits

문장 분리 unit5, 알림 최종 iPhone3·iPad1·Duo 접힘1 통과 증거를 소스 동등성 확인 후 재사용했다. 이전 일반 본문 기본1건의 개별 통과도 분리 기록했다. 이번 추가 Watch 실행은 러닝6존·계단6존·계단 심박 미수신3/3, skip0·실패0이다.

Duo 펼침 T12는 실제 활성 화면 전환이 확인되지 않은 디자인맵 산출물 공백으로 남는다. 기존 PNG를 새 증거로 표시하지 않는다. Watch 큰 글씨·AOD·VoiceOver와 전체 회귀는 검증하지 않았다. 이 한계를 UI/실제맵 전체 완료로 확대하지 않는다.

## Next Steps

- [x] 이전 P1/P2를 현재 변경에서 다시 확인: Open 없음.
- [x] 관련 UI·실제 캡처와 출처 확인.
- [ ] 검토 범위만 PR 생성·원격 머지·소유 자원 정리.
