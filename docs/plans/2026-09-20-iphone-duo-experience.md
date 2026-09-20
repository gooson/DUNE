---
tags: [iphone-duo, adaptive-layout, fitness, implementation]
date: 2026-09-20
category: plan
status: draft
---

# iPhone Duo 경험 구현 계획

## Scope

사용자가 리서치의 디자인 15개(D01–D15), 기능 12개(F01–F12)를 순서대로 진행하도록 요청했다. 기능별 작은 구현·검증 단위로 진행한다. iOS 26 fallback을 유지하고 SDK 27.1 API는 설치된 선언으로 검증한다. 추정 효용은 완료 사실로 표현하지 않는다.

## Baseline

- 시작: detached HEAD. 작업 브랜치 `codex/iphone-duo-experience`.
- 기존 미추적 파일: `docs/brainstorms/2026-09-20-iphone-duo-experience-research.md` (이전 리서치 산출물, 자동 커밋 제외).
- Life의 regular HStack 두 열 모두 fillHeight, 빈 상태에 무한 높이 EmptyStateView. 상단 hero는 데이터 없음에도 0%와 0/0을 표시.
- 기존 TabView/NavigationStack/sidebarAdaptable, 자세 비교, 건강 QA, 운동 템플릿·주간 리포트를 재사용.

## Affected Files

| 영역 | 파일 / 디렉토리 | 변경 |
|---|---|---|
| Life | DUNE/Presentation/Life/LifeView.swift | 요약·빈 상태·집계·분석 연결 |
| 공통 레이아웃 | DUNE/Presentation/Shared/Components/ | 접근성·접힘·넓은 화면 컨테이너 |
| 운동 | DUNE/Presentation/Exercise/ | 거치 UI·이전 기록·세션 연속성 |
| Activity | DUNE/Presentation/Activity/ | 지도/운동·계획 동시 표시 |
| Dashboard/Wellness | DUNE/Presentation/Dashboard/, Wellness/ | 요약/차트·설명 비교 |
| 자세 | DUNE/Presentation/Posture/, DUNE/Data/Services/PostureCaptureService.swift | 비교·카메라 전환·양면 안내 |
| 앱/위젯 | DUNE/App/, DUNEWidget/, Shared/, DUNE/project.yml | Live Activity·scene·버전/회전 설정 |
| 번역 | Shared/Resources/Localizable.xcstrings | en/ko/ja |
| 검증 | DUNETests/, DUNEUITests/ | 로직 경계·UI 흐름·리사이즈 |

## Implementation Steps / Progress

- [ ] 1. D01–D03: Life 빈 상태 높이·시작 행동·집계 명확성.
- [ ] 2. D04–D07, D12–D14: 접힘/비대칭 safe area/입력·모달/접근성 기반.
- [ ] 3. F01/F02/F09 + D09: 운동 거치·이전 기록·좁은 창 대응.
- [ ] 4. F05: 시간 기반 휴식 상태와 Live Activity 연속성.
- [ ] 5. D08/D10/D11 + F03/F08/F11: Today/Wellness/Life 및 지도·자세 비교 경험.
- [ ] 6. F04: 주간 계획 편집과 버튼 대안.
- [ ] 7. F07/F06: 카메라 전환·양면 촬영 안내, 가용성 처리.
- [ ] 8. F10: 별도 scene의 기록·분석과 중복 세션 방지.
- [ ] 9. D15/F12: 동작 감소를 존중하는 브랜드 전환.
- [ ] 10. 전체 회귀 검증·전문 관점 검토·solution 문서.

각 단위는 변경 파일을 한정하고 검증 후 커밋한다. 실제 완료한 범위만 체크한다.

## Testing Strategy

- 표준 `scripts/build-ios.sh`를 DEVELOPER_DIR=Xcode27.1로 실행.
- 새 상태/시간 계산 로직의 유닛 테스트, 입력 경계/상태 복원 테스트.
- Life 빈 상태→추가→취소, seeded 상태, 운동 입력·완료 UI 테스트.
- Duo 내부/외부·회전·부분 접힘·좌/우 분할·키보드·큰 글씨 검증.
- 일반 iPhone/iPad와 iOS 26 fallback 회귀. 가용 런타임이 없으면 미검증으로 기록.
- 카메라 품질과 물리 접힘 터치·배터리는 실기기 검증 대상으로 구분.

## Edge Cases / Risks

빈 기록과 필터 결과 없음 구분; 0%를 미설정으로 오인하지 않게 하기; 초안/선택의 view identity 보존; 실제 측정 시각과 타이머 종료 시각 유지; 멀티 scene에서 쓰기 단일화; 카메라 세션/부가 화면 가용성 변화; beta SDK 변경; Dynamic Type·번역 길이.

## Validation Ledger

아직 구현·검증 완료한 항목 없음.
