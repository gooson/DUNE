# A14 근육 피로 설명 개편

## 범위
A14는 MuscleDetailPopover의 실제 CompoundFatigueScore를 받는 FatigueInfoSheet다. A15 FatigueAlgorithmSheet는 별개다. 14일 운동별 원·감쇠 부하/소계, 수면·생체 계수와 기본값 조건, 실제 최종 점수·단계·시간상수, 원래 범례 및 시트 닫기를 유지한다. 임의 수치·공식을 추가하지 않는다.

## 구현
불투명 테마 히어로와 아이콘 표제, 실제 기여 행을 접근성 글씨에서도 정렬한다. 조건부 빈 상태 및 실제 수치와 원래 접근성 식별자를 보존한다. UI 테스트는 기존 A14 경로에서 섹션·실제 값·닫기 동작을 관찰한다.

## 검증 계획
디자인맵 생성기/정적 diff 및 source review 후 정확한 원래 ActivityExerciseRegressionTests/testVisualAuditMuscleFatigueExplanation과 기존 fatigue regression을 필요 범위로 수행한다. Phone/iPad/Duo 접힘·펼침과 MAX는 별도 전용 기기로 수집한다. 현재 source 준비 단계에서는 build·device·UI test를 실행하지 않는다. 원본 캡처와 변경 후 캡처를 혼동하지 않는다.

## 위험
긴 운동명·기여값 줄바꿈, 최대 글씨의 스크롤 가시성, neutral 계수 조건, 실제 근육별 값은 네이티브 검증이 필요하다.
