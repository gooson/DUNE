---
tags: [swiftui, hero-card, recorded-history, readiness, habit-completion, missing-data, dynamic-type, design-map]
category: architecture
date: 2026-10-25
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Presentation/Activity/Components/ReadinessHeroEvidenceView.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Shared/Models/WeeklyHeroTrendPoint.swift
  - DUNE/Presentation/Shared/Components/WeeklyHeroTrendView.swift
related_solutions:
  - docs/solutions/architecture/2026-10-17-honest-hero-trends-and-capture.md
  - docs/solutions/general/2026-10-22-contextual-first-fold-hero.md
---

# Solution: Activity·Life 히어로에 구성 근거와 실제 기록 흐름 추가

## Problem

### Symptoms

Activity와 Life는 큰 링과 한 줄 설명만 있어 다른 탭보다 정보 밀도가 낮았다. 점수의 근거나 최근 기록을 확인하려면 아래 카드 또는 상세로 이동해야 했다.

### Root Cause

현재 상태를 보여주는 링에만 표현이 집중되어 있었다. 준비도 상세의 과거 값은 근사 산식이라 현재 점수 이력으로 재사용하기 부적절하고, 습관의 과거 대상 수는 저장되어 있지 않아 과거 `완료/대상` 비율을 그대로 만들 수 없었다. 결측을 0으로 채우거나 고정 분모를 사용하면 보기 좋은 그래프가 실제 기록의 의미를 바꾼다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| ActivityView·ReadinessHeroEvidenceView | 기존 124pt 링 아래 HRV·수면·회복 100점 구성 점수와 준비도 상세 행동 | 현재 점수의 근거와 실행 경로 연결 |
| ActivityViewModel·WeeklyHeroTrendPoint | 기존 ScoreRefreshService의 8일 rolling snapshot을 날짜별 최신 유효값 7개로 변환·캐시 | 저장된 관측 이력만 표시하고 DST 경계를 포함 |
| LifeView·LifeHeroTrend | 현재 완료·대상·남음과 수동 습관의 7일 완료 횟수 | 현재 주기 진행과 일별 완료 기록을 분리하고 과거 분모를 만들지 않음 |
| WeeklyHeroTrendView | 기본 글씨의 7열 막대와 큰 글씨의 날짜·값 목록, 결측 음성 레이블 | 작은 글씨로 압축하지 않고 스크롤로 정보 접근 보장 |
| TestDataSeeder·HeroRhythmUITests | opt-in 실제 기록 fixture, sparse·자동 연동 전용 상태·목적지·캡처 | 일반 seeded 데이터 의미를 바꾸지 않고 새 흐름 재현 |
| String Catalog·디자인맵 | en/ko/ja와 새 실제 PNG·출처 보존 | 시안과 구현 증거를 구분 |

### Key Code

```swift
// 과거는 저장된 값이며, 오늘은 현재 링 점수와 같은 기준이다.
if date == today {
    value = current.flatMap {
        $0.evaluationDate <= referenceDate
            && calendar.isDate($0.evaluationDate, inSameDayAs: referenceDate)
            ? $0.score : nil
    }
} else {
    value = latest[date].map { Int($0.value.rounded()) }
}
```

준비도 변환은 NaN·Infinity·0...100 범위 밖·미래·표시 기간 밖 표본을 제외한다. 같은 날짜의 유효 최신 표본을 사용하고 오늘의 오래된 current 값도 제외한다. 두 날짜 미만이면 추세 대신 데이터 부족 안내를 표시한다.

Life는 현재 active manual 습관만 집계한다. 기존 completionLogs 집계를 재사용하여 skip·snooze를 제외하고, auto-linked 습관·자동 완료·미래 기록·습관 생성 전 날짜를 제거한다. 수동 습관이 존재한 날짜의 0회와 생성 전 결측은 다르다. 자동 연동 습관만 있으면 수동 진행 0/0 대신 시작 안내를 표시한다.

## Verification

- 관련 단위 테스트 41/41 통과: 날짜·DST·최신값·결측·0·범위·수동 습관 완료 의미를 포함한다.
- 새 iPhone 히어로 10개 고유 시나리오, 기존 Life 설명 배치 1개(3상태), iPad 4개, Duo 외부 4개 통과. 밝음·어두움·iPhone 최대 AX·sparse·자동 연동 전용 실제 화면 23장을 보존했다.
- 다섯 관점·번역 직접 리뷰와 독립 app-quality-gate에서 P1/P2 없음. P3 catalog extraction 메타데이터를 수정하고 번역 값 동일성·formatter·수정 후 빌드를 확인했다. Activity 기존 머리말 링크와 하단 상세 링크 중복은 호환성을 위해 유지했다.
- 공통 Today 알림함 UI 2건 실패는 원인 미확정으로 보존했다. Duo 내부는 HID와 공식 회전 setter가 성공을 반환했으나 실제 readback은 portrait여서 가로 캡처를 시작하지 않았다. 숫자 힌지 각도도 현재 CLI에서 미검증이다. 사용자가 `통과 하고 계속`으로 이 한계를 기록한 진행을 승인했다. 실패 테스트를 통과로 변경하지 않았다.
- [실제 화면·출처·정확한 재개 조건](../../design/full-redesign-map/review/activity-life-hero-rhythm-2026-10-25/README.md), [리뷰](../../reviews/2026-10-25-activity-life-hero-review.md), [종합 품질](../../reviews/2026-10-25-activity-life-hero-quality.md).

## Prevention

### Checklist Addition

- [ ] 히어로 이력이 현재 점수와 같은 산식·관측 경로를 쓰는가?
- [ ] 과거 분모나 관측값을 UI를 채우기 위해 만들지 않았는가?
- [ ] 알려진 0과 결측이 구분되고 접근성 음성 의미도 맞는가?
- [ ] 큰 글씨에서 컨테이너 존재뿐 아니라 마지막 날짜·CTA까지 실제로 도달하는가?
- [ ] 원래 메뉴가 닫힌 상태의 하위 항목을 바로 조회하는 테스트가 없는가?
- [ ] 회전 setter의 성공 응답을 실제 방향·활성 화면·native viewport와 구분하는가?
- [ ] 재사용한 문자열의 extractionState와 번역 값이 현재 코드와 일치하는가?

### Rule Promotion Decision

기존 sparse trend, CTA 목적지, 실제 디자인맵, 입력 유효성·번역 규칙으로 다루는 패턴이다. 이번 사례는 이 해결책과 체크리스트에 보강하고 별도 전역 규칙·교정사항을 추가하지 않는다. `.claude/**` source of truth는 수정하지 않았다. 이 요청에 연결된 active TODO가 없어 done 이동 대상은 없다.

## Lessons Learned

정보 밀도를 높일 때는 장식보다 현재 값의 근거와 기록의 의미를 추가하는 것이 도움이 된다. 현재 주기 진행과 실제 일별 완료 횟수는 같은 숫자가 아니므로 레이블부터 구분해야 한다. 접근성 컨테이너가 존재한다는 검사만으로 긴 카드의 아래쪽 내용이 보이는지 알 수 없으며, 실제 마지막 행까지 이동한 PNG가 필요하다. 검증 환경이 막힌 부분은 성공 범위와 분리해 보존해야 이후 작업이 잘못된 완료 증거를 재사용하지 않는다.
