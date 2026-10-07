---
tags: [iphone-duo, adaptive-layout, fitness, implementation]
date: 2026-09-20
category: plan
status: implemented
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

- [x] 1. D01–D03: Life 빈 상태 높이·시작 행동·집계 명확성.
- [x] 2. D04–D07, D12–D14: 접힘/비대칭 safe area/입력·모달/접근성 기반.
- [x] 3. F01/F02/F09 + D09: 운동 거치·이전 기록·좁은 창 대응.
- [x] 4. F05: 시간 기반 휴식 상태와 Live Activity 연속성.
- [x] 5. D08/D10/D11 + F03/F08/F11: Today/Wellness/Life 및 지도·자세 비교 경험.
- [x] 6. F04: 주간 계획 편집과 버튼 대안.
- [x] 7. F07/F06: 카메라 전환·양면 촬영 안내, 가용성 처리.
- [x] 8. F10: 기존 기록 창과 별도 읽기 전용 분석 scene. 새 분석 창에는 기록 시작 경로를 두지 않음.
- [x] 9. D15/F12: 동작 감소를 존중하는 브랜드 전환.
- [x] 10. 전체 회귀 검증·전문 관점 검토·solution 문서.

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

- 1단계: Xcode 27.1 Duo 시뮬레이터 빌드 성공. Life 빈 상태 추가/취소, 템플릿 열기/취소, seeded hero UI 테스트 3개 통과.
- 2–3단계: 적응형 pane, 비대칭 safe area를 사용하는 시스템 배치, 독립된 완료 버튼, 키보드 대응, 큰 글씨 수치 입력 구현. Duo에서 무게/횟수 변경 → 키보드 표시 → 세트 완료 → 저장 → 복귀 UI 테스트 통과. 운동 기록 목록/상세 inspector 닫기·재선택·이력 이동 UI도 통과. 선택은 최신 목록의 ID로 해석하며 삭제 시 해제.

- F05: 종료 시각 기준 타이머, 휴식 초안 호환 복원, 잠금 화면/Dynamic Island Live Activity 연결. Duo SDK 빌드 성공, 타이머/운동 세션 유닛 테스트 58개 통과. Live Activity 시각 및 외부 화면 실동작은 추가 확인 대상.

- Today 상세 열기·닫기·다시 열기·전체 데이터 이동, Life 습관 기록 상세/닫기 UI 검증 통과.
- 주간 계획: 날짜 키·교체·삭제·직렬화·달력 변경 단위 테스트 3개 통과. Duo 버튼 기반 템플릿 배정/제거 UI 통과.
- 지표 비교: 두 지표 동일 기간 및 기간 변경 동기화, 닫기 UI 통과. 수면은 분 단위로 표시하며 합성 누락 0값을 제외.
- 접근성: Duo와 iPad에서 최대 접근성 글씨 설정으로 두 시작 행동 접근 및 습관 추가/취소 UI 통과.
- 호환성: Xcode 27.1 Duo 빌드와 기존 Xcode 27.0 일반 iPhone 빌드 성공. 일반 iPhone Life 빈 상태/seeded UI 2개 통과, iPad seeded/최대 글씨 UI 2개 통과.
- 카메라: 촬영 중단·카운트다운 중단·결과/메모 보존 테스트 3개 통과. 오래된 카운트다운이 새 전환을 덮지 않는 추가 테스트도 최종 실행에서 통과.
- F10: 공유 저장소, 권한 준비 이후 조회, 수동 기록 변경·활성화·날짜·HealthKit 갱신 신호 반영. 추가 분석 창은 조회 전용. 새 창 전환의 실제 UI 검증은 미수행.
- D15/F12: 부분 접힘의 이산 상태에 따른 배경 채도 변화, Reduce Motion 적용. 입력/배치/차트 수치에는 영향을 주지 않음.
- SwiftUI/Apple UX 관점과 app-quality-gate 정적 검토 수행. 지적된 수면 누락/단위, 권한 준비/분석 갱신, 촬영 취소 generation, 종료 예정 Live Activity 재연결 문제를 수정.

- 최종 단위 테스트: 타이머, 운동 세션, 주간 계획, 카메라 전환, 주간 통계, 갱신 coordinator, 훈련량 분석 **7개 suite / 106개 테스트 통과**. 로그 `/tmp/dune-duo-final-units.log`.
- 운동 상세 최종 UI 통과: `/tmp/dune-duo-history-ui3.log`. 내부 화면 캡처로 목록/상세 병치를 확인.
- 최종 Duo SDK 빌드 성공. 주요 UI 로그: `/tmp/dune-duo-ui10.log`, 일반 iPhone `/tmp/dune-iphone-compat-ui.log`, iPad `/tmp/dune-ipad-compat-ui.log`.

## Remaining Device Validation

구현 완료와 출시 검증을 구분한다. 아래는 시뮬레이터·설치 환경에서 확인하지 못한 항목이다.

- iOS 26 실 런타임: 현재 설치되어 있지 않음. 기존 SDK 컴파일과 iPhone/iPad iOS 27.0 fallback은 검증.
- 물리적 부분 접힘/완전 펼침/외부 화면 전환을 반복하며 초안·선택·키보드·타이머 연속성 확인.
- 실기기 전면 카메라 전환, 외부 표시 촬영 안내, 이미지 회전/화질 및 완료 결과 보존.
- Live Activity 잠금 화면/Dynamic Island 표시·연장·종료, 장시간 백그라운드·프로세스 종료 후 복원.
- 여러 실제 창에서 기록과 분석의 동시 가시성, 창 복원 및 외부 화면의 시스템 지원 상태.
- 배경 효과의 실기기 전력·프레임 성능과 VoiceOver 탐색 순서.

주간 계획은 현재 기기 내 저장이며, 새 분석 창 외 기존 앱 주 창 여러 개의 중복 기록 정책을 확장한 것은 아니다.
