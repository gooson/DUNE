---
tags: [actual-screen, live-activity, watchos, indoor-place]
date: 2026-11-06
category: solution
status: implemented
---

# 운동 화면 개선 · 실제 캡처

[갤러리 열기](index.html) · [이미지별 출처](capture-index.json) · [Live Activity 여백 실측](live-activity-margins.json) · [검증 기록](../../../../reviews/2026-11-06-workout-surfaces.md)

새 네이티브 PNG 8장: 일반 iPhone의 시간/거리 우선 Live Activity, 실내 장소 핀, 기존 실외 경로와 40mm Watch의 C14·C15·C20·C21. 원본 PNG를 수정 없이 복사하고 SHA-256·기기·runtime·시각·결과 번들을 남겼다. Watch C14·C15는 기존 인덱스 이미지를 갱신하고 C20·C21는 새 상태로 추가했다.

iPhone UI 4건·Watch UI 3건은 표준 실행기 exit 0과 정상 결과 번들로 확인했다. 카드 위 20pt·아래 20.1–20.3pt를 측정했으며 40mm 화면의 거리·시간·현재 존·구간 막대와 미수신 표시를 직접 확인했다.

운동 수치·지도 좌표는 검증 fixture다. 실제 사용자 운동, 실내 GPS 수신, Watch→HealthKit→iPhone 동기화 검증이 아니다. 다른 기기·큰 글씨·Always-On·Island·small 상태를 통과한 것으로 확대하지 않는다.
