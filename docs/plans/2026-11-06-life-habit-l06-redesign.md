---
tags: [detail-redesign, habits, targeted-ui, l06]
date: 2026-11-06
category: plan
status: implemented
---

# L06 · 관리에서 연 습관 기록

## Affected Files

| 파일 | 변경 |
|---|---|
| `DUNE/Presentation/Life/HabitManagementView.swift` | 원래 상태·계산·아이콘에서 시각 위계를 보강한다. |
| `DUNEUITests/Full/LifeRegressionTests.swift` | `testVisualAuditHabitManagement`와 공유 History MAX 검사로 관리에서 연 이력의 이름·동작·값·날짜, 시트 Close 및 관리 화면 복귀를 확인한다. |
| `docs/design/layout-map/life-habit-l06.html` | 앱 변경 전에 배치를 보존한다. |
| `docs/design/theme-map/themes/dune-life-habit-l06.html` | 테마 표현 시안이며 실제 캡처와 구분한다. |

## Implementation Steps

1. 공유 [묶음 계획](2026-11-06-detail-redesign-habit-analytics-batch04.md)의 원본 파일 SHA와 호출부·기능·데이터 불변식을 확인한다.
2. 이 화면의 App 변경만 별도 로컬 커밋하고 공통 UI 검사와 관련 소비자를 독립 리뷰한다.
3. 공유 SDK 실행에서 해당 화면 메서드·기기만 채택하고 실제 PNG·AX를 독립 검토한다. 그 후 실제 디자인맵·해결 문서를 갱신해 화면별 PR을 발행한다.

## Testing Strategy and Risks

이 화면은 관리 화면에서 여는 medium/large 기록 시트다. iPhone·iPad·Duo 접힘·펼침 기본 글씨와 접힌 Duo MAX에서 원래 아이콘·이름·History, 실제 로그 동작·값·날짜와 Close가 스크롤로 읽히는지 확인한다. cachedLogSnapshots·sortedEntries와 관리의 기존 Restore·Back 동작은 유지했다. L05의 빈 상태 검사를 이 화면의 검사로 합산하지 않는다. 고정 소스 `83c350b0`의 화면별 5개 메서드·기기 기여와 PNG·AX 5쌍이 통과했고 PR #936으로 머지했다. Open L06은 원래 실패 기록을 보존하고 동일 소스·300초 한도의 단독 검사에서 127.365초에 통과했으며 앱 수정으로 해결했다고 주장하지 않는다.

## 실제 선택 화면 검증

[L06 PNG·AX·출처](../design/full-redesign-map/review/l06-habit-history-detail-2026-11-06/index.html). PR/CI 상태는 별도 기록을 따른다.
