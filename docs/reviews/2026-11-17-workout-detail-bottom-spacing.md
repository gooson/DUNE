---
tags: [review, run, workout-detail, spacing]
date: 2026-11-17
category: general
status: reviewed
---

# W28 하단 여백 /run 검증·리뷰

대상 기준 main `153982ec9`, 구현 커밋 `c900e7290`. 새 워크트리는 만들지 않고 primary checkout을 재사용했다.

| 관점 | 결과 |
|------|------|
| Security | P1/P2/P3=0, 입력·권한·민감 데이터 경로 변경 없음 |
| Performance | P1/P2/P3=0, 고정 padding과 AX 그룹만 추가 |
| Architecture | P1/P2/P3=0, 기존 DS 토큰과 root navigation 유지 |
| Data integrity | P1/P2/P3=0, HealthKit/SwiftData 읽기·쓰기 변경 없음 |
| Simplicity | P1/P2/P3=0, 새 추상화 없음 |
| Agent-native | skipped, AI·prompt·adapter 변경 없음 |
| SwiftUI | 초기 P2 테스트 결함 해결, 최종 P1/P2=0, P3 검증 한계 1 |
| Apple UX | 새 일반/MAX PNG 확인, 변경 여백의 P1/P2/P3=0 |
| UI testing | 시트·잘못된 header frame 대신 알림 push/카드 그룹/보이는 탭 검사 |
| perf-optimizer / app-quality-gate | skipped, 대량 처리·새 주요 기능 없음 |
| Localization | 새 사용자 문자열 없음, 전체 카탈로그 check/manual 통과 |

## Findings lifecycle

- P2 `spacing-test-false-positive`: **Resolved**. iPhone 하단 탭 바 존재·hittable·화면 하단 위치를 강제하고 실제 Other 카드 frame을 측정한다. 시트 경로를 사용하지 않는다. 최종 iPhone 두 검사 통과와 native PNG로 확인했다.
- P3 `last-zone-variant`: **Open, non-blocking**. 최종 fixture의 마지막 카드는 Weather다. 날씨 없는 마지막 심박 구간 카드·Duo·iPad 최대 글씨의 새 캡처는 미수행이다. 공통 VStack 끝 padding 구조로 기능 영향이 동일하며, 별도 fixture 추가·다른 화면 개편으로 이번 단순 마진 수정 범위를 넓히지 않았다.
- 기존 MAX Weather 줄바꿈은 이번 변경에서 발생한 finding으로 집계하지 않았다.

## Execution Summary

| Phase | 상태 | 증거 |
|-------|------|------|
| 0 Init | completed | main clean 확인, AGENTS·adapter·run·교정사항 읽음 |
| 1 Plan | completed | `docs/plans/2026-11-17-workout-detail-bottom-spacing.md` |
| 2 Work | completed | 구현·선택 UI 컴파일·커밋/push |
| 2.5 UI | completed | 최종 iPhone 2/2, iPad 1/1, skip0; 초기 실패·중단은 보존 |
| 3 Review | completed | 5개 코드 관점, Agent-native 면제 |
| 3.5 Quality | completed | SwiftUI·Apple UX·UI test 별도 관점, native PNG 확인 |
| 4 Resolve | completed | 초기 P2 해결, 최종 P1=0/P2=0/P3=1 |
| 5 Compound | completed | 해결 문서·W28 실제 갤러리·layout map 동기화 |
| 5.5 Pre-Ship | 별도 최종 응답 | clean·원격·diff 검증 후 진입 |
| 6 Ship | 별도 최종 응답 | PR 최종 리뷰·원격 머지·소유 simulator/cache 정리 |

자동 실행 원본: `.codex-checks/workout-bottom-logs/`, `.codex-checks/workout-bottom-xcresults/`, `.codex-checks/pipeline/`. 최종 선택 결과 JSON·소스 해시는 [실제 갤러리](../design/phone-design-map/actual/workout-bottom-spacing-2026-11-17/index.html)에 보존했다. 문서 추가로 전체 worktree fingerprint가 달라지는 것과 앱·테스트 소스의 검증 범위는 구분하며, 오래된 receipt를 수정하지 않았다.

기존 관련 TODO 파일은 없었다. 계획 문서를 implemented로 전환하며 별도 미완료 TODO를 남기지 않는다.

## Change Verification Guide

HealthKit에서 가져온 운동이 있는 상태에서 Activity → 최근 달리기 운동 → 맨 아래까지 스크롤한다. 마지막 심박 구간 또는 날씨 카드가 떠 있는 탭 바와 떨어져 보이는지 확인한다. 큰 글씨에서도 같은 순서로 검사한다. 알림의 운동 항목에서도 상세로 들어갈 수 있다. iPad에서는 상단 탭 배치를 유지하며 콘텐츠 끝에 여백이 생긴다.
