# A14 근육 피로 설명 개편

## 범위
A14는 MuscleDetailPopover의 실제 CompoundFatigueScore를 받는 FatigueInfoSheet다. A15 FatigueAlgorithmSheet는 별개다. 14일 운동별 원·감쇠 부하/소계, 수면·생체 계수와 기본값 조건, 실제 최종 점수·단계·시간상수, 원래 범례 및 시트 닫기를 유지한다. 임의 수치·공식을 추가하지 않는다.

## 구현
불투명 테마 히어로와 아이콘 표제, 실제 기여 행을 접근성 글씨에서도 정렬한다. 조건부 빈 상태 및 실제 수치와 원래 접근성 식별자를 보존한다. UI 테스트는 기존 Activity 경로의 실제 계수·결과 범위, 화면 내 가시성과 시트 닫기를 확인하도록 준비한다. A03 인라인 진입은 기존 공유 경로 검사를 별도 증거로 확인한다.

## 검증 계획
디자인맵 생성기/정적 diff 및 source review 후 정확한 원래 ActivityExerciseRegressionTests/testVisualAuditMuscleFatigueExplanation과 기존 fatigue regression을 필요 범위로 수행한다. Phone/iPad/Duo 접힘·펼침과 MAX는 별도 전용 기기로 수집한다. 현재 source 준비 단계에서는 build·device·UI test를 실행하지 않는다. 원본 캡처와 변경 후 캡처를 혼동하지 않는다.

## 위험
긴 운동명·기여값 줄바꿈, 최대 글씨의 스크롤 가시성, neutral 계수 조건, 실제 근육별 값은 네이티브 검증이 필요하다.

## 후속 검토 수정
중립 계수 1.00은 데이터 부재와 측정된 정상값 모두 가능하므로 출처를 추측하지 않는 설명을 사용한다. 어두운 히어로의 단계 텍스트는 고대비 잉크를 사용하고 원래 단계색은 장식 점으로 남긴다. 실제 경계·기여 행·두 진입 경로와 MAX 가독성은 기기 검사 전 미검증이다.

## 실제 A13 통합 뒤 검증 범위

2026-11-04 검증 준비는 실제 A13 머지 `d12b22848e8f00918d5727c7f961f1f8a7b08f9f`를 통합한 소스에서 시작한다. A13의 공유 sheet/inline 구조와 이름 있는 pane 및 원래 grabber 판정을 보존한다. 계산 버튼은 실제 부모 scroll 안에서 짧은 방향 drag와 전체 frame·hittability 검증 뒤 누른다. 원래 A14 수치·반올림 허용·기여 감쇠·소계/12·96시간 τ 계약은 유지하고, 각 확인 지점의 실제 PNG/AX를 수집한다.

필요한 실행은 일반 iPhone·iPad·Duo 접힘·펼침의 원래 normal 사례 네 개, 접힌 Duo의 명시적 dark Accessibility XXXL 사례 한 개, 같은 iPad에서 기존 A03 인라인 경로로 새 A14 자식의 실제 값과 원래 닫기·Back을 확인하는 사례 한 개다. 합계 여섯 사례이며 source 준비 시점에는 아직 네이티브 통과를 주장하지 않는다. 시뮬레이터는 소유 기기 하나씩만 만들고 성공·실패 결과를 보존한 뒤 삭제한다. 전체 회귀와 관련 없는 Watch 검사는 추가하지 않는다.
