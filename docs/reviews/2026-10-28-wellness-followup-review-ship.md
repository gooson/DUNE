---
tags: [review, wellness, today, ship]
date: 2026-10-28
category: review
status: reviewed
---

# Wellness 후속 피드백 통합 리뷰

> Date: 2026-10-28
> Scope: 희소 수면 막대, 오늘 밤 수면 시각화, Today 지표 표현·동일 행 높이
> Files reviewed: 106개 (앱·테스트·시안·실제 캡처·증거 문서 포함)

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | 없음 |
| P2 | 1 | Resolved |
| P3 | 0 | 없음 |

2969줄 diff이므로 source skill 예외에 따라 parent가 폴더별 5관점을 직접 검토했다. Agent-Native는 지침 변경이 없어 생략했다. [읽기 전용 리뷰 원본](2026-10-28-wellness-followup/findings-before-resolve.json)은 수정 전 HEAD `2eebefa9` 기준이다. 원격 main의 별도 문자열 변경은 이번 작업에 포함하지 않고 보존한다.

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Data Integrity] 과거 기록 변경이 그래프를 갱신하지 못함

- **File**: `DUNE/Presentation/Shared/Models/VitalCardData.swift:68`
- **Category**: data
- **Issue**: 새 Today 그래프는 과거 기록을 사용하지만 DTO의 equality가 sparklineData를 비교하지 않는다. 최신 값·시각이 같으면 Observation의 배열 대입 알림이 생략될 수 있다. 같은 조건의 축소 Swift 재현은 알림 0회였다.
- **Suggestion**: equality/hash에 시계열을 포함하고 실제 Observation 갱신을 회귀 검증한다.

## P3 Findings (Consider)

없음. 같은 행의 자연 높이를 맞추면서 짧은 체중 카드 하단에 생기는 여백은 승인된 배치 계약이다.

## Positive Observations

- Security: 새 외부 전송·권한·비밀이 없고 시각 캡처 fixture는 UI testing 진입으로 한정된다.
- Performance: 한 행 2개 Layout, 제한된 기존 기록을 사용하며 새 HealthKit 쿼리가 없다.
- Architecture: 공통 테마 토큰과 기존 navigation 목적지를 유지하고 도메인 계산을 View에 넣지 않았다.
- Data: 수면 누락일은 빈 슬롯, 체중 단일 관측은 빈 추세로 표현한다. 예측 점수와 신뢰도를 구분한다.
- Simplicity: 광범위한 그리드 추상화 대신 Today 행 높이만 다루는 작은 Layout을 사용한다.
- L10N: 사용자 문자열의 LocalizedStringKey/String(localized:) 경로와 기존 en/ko/ja 키를 확인했다.
- 기존 Astra 검토·iPhone/iPad 실제 캡처는 각 갤러리에 보존했다. 최대 글씨·희소 기록·0/100·nil 예측 검증을 전체 UI 통과로 확대하지 않는다.

## Next Steps

- [x] P2 수정 및 회귀 검증
- [x] 현재 diff 기준 findings 재조정
- [x] 독립 최종 PR 리뷰
- [ ] GitHub PR merge 및 소유 기기 정리

## Resolve와 최종 검증

`72dc049d`에서 equality/hash에 sparklineData를 포함했다. 최신 값·날짜가 같은 두 카드의 과거 값만 다르게 한 실제 Observation 회귀가 변경 알림1회와 Set 계약을 확인했다. 기존 추세 순서·단일 관측 검사와 함께 **3개 단위가 통과**했다. canonical DUNETests build-for-testing와 generic iOS 앱 빌드가 통과했다. 표준 unit script에 selector가 없어 이미 확인한 exact-identifier test-without-building 경로를 기존 simulator lock·180초/무출력90초 deadline 안에서 사용했다. runner는 수정하지 않았다.

`240ecde3`에서 원격 main `8a89b34e`의 별도 문자열 변경을 병합했다. 병합 후 문자열 formatter check를 다시 통과했고, 최종 UI build가 통합 상태를 컴파일했다. 테마 맵 동기화와 diff 공백 검사도 통과했다. 모든 P1/P2를 현재 소스에서 재확인했으며 Open은0개다.

| 최종 관련 UI | 최초 실행 | 조건부 재실행 |
|---|---|---|
| Today equal row geometry·비교 없음·체중 상세, 밝음/어두움 | 통과 | 재실행 없음 |
| Wellness 신체4지표·헤더 가장자리 상세 | 실패 | 해당 메서드1개 통과 |

최초 body 실패는 Add Body Record로 내려간 후 헤더를 기본 up 방향으로 다시 찾는 테스트였다. 실패 hierarchy의 헤더 y=-414.3과 실제 실패 PNG를 확인한 뒤 최종 reveal에 `.down` 한 줄만 지정했다. 앱·공유 helper·실행기는 그대로다. 재실행은 해당 메서드1개뿐이며 정상 종료했다. 최초 receipt의 2 executed/1 passed/1 failed를 성공으로 덮어쓰지 않는다. 최종 고유 selector2개 각각의 성공이며 한 번의 일괄 실행 성공은 아니다.

[최종 새 Today4장·실패/재실행 증거](../design/full-redesign-map/review/wellness-followup-ship-2026-10-28/index.html), [독립 PR 리뷰](2026-10-28-wellness-followup/pr-review.md), [최종 findings](2026-10-28-wellness-followup/findings.json)를 보존했다.

## Proof Ledger와 제한

자동 판정기는 shared DTO·fixture·미매핑 HTML/PNG에 iOS/watch full fallback을 냈다. 최신 adapter는 full을 명시적으로 요청한 경우에만 전체 실행하도록 규정한다. 호출부 검색상 VitalCardData는 iOS Dashboard/Wellness가 사용하며 Watch 소비자는 없다. 이에 iPhone의 영향받는 두 selector와 실제 Observation 단위 회귀를 실행했다. 변경하지 않은 수면 요약·예측 컴포넌트는 각 이전 갤러리의 소스/기기/상태 증거로 보존하며 최종 HEAD에서 새로 수행했다고 표시하지 않는다.

전체 UI 회귀·Duo 접힘/펼침, 이번 equality-only delta의 iPad/최대 글씨와 실제 VoiceOver는 미검증이다. 기존 Today 작업의 전체 단위는 무관한 AI Q&A 평가 실패와 다음 평가 idle timeout으로 끝났으므로 전체 단위 통과가 아니다. 임시 계획의0건 시도도 통과에서 제외되어 있다. 해당 미검증 상태를 전체 통과로 확대하지 않는다.

## 독립 최종 PR 게이트

gpt-6-sol medium이 base origin/main·앱 HEAD240ecde3의 Swift 변경11개·호출부·도메인·테스트·기존 en/ko/ja 키와 앞선 리뷰를 읽기 전용으로 확인했다. test-only 스크롤1줄 delta와 실제 최초/재실행 receipt도 별도 확인했다. 새 P1/P2/P3 없음, data-001 Resolved. 이후 문서·새 PNG·로그 보존 외 앱 변경은 없다. 이 문서의 Ship 항목은 원격 merge 확인 후 사용자 결과에서 별도로 보고한다.
