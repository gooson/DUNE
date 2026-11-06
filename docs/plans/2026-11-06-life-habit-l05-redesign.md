---
tags: [detail-redesign, habits, targeted-ui, l05]
date: 2026-11-06
category: plan
status: implemented
---

# L05 · 습관 이력

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/Presentation/Life/LifeView.swift` | 원래 상태·계산·아이콘에서 시각 위계를 보강한다. |
| `DUNEUITests/Full/LifeRegressionTests.swift` | `testHabitHistoryShowsSeededEntriesAndDismisses`·iPhone 빈 기록 검사와 L06에서 도입한 공유 History MAX 검사로 기록 수·행·날짜·Past Record·시트 Close를 확인한다. |
| `docs/design/layout-map/life-habit-l05.html` | 앱 변경 전에 배치를 보존한다. |
| `docs/design/theme-map/themes/dune-life-habit-l05.html` | 테마 표현 시안이며 실제 캡처와 구분한다. |

## Implementation Steps

1. 공유 [묶음 계획](2026-11-06-detail-redesign-habit-analytics-batch04.md)의 원본 파일 SHA와 호출부·기능·데이터 불변식을 확인한다.
2. 이 화면의 App 변경만 별도 로컬 커밋하고 공통 UI 검사와 관련 소비자를 독립 리뷰한다.
3. 공유 SDK 실행에서 해당 화면 메서드·기기만 채택하고 실제 PNG·AX를 독립 검토한다. 그 후 실제 디자인맵·해결 문서를 갱신해 화면별 PR을 발행한다.

## Testing Strategy and Risks

이 화면은 medium/large detents를 유지하는 기록 시트다. iPhone·iPad·Duo 접힘·펼침 기본 글씨와 접힌 Duo MAX에서 실제 습관 아이콘·이름·기록 수, 행의 동작·값·날짜, 조건부 Past Record와 Close를 확인한다. iPhone의 기존 빈 기록 selector를 한 번 추가했으며 모든 프로필에서 빈 상태를 반복하지 않았다. Hero와 기록·동작은 하나의 스크롤 안에서 읽힌다. 기록 조회·정렬·저장과 내비게이션은 원래 코드로 유지했다. 고정 소스 `83c350b0`의 화면별 6개 메서드·기기 기여와 PNG·AX 14쌍이 통과했고 PR #935로 머지했다.

## 실제 선택 화면 검증

[L05 PNG·AX·출처](../design/full-redesign-map/review/l05-habit-history-2026-11-06/index.html). PR/CI 상태는 별도 기록을 따른다.
