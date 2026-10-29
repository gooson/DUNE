---
tags: [cardio-atlas, sheet, modal, scroll, background, navigation]
category: general
date: 2026-10-30
severity: important
status: implemented
related_files:
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasSection.swift
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasShareView.swift
  - DUNEUITests/Visual/CardioAtlasUITests.swift
---

# 공유 모달 배경과 세로 드래그 안정화

## Problem

사용자가 제공한 영상에서 공유 모달을 위아래로 움직일 때 내용이 보이지 않는 시트에 `완료`만 중간에 남거나 아래 운동 상세/목록이 드러났다. 공유 본문에는 명시적인 불투명 배경이 없었고, inspector 위에서 여는 공유 sheet의 크기·본문 제스처 처리가 기본 설정에 맡겨져 있었다.

## Solution

- 공유 목적지의 독립 `NavigationStack`은 유지하고, 해당 목적지에만 page sizing·large detent·본문 scroll 우선·닫기 손잡이를 지정했다. Journey/Passport의 표시 정책은 바꾸지 않았다.
- 공유 `ScrollView`가 제안된 전체 영역을 채우게 했다. 불투명 `surfacePrimary` 위에 `SheetWaveBackground`를 놓고 safe area까지 확장했다. 내비게이션 바와 sheet 바탕도 같은 불투명 색을 사용한다.
- 본문 내용이 화면보다 클 때만 bounce를 허용한다. 드래그 닫기를 비활성화하지 않으며, 닫힌 뒤 같은 운동 상세가 정상적으로 남는지 확인한다.

사용자 영상의 모든 시스템 중간 프레임을 실기기에서 동일하게 계측한 결과는 아니다. 명시적 배경이 빠진 설정과 자동 크기에 의존하던 경로를 수정하고, 예시 데이터로 실제 모달 제스처 회귀를 검증한다.

## Verification

위치 비공개·예시 운동으로 한국어 dark/light와 최대 접근성 글씨의 긴 본문을 검사한다. 본문 위아래 드래그 후 보이는 카드/컨트롤과 충분한 본문 높이를 확인하고, 제목 영역 드래그 닫기→같은 상세→공유 재열기→완료 닫기를 검사한다. iPhone dark/light/최대 글씨 3/3, iPad dark 1/1이 정상 종료·통과했다. [새 실제 원본 20장과 기기별 검증](../../design/full-redesign-map/review/cardio-share-modal-2026-10-30/index.html)을 보존했다. 첫 실행은 본문 구간 후 제목 영역의 닫기 드래그에서 실패했고, AX로 확인한 보이는 시스템 손잡이를 직접 끄는 입력으로 보정해 한 번 재검증했다. 직전 Duo의 AX/러너 기동 장애는 복구 근거 없이 다시 실행하지 않는다.

## Prevention

내용의 데이터 상태와 별개로 modal의 불투명 바탕과 제안 영역을 정의한다. inspector 위의 중첩 sheet는 최초 진입뿐 아니라 본문 스크롤·상단 드래그·닫기 취소/완료·재열기를 같은 seeded 흐름으로 검사한다. 배경색 설정이나 정적 캡처만으로 제스처 수정 완료를 판단하지 않는다.

## Lessons Learned

투명한 본문과 자동 modal 크기는 서로 다른 설정이다. 각각을 명시하고 본문 스크롤과 sheet 닫기를 구분해 확인해야, 빈 시트가 남는 문제를 단순 색상 변경으로 숨기지 않을 수 있다.
