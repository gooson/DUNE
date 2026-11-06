---
tags: [detail-redesign, habits, targeted-ui, l05]
date: 2026-11-06
category: plan
status: done
---

# L05 · 습관 이력

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/Presentation/Life/LifeView.swift` | 원래 상태·계산·아이콘에서 시각 위계를 보강한다. |
| `DUNEUITests/Full/LifeRegressionTests.swift` | `testHabitHistoryShowsSeededEntriesAndDismisses`와 해당 closed MAX 검사로 실제 읽기·기록·닫기/뒤로를 확인한다. |
| `docs/design/layout-map/life-habit-l05.html` | 앱 변경 전에 배치를 보존한다. |
| `docs/design/theme-map/themes/dune-life-habit-l05.html` | 테마 표현 시안이며 실제 캡처와 구분한다. |

## Implementation Steps

1. 공유 [묶음 계획](2026-11-06-detail-redesign-habit-analytics-batch04.md)의 원본 파일 SHA와 호출부·기능·데이터 불변식을 확인한다.
2. 이 화면의 App 변경만 별도 로컬 커밋하고 공통 UI 검사와 관련 소비자를 독립 리뷰한다.
3. 공유 SDK 실행에서 해당 화면 메서드·기기만 채택하고 실제 PNG·AX를 독립 검토한다. 그 후 실제 디자인맵·해결 문서를 갱신해 화면별 PR을 발행한다.

## Testing Strategy and Risks

네 기본 프로필과 접힌 Duo MAX에서 기존 닫기/뒤로·스크롤·리프 텍스트·아이콘·실제 수치를 확인한다. L05 빈 기록은 iPhone의 기존 empty selector를 한 번 추가한다. 헤더가 medium sheet의 모든 공간을 차지하지 않도록 한 스크롤 영역에 두며, MAX의 행·닫기·범례 접근을 직접 확인한다. 기존 정렬·필터·날짜·합계·비율·저장·권한을 변경하지 않는다. 아직 build·SDK·native 결과는 없다.

## 실제 선택 화면 검증

[L05 PNG·AX·출처](../design/full-redesign-map/review/l05-habit-history-2026-11-06/index.html). PR/CI 상태는 별도 기록을 따른다.
