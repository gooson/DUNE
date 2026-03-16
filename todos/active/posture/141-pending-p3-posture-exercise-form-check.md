---
source: brainstorm/realtime-video-posture-analysis
priority: p3
status: pending
created: 2026-03-16
updated: 2026-03-16
---

# Phase 4B: 운동 폼 판정

## 설명

특정 운동 선택 후 실시간으로 폼을 판정하여 pass/caution/fail 피드백 제공.

## 주요 작업

1. **운동 폼 규칙 모델**
   - `Domain/Models/ExerciseFormRule.swift`
   - 운동별 체크포인트 정의 (관절 각도 범위, 정렬 기준)
   - 운동 phase 정의 (하강/최저점/상승)

2. **폼 분석 서비스**
   - `Domain/Services/ExerciseFormAnalyzer.swift`
   - 시계열 관절 데이터 → phase 자동 감지
   - phase별 체크포인트 판정
   - 순수 SIMD, Vision/UI 무의존

3. **초기 지원 운동**
   - Squat: 깊이(hip-knee 각도), 무릎 valgus, 허리 중립
   - Deadlift: 허리 굴곡, hip hinge 비율
   - Overhead Press: 팔 경로, 허리 과신전, lockout

4. **폼 체크 UI**
   - 운동 선택 → 폼 체크 모드 진입
   - 체크포인트별 실시간 상태 표시
   - 렙 자동 카운트

## 착수 조건

- Phase 4A 완료 (듀얼 파이프라인 안정)

## 검증 기준

- [ ] 스쿼트 phase 감지 정확도 > 90%
- [ ] 체크포인트 판정이 숙련자 기준 80% 일치
- [ ] 렙 자동 카운트 정확
- [ ] 운동 전환 시 규칙 즉시 교체
