---
tags: [life, swiftui, workout-achievement, dynamic-type, design-map, bounded-progress]
category: general
date: 2026-10-29
severity: important
related_files:
  - DUNE/Presentation/Life/WorkoutAchievementBoard.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNETests/WorkoutAchievementBoardTests.swift
  - DUNEUITests/Visual/LifeFlowUITests.swift
related_solutions:
  - ../architecture/2026-03-04-life-tab-auto-workout-card-ux-ui.md
  - 2026-03-29-life-auto-achievement-healthkit-filter-bug.md
---

# Solution: Life 주간 운동 업적을 성과 보드로 전환

## Problem

디자인 개편 후에도 외곽 카드 안에 그룹별 카드와 가로 진행 막대를 반복해 기존 화면과 차이가 적었다. 사용자는 해당 영역만 시안을 요청한 뒤 **성과 보드**를 선택했다. 집계·목표 동작을 유지하면서 정보의 시각적 우선순위를 바꾸어야 했다.

### Root Cause

정보별로 다른 의미를 같은 카드/막대 패턴으로 표현했다. 완료 목표 수, 운동 횟수, 근력 부위별 진행, 러닝 거리를 구분하는 시각 언어가 부족했다. 시안의 고정 10개를 그대로 앱에 옮기면 사용자 목표 수가 달라질 때 잘못된 완료 표현을 만들 위험도 있었다.

## Solution

| File | Change | Reason |
|---|---|---|
| `WorkoutAchievementBoard.swift` | 큰 완료 수·장식 메달·횟수 분절·근력 타일·거리 곡선 | 서로 다른 지표를 구분하고 중첩 표면 제거 |
| `LifeView.swift` | 표시만 추출하고 기존 목표 메뉴 closure 전달 | 저장·수정·이력·보관·내비게이션 소유권 유지 |
| `WorkoutAchievementBoardTests.swift` | 가변 분모·누락 그룹·비정상 값·13개 목표 검증 | 장식이 데이터 의미를 바꾸지 않게 보호 |
| `LifeFlowUITests.swift` | seeded 메뉴/이력·접기·한국어·기기별 캡처 | 계산 통과와 실제 배치 검증을 구분 |

완료 수는 기존 완료 상태를 합산한다. 모든 근력 규칙을 표시하고 0회 항목도 보존한다. 목표가 12개를 넘으면 잘라낸 점 12개를 전부 채우는 대신 실제 완료/전체 비율의 `ProgressView`를 쓴다. 장식 메달은 보상 모델이 아니며 VoiceOver에서 제외한다.

```swift
static func strengthMarkCount(target: Double) -> Int {
    Int(min(3, safeValue(target)))
}
```

정수로 변환하기 **전에** 유한값·음수·상한을 처리한다. `Int(min(target, 3))` 뒤에 음수 방어를 넣으면 매우 큰 음수에서 먼저 trap이 발생할 수 있다.

최대 접근성 글씨는 장식을 숨기고 그룹 제목에 전체 폭을 준다. 완료 수는 다음 줄로 이동하며 근력 grid는 한 열까지 허용한다. 네이티브 캡처에서는 단순 `isHittable`만으로 제목 전체가 보인다고 판단하지 않고 실제 navigation/tab-bar viewport 안으로 위치를 맞춘다.

## Verification

최종 iOS 빌드와 관련 단위 **52개 / 3 suites**가 통과했다. iPhone 기본/어두움/한국어/최대 글씨·목표 이력·접기, iPad 및 Duo 기기별 세부 결과는 [실행 보고](../../reviews/2026-10-29-workout-achievement-board/README.md)를 따른다. 공통 smoke의 기존 Today 실패 3건은 관련 소스 diff와 이전 실행을 대조해 분리했다. targeted 성공을 전체 회귀 성공으로 확장하지 않는다.

## Prevention

- 장식 표식의 개수 제한이 실제 완료 비율을 바꾸지 않는지 확인한다.
- `Double` → `Int` 전에 유한값/하한/상한을 모두 제한한다.
- `isHittable`·AX 존재·PNG 시각 검토를 별개 증거로 기록한다.
- 브라우저 시안과 새 네이티브 원본을 구분하고, 기기 UDID·소스·테스트·해시를 함께 보존한다.
- 무관한 기존 실패는 기준 실행과 변경 경로를 확인하고 현재 작업의 검증 범위를 재확정한다.

기존 디자인맵·입력 방어·재시도 규칙으로 처리 가능해 새 전역 규칙/Correction Log는 추가하지 않았다. `.claude/**`는 변경하지 않는다. 해당 작업의 기존 TODO 파일은 검색 결과 없어 상태 변경 대상이 없다.

## Lessons Learned

시각적 변화는 색 교체보다 정보별 표현을 바꾸는 데서 커졌다. 기능 동작을 부모에 유지하면서 표시를 분리하면 디자인 교체 범위를 제한할 수 있다. 최대 글씨의 합격 여부는 일반 글씨나 계산 테스트로 대신 판단할 수 없다.
