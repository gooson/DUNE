---
tags: [swiftui, today, information-hierarchy, dynamic-type, shared-component, sleep]
category: general
date: 2026-10-25
severity: important
status: implemented-validation-partial
related_files:
  - DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift
  - DUNE/Presentation/Dashboard/Components/CumulativeStressCard.swift
  - DUNE/Presentation/Dashboard/Components/DailyDigestCard.swift
  - DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift
related_solutions:
  - ../architecture/2026-04-05-cumulative-stress-detail-view.md
  - 2026-03-30-sleep-card-redundant-unit.md
---

# Today 하단 카드의 읽기 위계와 공유 소비자 정리

## Problem

회복·수면, 장기 스트레스, 일간 요약에서 수치와 설명이 비슷한 크기로 나열돼 밀도가 높았다. 작은 수면 부족 링이 수면 시간처럼 보였고, 기술적 근거와 요약 원문이 항상 노출됐다. 스트레스 카드 전체가 링크여서 근거 펼침을 추가하면 탐색 행동과 경쟁했다.

## Solution

기존 `StandardCard`·색·서체·간격 토큰으로 V2를 구현했다. 수면 시간과 날짜를 먼저, 수면 부족을 별도 행으로 표시한다. 그래프는 유효한 실제 표본 최대7개와 기간·시간 단위를 사용한다. 상단 눈금이 잘리지 않도록 글씨 크기에 따라 plot 끝 여백을 늘린다.

스트레스는 점수·상태를 먼저 두고 근거를 native DisclosureGroup으로 펼친다. 상세 링크는 별개 행동이다. 실제 모델이 엄밀한30일 분석이 아니므로 기간 문구는 최근 기록 기준으로 바꿨다. 일간 요약은 날짜·컨디션·걸음 수와 원문 펼침으로 나눴다. 큰 글씨에서는 주요 행을 세로로 배치한다.

공유 카드의 다른 소비자 T10도 확인했다. 카드가 컨디션·걸음을 표시하므로 알림 상세의 중복 grid를 제거하고 수면만 보충한다. 수면 시간은 기존 `hoursMinutesFormatted`로 현지화한다. 불충분 수면 분석이 반환한 수면 부채0과 단독 변화량은 실제 기록의 존재 근거에서 제외한다.

```swift
return metrics.conditionScore != nil || metrics.workoutSummary != nil
    || (metrics.sleepMinutes.map { $0.isFinite && $0 > 0 } ?? false)
    || metrics.stepsCount != nil || metrics.stressLevel != nil
```

HealthKit 조회·저장·모델·점수 계산은 변경하지 않았다. 기존 요약 생성기의 어제 운동 재사용과 스트레스의 대리 지표 계산은 별도 한계로 남긴다.

## Verification and limits

44018fcc에서 iPhone 전용 UI7/7, 최종 카드 배치의 밝음·어두움·최대 글씨 캡처를 확인했다. 초기 공통 검사는36건 중34건 통과했고, 변경되지 않은 알림함2건은 자동 Morning Briefing 시트가 앞에 있어 실패했다. 해당 실패를 이번 변경의 성공으로 취급하지 않았다.

후속14d37e32의 P2수정은 구조·데이터 리뷰에서 해결로 확인했고 표준 iOS빌드도 통과했다. 수정 후 T10의 강화된 중복 방지 검사는 시뮬레이터 점유 해제 후 실행해야 한다. iPad는 잠금60초 대기에서 첫 실행과 허용된 재시도가 모두 시작 전에 종료됐다. 같은 실행을 더 재시도하지 않는다. Duo 두 자세도 미실행이다. 미캡처 T03/T10과 재개 조건은 [실제 화면 갤러리](../../design/full-redesign-map/review/today-reading-v2-2026-10-25/README.md)에 명시했다.

## Prevention

- 공용 카드의 정보량을 바꾸면 모든 소비자의 추가 지표·배치와 중복을 함께 확인한다.
- 분석 기본값과 관측값을 구분한다. 파생 부채0만으로 기록 존재를 판단하지 않는다.
- 차트 clipping을 유지할 때는 상단·하단 눈금 여백을 글씨 크기에 맞추고 실제 PNG로 확인한다.
- 방향 시안, 실제 앱 캡처, 실행 테스트의 범위를 각각 기록한다. 다른 기기의 증거로 확대하지 않는다.

## Lessons Learned

시각적 밀도는 모든 글씨를 줄이기보다 수치·상태·근거의 순서를 나누면 개선된다. 근거를 접어도 원문과 상세 진입은 보존해야 한다. 공유 소비자의 중복은 요소 존재만 보는 UI테스트로 놓칠 수 있어 개수 검사를 추가했다. 네이티브 최대 글씨는 긴 세로 스크롤을 요구하므로 한 장의 viewport로 카드 전체를 검증했다고 주장하지 않는다.

새 전역 규칙이나 `.claude/**` 수정은 필요하지 않았다. 관련 활성 TODO가 없어 상태 변경은 없다.
