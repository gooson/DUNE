---
tags: [xctest, swiftui-menu, dynamic-type, ipad, iphone-duo, simulator, native-evidence]
date: 2026-10-30
category: testing
---

# 큰 글씨 선택기와 Duo 검증을 실제 화면 경계에 맞추기

## 문제와 원인

정보 Picker의 고정77.5pt 버튼 높이에서123–184pt 선택 문구가 잘렸다. 이는 스크롤 가장자리와 구분되는 실제 UI 문제였다. 메뉴 CollectionView의 AX 높이는874pt인데 실제 popup은520pt로 잘렸고, 고정 큰 드래그는 목표 행을 왕복해 지나쳤다. iPad의 전체 창 중심516pt는 실제 조회 영역612–1032pt 밖이어서 왼쪽 대시보드만 스크롤했다. 범위 없는 뒤로 버튼 선택은 왼쪽 알림함을 열었다. Duo는 오른쪽 floating BackButton에 레이블이 없고 Done을 항상 노출하지 않았다.

## 해결

접근성 글자 크기에서만 줄바꿈·자연 높이의 Menu 라벨을 제공하고 기본 Picker는 보존한다. 제목·선택 값·체크·접근성 선택 trait를 유지한다. 테스트는 메뉴의 실제 조상 clipping 프레임과 창의 교집합을 사용하고, 행의 필요한 이동 거리만 느리게 드래그한 뒤 멈춘다. 종류와 기간이 같은 선택 도우미를 쓴다. 조회 ScrollView의 중심에서 이동하고 내비게이션 아래에 값 전체가 들어오는지 검사한다. 활성 레이블 뒤로 버튼을 우선하고 Duo에서는 hittable BackButton으로 복귀한다. 시스템 공유는 실제 caption의 준비와 취소 후 보고서 복귀를 모두 확인한다.

## Duo 상태와 SDK27.2

검토한 HID Open setter의 성공 코드만으로 내부 화면을 주장하지 않는다. 실제로 LCD가 활성인 채 남아 공식 Device Hub의 정확한 전용 기기에서 Open을 선택했다. devicectl의 unique active 패널, 명시 display1/3 원본 PNG와 앱 viewport를 짝지어 보존한다. SDK27.2는 비활성LCD에activeOn, 렌더링중LCD-1에off를 반환했으므로 backlightState는 원문 진단값으로만 남긴다. 숫자 hinge angle을 측정했다고 보고하지 않는다.

## 예방과 검증

선택 문구·기간·결과 큰 값을 각각 새 PNG로 촬영해 컨트롤 내부 잘림과 유효한 스크롤 연속 영역을 구분한다. 현재 worktree 소유 UDID, 표준 실행기·저장소 잠금·deadline, 원인별 조건부 재시도 한도를 유지한다. 실제 저장 기록 경로와 합성 snapshot 경로를 메타데이터에 정확히 표시하고, 통과한 검사에서 나온 이미지와 실패 진단을 합산하지 않는다. 실행 결과와 새 이미지의 마지막 검토는 최종 Siri 건강 조회 검증 기록을 따른다. 실제 Siri 음색은 코드·시뮬레이터 이미지의 검증으로 확정하지 않는다.
