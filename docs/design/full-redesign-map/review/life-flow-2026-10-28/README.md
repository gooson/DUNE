---
tags: [life, actual-screen, iphone, ipad, duo]
date: 2026-10-29
status: verified-selected-scope
---

# Life Flow · 네이티브 실제 화면

iPhone·iPad·Duo 외부/내부의 새 네이티브 PNG74장을 보존한다. 통과한 테스트에서68장, 초기 실패 실행의 부분 증거6장이다. 시안 렌더가 아니며 바이트를 수정하지 않았다. manifest에 각 이미지의 소스·기기·원본·결과·SHA-256을 기록한다.

- iPhone: 초기10장(부분6 포함), 승인 추가 실행15장, 최종 주간/예정 회귀4장.
- iPad: 기본·다크·최대글씨의 히어로/오늘/리듬/지난 기록 및 밝은 히트맵/보고15장.
- Duo 외부/내부: 자세별 같은15장. 기본·다크·최대글씨 검사 각각 통과했고 모든 명명 checkpoint ACK가 유효하다. 활성 display PNG를 표시하고 비활성 paired PNG·AX는 검증 폴더에 보존한다.

앱 소스는62d3c097 이후 동일하다. iPhone 캡처는19f43ee3/dd18af04/c80b5f1e, iPad는c80b5f1e, Duo는791b8bf4의 UI 전용 split 검사에서 수집했다. L07은 native 제목 Activity Detail인 HabitHeatmapDetailView이고 루트 주간 요약은L01, Weekly Report 상세는L08이다.

Duo 외부는1398×2034/LCD1, 내부는2853×2007/LCD-1·display3 활성이다. 실제 display readback과 AX frame으로 자세를 확인했으며 숫자 hinge 각도는 측정되지 않았다. 각 자세의 대표 히어로·리듬·지난 기록을 육안 검토했다. 최대글씨 폼 PNG는 스크롤 중 한 viewport이므로 전체 폼의 동시 표시/VoiceOver 검증이 아니다. L08 다크·최대글씨와 모든 테마는 이번 범위 밖이다.

[전체 검증·이전 실패](../../../../reviews/2026-10-28-life-flow/README.md), [출처](manifest.json), [시안](../../../theme-map/themes/dune-life-redesign.html)을 각각 구분한다.

최대글씨 리듬 캡처도 카드 상단 viewport이므로 전체 플롯·축의 동시 표시를 증명하지 않는다. 기본 크기의 리듬 수치·막대·28일 패턴은 별도 원본에서 확인했다.
