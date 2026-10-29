---
tags: [cardio-atlas, passport, achievements, session-count, milestones, recomputation]
category: general
date: 2026-10-30
severity: minor
related_files:
  - DUNE/Domain/Models/CardioAtlasProgress.swift
  - DUNETests/CardioAtlasProgressTests.swift
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasProgressViews.swift
  - DUNE/App/TestDataSeeder.swift
  - DUNEUITests/Visual/CardioAtlasUITests.swift
related_solutions: []
---

# Solution: Passport 운동 횟수 업적을 100회마다 계속 제공

## Problem

### Symptoms

운동을 100회 넘게 해도 횟수 업적이 100회에서 끝났고, 횟수의 다음 목표도 사라졌다.

### Root Cause

거리·시간·횟수 업적을 하나의 고정 threshold 배열에서 계산했다. 횟수 배열은 `[1, 5, 10, 20, 50, 100]`으로 끝났고 다음 업적도 같은 배열에서만 선택했다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `CardioAtlasProgress.swift` | 기존 6개 횟수 기준 유지, 100 초과의 100 배수에서 추가 달성 생성, 다음 배수 계산 | 임의의 상한 없이 이어지는 업적과 다음 목표 |
| `CardioAtlasProgressTests.swift` | 횟수 경계·기존 ID/날짜·첫 달성·중복/종목 분리·과거 시점·삭제 검사 | 이력 재계산 계약 유지 |
| `CardioAtlasProgressViews.swift` | 달성/다음 목표의 안정적인 접근성 ID | 실제 화면 검사 |
| `TestDataSeeder.swift` | 명시적 UI 실행 인자에서만 350개 예시 기록 추가 | 기존 fixture와 실제 데이터에 영향 없이 후반 업적 재현 |
| `CardioAtlasUITests.swift` | 200/300 달성·다음 400·완료 복귀 검사와 새 PNG | CA04 상태 증거 |

### Key Code

```swift
if initialSessionCountThresholds.contains(count) || (count > 100 && count.isMultiple(of: 100)) {
    // 해당 세션을 첫 달성 기록으로 추가
}
let nextCountThreshold = initialSessionCountThresholds.first { $0 > count }.map(Double.init)
    ?? Double(count / 100 + 1) * 100
```

이미 정렬·중복 제거·현재 운동까지 제한한 같은 종목 세션을 순회하면서 해당 횟수에서 한 번만 달성시킨다. 횟수가 클수록 threshold 배열 전체를 매번 순회하는 방식을 피한다. 기존 ID·달성일·거리/시간 기준·Journey 목표는 유지한다. 저장 모델 변경이나 별도 마이그레이션은 필요 없다.

검증 결과와 새 원본은 [실제 화면 갤러리](../../design/full-redesign-map/review/cardio-count-milestones-2026-10-30/README.md)에 기록했다. Foundation 실제 소스 기준 단위 15개 정의/26개 사례가 통과했으며 전체 iOS 단위 스위트와 구분한다. 기기별 UI 결과와 미갱신 Duo 상태는 갤러리의 최신 영수증을 따른다.

## Prevention

- 초기 업적 목록의 마지막 값 이후에도 달성과 다음 목표가 이어지는지 경계 양쪽에서 검사한다.
- 자동으로 늘어나는 횟수 기준은 첫 달성 날짜·기존 ID·삭제 후 취소·과거 시점 제한을 함께 검사한다.
- 새 대량 UI 데이터는 opt-in fixture로 한정하고 기존 시나리오를 바꾸지 않는다.

## Lessons Learned

유한한 입문 단계와 반복되는 장기 목표를 같은 고정 배열로 제한하면 오래 사용한 사용자에게 다음 목표가 사라진다. 반복 기준은 실제 누적 횟수에서 계산하고 기존 이력 계약을 유지한다.
