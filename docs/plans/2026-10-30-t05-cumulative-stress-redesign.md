---
topic: t05-cumulative-stress-redesign
date: 2026-10-30
status: approved
confidence: high
related_solutions:
  - ../solutions/architecture/2026-04-05-cumulative-stress-detail-view.md
  - ../solutions/architecture/2026-10-30-condition-detail-redesign.md
  - ../solutions/architecture/2026-10-30-shared-score-history-contract.md
---

# Implementation Plan: T05 Cumulative Stress

## Context

사용자가 전체 상세 시안의 실제 앱 구현과 화면별 /run PR을 요청했다. L03/T04는 병합했고 공통 고정 가시 구간 계산 PR863도04c6437d에 병합·정리·재생성했다. T05의 카드 간격, 구성/계산 통합, 강조된 동일 히어로, 원래 아이콘과 기간 기능 보존을 반영한다. 원본 da96의534개 시안 변경은 보존한다. 새 계획은 기존2026-04-05 최초 구현 계획의 후속 개편이며 사용자 /run 권한에 따라 진행한다.

## Research

원본 detail-redesign-map manifest의 T05 proposal와 feature parity, 네이티브 T05 View/VM/모델/계산/조회·단위, T04의 실제 경계·AX 수정과 공유 helper를 대조했다. 기존 해결책/brainstorms/TODO도 검색했다. 별도 읽기 전용 조사3건은 /tmp/t05-native-research.md, /tmp/t05-window-plan-research.md, /tmp/t05-history-design.md에 보존했다. 앞의2건에 반환weight가 정규화됐다는 오류를 명시적으로 정정했다. 최신 소스상 weightedSum/availableTotalWeight만 최종 점수에서 정규화하고 contribution.weight는 기본40/35/25다.

새 framework API를 도입하지 않으며 기존 SwiftData/Calendar/SwiftUI 패턴을 재사용한다. Serena로 기존 링 심볼/프로젝트를 확인했고 Apple design reference의 크기 등급·Dynamic Type·SF Symbols·progressive disclosure 원칙을 적용한다. 시각 계약은 먼저 layout/theme에 보존한다.

## Requirements

- 도메인 스트레스 계산·저장 모델·탭 진입·현재 점수/상태/해석/가이드·원래3요인 아이콘/원점수/설명·4단계 범례를 보존한다.
- 동일 ScoreHeroPalette와104pt 링, 진한 표면·금빛 능선으로 T04/탭과 일관된 히어로. 큰 글씨에서는 숫자/상태를 세로로 전환한다. 상태의 의미/색은 유지한다.
- 카드 사이 명시적 간격, 요인별 아이콘·0–100 가로 막대, 현재 적용 비중. 유효한 사용 가능 weight만 표시에서 정규화하며 기본 모델 비중 설명과 구분한다. 잘못된 weight는 비중 미표시; 모델은 수정하지 않는다.
- D/W/M/6M/Y, 스크롤·선택·추세선·이전/다음·가시 날짜·평균/최저/최고/이전 비교·실제 하이라이트를 유지한다. 날짜는 통합 추세 카드에1번 표시한다. 스트레스 상승을 좋은 변화 색으로 표시하지 않는다.
- day는 실제 시간별 자료, week+ 통계는 원본 일평균. 긴 plot bucket을 통계의 표본으로 재사용하지 않는다. 한 고정 구간과 참조 시점, 이전 구간 reserve로 일관된 연속 이동/통계를 산출한다.
- 구성과 기존 전체4설명은 한 native DisclosureGroup에 통합한다. 이중 펼침을 만들지 않고 모든 설명을 보존한다.
- 로딩/실패/유효한 빈 기록을 구분한다. 취소/늦은 응답이 새 기간의 상태를 덮지 않는다. missing hour/day를0이나 현재 점수로 채우지 않는다.

## Approach / Alternatives

| Approach | Decision |
|---|---|
| UI만 바꾸고 달력 요약·2000개 제한 유지 | 보이는 구간과 통계가 다르고 최신 이력이 잘려 제외 |
| 전역 cap을30k로 올리기 | 물리적 중복 행 제한을 증명하지 못하고 다른 호출까지 바꿔 제외 |
| 새 저장 모델·범용 repository·background actor | 현재 기능에 과도해 제외; 실측 성능 문제 발생 시 후속 검토 |
| 전용 complete scalar 조회 + 최대31일 날짜 조각 | 채택. 기존 API 기본 cap 유지, 실패 전파, 취소/양보, 값만 반환 |

조회 범위는 공유 window.domain보다 한 가시 구간을 더 앞서 포함한다. week+는 첫 날 전체 bucket을 얻도록 조회 하한을 startOfDay로 내린다. 조각은 서로 겹치지 않는 [start,end), 단일 조각에는 행 cap을 넣지 않는다. 정상 시간별 밀도에 대한 시간 범위 제한이지 물리적 행 수/latency 보장은 아니다. 모든 조각을 성공한 뒤에만 결과를 게시한다. 각 논리 hour는 createdAt 최신 row, 동률이면 높은 score의 결정적 tie로 선택한다. createdAt은 다른 점수 갱신에도 바뀌므로 이 정책을 최신 스트레스 측정의 증명으로 표현하지 않는다. 중복 삭제/스키마 변경은 하지 않는다. DST 반복 시각은 절대 hour로 구분한다.

## Affected Files

| File | Change |
|---|---|
| Data/Services/ScoreRefreshService.swift | T05 전용 complete scalar stress history, 날짜 조각·취소·검증·중복 정책 |
| Dashboard/CumulativeStressDetailViewModel.swift | 고정 가시 구간·원본 통계·paging·loading/error·주기 경합 방지 |
| Dashboard/CumulativeStressDetailView.swift | 통합 추세·간격·요인 bar·단일 설명·반응형 배치 |
| Dashboard/Components/CumulativeStressDetailHeader.swift | 같은 팔레트/링·실제 상태/날짜 히어로 |
| Dashboard/Components/CumulativeStressLevelGuide.swift | 기존 단계 심볼·큰 글씨 세로 헤더 |
| Dashboard/Components/CumulativeStressExplainerSection.swift | 기존4설명 보존, embedded 기본값으로 원래 호출 계약 보존 |
| Shared/Extensions/CumulativeStressScore+View.swift | 표시 전용 실제 비중·방어·기본 비중과 구분 |
| DUNETests/ScoreRefreshServiceTests.swift / CumulativeStressDetailViewModelTests.swift / 표시 비중 테스트 | 데이터·경계·부족 요인·오염 값 회귀 |
| DUNEUITests/Full/CumulativeStressDetailRedesignTests.swift / App/TestDataSeeder.swift(필요한 opt-in fixture만) | 실제 진입·기간/통계·펼침·AX·기기 캡처 |
| Shared/Resources/Localizable.xcstrings, project.pbxproj, design maps, plan/review/solution | 번역/표준 regen/새 실제 캡처·출처·검증 |

## Implementation Steps

1. layout/theme 계약과 원본 T05 JSON 보존, 영향 상태·기기·테스트 계획 확정.
2. 독립 파일 소유권으로 service/테스트, VM/테스트, UI 테스트 구현을 위임하고 parent는 화면/문구/맵을 구현한다. agent는 빌드/시뮬레이터/커밋을 실행하지 않는다.
3. source 동결 후 format·표준 regen/build·변경 범위 판정·관련 단위와 선택 UI를 한 번씩 실행한다. 실패는 증거를 먼저 수집하고 실제 원인별 변화 후 최대1회 조건부 재시도한다.
4. 일반 iPhone/iPad/Duo 접힘·펼침 실제 T05 새 PNG와AX를 캡처하고 직접 확인한다. 추가 iPhone dark/큰 글씨 확인을 범위에 포함한다. 기존4장의 예전 PNG는 이전 비교로만 보존하고 출처443a32ca를 명시한다.
5. 필수 일반5관점/품질·Resolve·Compound·Pre-Ship·화면 PR 생성/최종 CI/병합/정리/표준 regen을 수행한다. 전체/full suite는 사용자 명시 요청이 없어 실행하지 않고 미검증으로 남긴다.

## Testing / Edge Cases

- 기존 domain 계산 테스트와 실제 in-memory SwiftData:2000개 초과+최신 sentinel, [start,end), 조각 경계1회, nil/0/오염 값, 동일 hour의 중복/createdAt/tie, 취소 시 partial 금지.
- VM: day 시간별 변화, week+ unequal hour count의 동일 day 가중, 6M/year 원본 일별 min/max/count, current/prior half-open, 최하 페이지 비교, 고정 길이/DST/월말, 빈 구간 clearing, 빠른 기간 변경/취소/실패 격리. 필요하면 deterministic race를 위한 작은 주입 closure만 추가한다.
- 표시:40/35/25, HRV+sleep53/47, HRV+activity62/38, HRV-only100; 원본 weight/score 불변. empty/all-zero/NaN/inf/negative/overflow는 비중없음. arbitrary future factor allocator는 추가하지 않는다.
- UI: Today 원래 stress 진입, 실제 현재 점수/요인 icon+score+bar+비중,5기간 선택/경계 이동/추세선, 하나의 계산 펼침과 모든 설명, 큰 글씨 화면 겹침·text clipping·44pt 조작,4기기 실제 배치.

## Risks / Confidence

MainActor fetch는 동기 구간이며 날짜 분할이 무제한 duplicate에 대한 성능 보장은 아니다. 성능 개선 수치를 주장하지 않는다. 중복 최신 정책은 표시의 conflict resolution이며 스트레스별 updatedAt이 아니다. 실제 스키마/계산은 보존한다. 서비스+VM 수정은 iOS 소비 범위와 다른 shared-target 포함 여부를 project.yml에서 재확인하고 필요한 compile 범위를 기록한다. 캡처·검증하지 못한 상태/테마는 완료로 표시하지 않는다.

Overall high on source contracts; runtime/UI 품질은 실제 검사 전까지 미검증이다.
