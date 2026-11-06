---
tags: [documentation, design-map, targeted-ui, validation-provenance]
date: 2026-11-06
category: general
status: implemented
---

# 습관 상세 계획의 화면 유형과 실제 검증 결과 맞추기

## Problem

습관 상세 공통 템플릿에 남은 닫기/뒤로와 빈 기록·범례 설명이 서로 다른 화면 유형에 섞였다. 계획이 완료 상태로 바뀐 뒤에도 실제 SDK 결과가 없다는 초기 문장이 남아 최종 검증 범위를 오해할 수 있었다.

## Solution

L05/L06 계획과 레이아웃의 시트 Close를 push 화면의 Back과 구분했다. 각 화면의 실제 메서드·기기 기여와 PNG·AX 수를 적고, 공통 계획에는 원래 네 실행 계획과 실제 여덟 SDK archive·실패 이력·화면별 머지 결과를 분리했다. L07/L08의 push 설명은 각 화면 PR에서 이미 수정했다. 이번 묶음 네 화면의 계획·해결 문서와 공통 계획의 상태는 문서 규칙의 `implemented`로 맞췄다. 앱·테스트·실제 캡처 데이터는 변경하지 않았다.

## Prevention

공통 템플릿을 복사한 뒤 화면 유형·원래 내비게이션·해당 selector와 실제로 확인한 상태를 각각 대조한다. 계획을 완료로 바꿀 때 초기 상태 문장과 실제 결과가 충돌하지 않는지 확인한다. 문서만 바뀌면 UI 검사를 반복하지 않고 링크·차이·출처를 검토한다.

## Lessons Learned

화면의 실제 기능과 문서의 검증 주장을 함께 맞춰야 한다. 실패 aggregate와 이후 성공 selector, 전체 묶음과 화면별 기여는 다른 수치로 기록한다.
