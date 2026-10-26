---
topic: sleep-debt-and-card-navigation
date: 2026-10-26
status: approved
confidence: high
related_solutions: [docs/solutions/design/hero-cta-button-pattern.md]
---

# Implementation Plan: 수면 부채 도식과 메인 카드 상세 진입 통일

## Context

Today의 수면 부채는 제목과 시간만 나열되어 최근 수면과 구분하기 어렵다. 네 메인 탭의 상세 링크는 상단·하단 및 화살표 종류가 달라 같은 행동을 찾기 어렵다. 사용자가 네 탭 전체에 제목 바로 옆 chevron과 헤더 전체 터치를 승인했다.

## Requirements

- 수면 부채에 기존 상세와 같은 0–10시간 척도의 40pt 링을 추가한다. 정확한 시간은 유지하고 0분은 체크 아이콘으로 구분한다.
- 상세 화면이 있는 카드 헤더는 제목과 `chevron.right`를 가까이 둔다. 중복 상세 문구·하단 CTA는 제거한다.
- 독립 헤더의 터치 높이는 최소 44pt이고 눌림 피드백을 제공한다. 카드 전체가 이미 링크면 새로운 링크를 중첩하지 않는다.
- 목적지·상태·데이터 계산은 유지한다. 추가/입력/닫기/정보 버튼은 해당 동작을 유지한다.
- 큰 글씨·긴 번역·데이터 없음·복수 목적지에서도 잘림과 중첩 제스처를 방지한다.

## Approach

공통 `CardNavigationHeader`가 제목·가까운 chevron·나머지 너비를 포함하는 레이블을 제공하고, 실제 NavigationLink/Button과 목적지는 소비자가 소유한다. SectionGroup은 정보 버튼을 독립시킨 채 헤더에 실제 목적지를 연결한다. 수면 링은 기존 ProgressRingView를 재사용한다.

| Alternative | Assessment |
|---|---|
| 오른쪽 끝 상세 텍스트 유지 | 현재 이격과 문구 중복을 해소하지 못해 제외 |
| 카드 전체를 새 버튼으로 감싸기 | 차트·정보·입력 버튼의 중첩을 유발하므로 기존 전체 링크만 유지 |
| 제목 옆 chevron + 헤더 링크 | 사용자가 선택한 배치. 각 상세의 실제 목적지를 유지 |

## Affected Files

| Scope | Change |
|---|---|
| Dashboard components | 수면 링, 컨디션·수면·스트레스·브리핑 진입 헤더 |
| Shared components | 공통 헤더/눌림 스타일, SectionGroup 헤더 진입 지원 |
| Activity, Wellness, Life | 상세 CTA를 헤더로 옮기고 중복 제거 |
| DUNEUITests | 카드 헤더의 넓은 터치 영역과 기존 목적지 검증 |
| Design maps | 배치 계약, T03/A01/H01/L01 및 새 실제 캡처 출처 |

## Implementation Steps

1. 공통 헤더와 수면 링을 구현한다. 목적지가 없는 헤더에는 chevron을 표시하지 않는다.
2. Today와 나머지 세 탭의 실제 상세 카드를 전환한다. 별도 목적지가 있는 카드 하위 섹션은 각각 헤더를 제공한다.
3. 변경한 헤더의 진입 경로와 수면 표시를 targeted UI로 검증한다. 현재 실행을 중복 시작하지 않으며 전용 시뮬레이터와 deadline을 유지한다.
4. 새 PNG를 확인하고 디자인맵에 보존한다. 미촬영 기기·상태는 기존 PNG와 구분한다.

## Edge Cases

| Case | Handling |
|---|---|
| 부채 0 / 10시간 초과 | 시간 원본 유지, 0은 체크·링만 최대치 제한 |
| 분석 불충분 / 유효하지 않은 값 | 기존 표시 조건 유지 |
| 접근성 글씨 | 제목 줄바꿈 및 실제 높이 확장, 44pt는 최소치 |
| 정보 버튼을 가진 섹션 | 헤더 링크 밖 별도 형제로 유지 |
| 하나의 카드에 복수 목적지 | 기존 목적지별 제목/하위 헤더 링크 유지 |

## Testing Strategy

단순 View의 기존 계산은 새 유닛 테스트를 만들지 않는다. 관련 Today·Activity·Wellness·Life UI에서 레이블, 터치 영역, 목적지를 검증하고 캡처를 육안 확인한다. 전체 회귀는 실행하지 않는다. UI 빌드가 앱 빌드도 확인하며 새 파일 등록은 표준 실행기의 프로젝트 재생성을 사용한다.

## Risks

중첩 버튼, 기존 접근성 식별자 소실, 정보 버튼의 잘못된 목적지 전파가 주요 위험이다. 실제 링크에 식별자를 유지하고 정보/보조 동작을 분리한다.

## Confidence Assessment

High. 사용자 선택과 기존 목적지가 명확하며 공통 변경을 표현 레이어로 한정할 수 있다.
