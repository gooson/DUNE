---
tags: [cardio-atlas, share, spacing, dynamic-type, swiftui]
category: general
date: 2026-10-30
severity: minor
status: implemented
related_files:
  - DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasShareView.swift
  - DUNEUITests/Visual/CardioAtlasUITests.swift
---

# 공유 스타일 선택 버튼의 여백 정리

## Problem

공유 화면의 세 스타일 버튼이 아이콘/이름 2단 구성에 `minHeight: 62`와 시스템 버튼 padding을 더해 큰 pill로 표시됐다. 내용에 비해 빈 공간이 크고 미리보기 카드가 아래로 밀렸다.

## Solution

아이콘과 이름을 가로로 배치하고 `.controlSize(.small)`을 적용했다. 버튼 label 최소 높이는 36pt로 줄이고 실제 시스템 버튼의 44pt 이상 터치 영역을 UI 테스트로 확인한다. 상단 padding은 16→8pt, 스타일 선택과 카드 사이 간격은 20→16pt로 정리했다. 접근성 글씨에서는 선택 버튼을 전체 너비의 3행으로 전환해 이름을 읽을 공간을 확보한다.

색/테마, 선택 trait, 사용할 수 없는 Pace Ribbon, 공유 카드 이미지와 위치 공개 범위는 기존 동작을 유지한다. 이번 수정은 CA05–CA07 공유 편집 컨트롤의 배치에 한정한다.

## Verification

검증 범위는 한국어·다크 모드의 기본/최대 접근성 글씨, 스타일 전환, 이미지 공유 준비 상태다. 위치 포함을 끈 예시 경로 fixture를 사용해 이번 컨트롤 검사가 MapKit 네트워크에 의존하지 않게 했다. iPhone 기본/최대 접근성 글씨 2/2, iPad 기본 글씨 1/1이 정상 종료·통과했다. 실제 버튼 frame 44–56pt와 카드 간격 20pt 이하를 확인했다. [새 실제 원본 8장과 기기별 범위](../../design/full-redesign-map/review/cardio-share-spacing-2026-10-30/index.html)를 보존했다. Duo 접힘·펼침의 새 캡처는 직전 AX/러너 기동 장애의 정상화 근거가 없어 미완료이며, 같은 실패 경로를 재실행하거나 기존 PNG로 대체하지 않았다. 기존 장소 검색 검사의 성공/실패를 이번 공유 화면의 검증 결과로 재사용하지 않는다.

## Prevention

시스템 버튼 스타일에 최소 높이를 줄 때는 label 높이와 시스템 padding이 합쳐진 실제 버튼 frame을 확인한다. 좁은 화면의 세로 아이콘/이름 구성이 필요 이상으로 커지면 가로 구성과 큰 글씨 전용 세로 배치를 먼저 검토한다.

## Lessons Learned

공간을 줄일 때 글자 크기나 터치 영역보다 내부 구성과 중첩 padding을 먼저 확인한다. 상단 스타일 선택과 카드 미리보기는 하나의 그룹으로 묶어 둘 사이 간격을 조정하면 아래 옵션의 간격을 불필요하게 바꾸지 않아도 된다.
