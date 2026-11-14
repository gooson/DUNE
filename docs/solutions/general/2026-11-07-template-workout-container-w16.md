---
tags: [swiftui, detail-redesign, w16, accessibility, native-capture]
category: general
date: 2026-11-07
severity: minor
status: resolved-with-explicit-capture-limits
related_files: [DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift]
related_solutions: []
---

# W16 큰 글씨 배치와 실제 화면 검증

## Problem / Solution

원래 템플릿 컨테이너의 진입·자동 전환·첫 세션을 새 실제 캡처로 확인했다. wrapper 앱 코드는 수정하지 않았다. 원래 아이콘·색·값·단위·기간·선택/입력·저장/내비게이션 콜백을 시각 작업으로 바꾸지 않았다. 배치·테마 제안은 앱 변경 전에 보존했으며 실제 캡처와 구분했다.

## Actual verification

[통과/진단 PNG·AX와 원본 실행 결과](../../design/full-redesign-map/review/template-workout-container-w16-2026-11-07/index.html). Phone MAX 통과와 iPad 일반·MAX 통과만 after다. Phone 일반은 5초 자동 전환 뒤 사라진 Start 탭의 검사 실패로 역사적 실제 맵/미갱신과 진단을 유지한다. 앱 owner SHA `fa59b2bfd3e08799df488b63c8585695e3bc82d6ee99a9d91b6c1a6dcf61d733`가 frozen `324b0b30033583cc8a218805afb6e4b609e55137`와 동일하다. 공유 증분 UI 컴파일을 사용했고 화면별 PR 분리를 이유로 이미 유효한 관찰을 재실행하지 않았다. 일반적인 전체 회귀를 실행한 결과는 아니다.

Phone 원본 7개는 3통과/4실패, 같은 ID의 원인 대응 재검사 4개는 3통과/1실패다. 고유 선택자 7개 중6개가 통과했으며 7/7이라고 보고하지 않는다. iPad 실제 결과는 갤러리 receipt와 독립 최종 게이트에 기록한다. 단계가 달라졌다고 실패 한도나 원본을 초기화하지 않는다.

## Limits

Duo의 새 캡처는 대기다. Running 센서 값 `--`는 시뮬레이터 동작 추적 불가 안내와 함께 기록했으며 실제 측정·GPS 성공이 아니다. Stair Climber는 기본 글씨 분기만 확인했다. Save는 누르지 않았다. 템플릿 전환의2sets 표시와 첫 세션Set1of3 관측을 구분하며 설정2세트가 적용됐다는 주장을 하지 않는다. 첫 선택 이름/탭이 스크롤 화면에 일부만 들어온 장면을 모든 값의 동시 가시성으로 해석하지 않는다.

## Prevention / Lessons learned

최대 글씨 검사는 원래 선택·입력·전환 동작과 함께 확인하고, 통과한 PNG/AX와 실패 진단의 출처를 구분한다. 고정 footer가 문구를 가릴 수 있으므로 스크롤 영역 안의 중점만으로 전체 가독성을 판정하지 않는다. 같은 소스의 공유 증분 컴파일은 재사용하되 빠진 기기·상태를 통과로 표시하지 않는다.
