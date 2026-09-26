---
tags: [watch, workout, weight, input-validation, release-audit, ios]
date: 2026-09-20
category: general
status: implemented-with-verification-limits
---

# 운동 기록 입력·디자인 1.0 조사

## Problem

크런치 등 운동의 무게 표시/수정 불일치 요청을 출발점으로 133개 기본 운동, 워치 Quick Start/루틴/세트 입력/이전 기록/저장, 폰 단독/루틴/복합 운동/기본 설정을 코드 기준으로 조사했다. 전체 종목의 실기기 검증 완료를 의미하지 않는다.

## Solution

| 발견 | 영향 | 변경 |
|---|---|---|
| 시작 미리보기와 세션의 inputType 소스 불일치 | 오래된 크런치 템플릿이 무게 운동으로 열림 | 시작 시 라이브러리 메타데이터 적용, offline alias 정규화 |
| 추가 중량 입력값으로 입력창 표시 상태까지 결정 | 숫자를 지우면 필드가 사라지고 재입력 불안정 | 입력 모드 상태와 숫자 문자열 분리; 실제 UI 회귀에서 확인 |
| 맨몸 운동 무게가 화면에서 숨겨짐 | 추가 중량을 바꾸거나 제거할 수 없음 | 워치/폰에서 추가 중량 선택과 제거, 기존 가중 기록도 보이게 함 |
| 자동 프리필과 사용자 중량 변경 혼동 | 루틴의 다음 세트 계획 중량이 덮어써질 수 있음 | 입력 sheet의 실제 수정에서만 세션 override 반영 |
| nil weight를 기본값으로 대체 | 제거한 중량이 다시 생김 | 이전 세트의 무중량 상태와 미기록 상태 구분 |
| 워치 HIIT가 weight/reps 화면 사용 | 필요 없는 kg, 라운드 시간 누락 | 무게 제거, 반복/라운드와 활성 경과 시간 기록 |
| 시간 운동의 무효한 분 입력 | 수정해도 실제 저장에 미반영 | 최초/휴식 후/운동 전환에서 시간 입력 sheet 차단, 실제 타이머 사용 |
| 시간 운동이 pause 포함 | 홀드 기록 과다 | activeElapsedTime 기준으로 계산 |
| 4종 운동 분류 오류 | 홀드를 횟수로, 메디신볼을 무중량으로 기록 | 아래 전수 목록에 수정 표시 |
| kg/lb 라벨만 전환 | 실제 저장 중량 변화 | 현재/완료 세트 숫자도 단위 변환 |
| 완료 세트 캐시가 값 변경 무시 | 수정한 무게/횟수/RPE 유실 | 저장과 요약에서 최신 완료 세트 사용 |
| 비중량 운동의 숨긴 필드 저장 | 유산소/시간 운동에 무게 혼입 | 저장 시 지원 필드 제한 |
| 복합 운동 일부만 저장 | 검증 실패 운동이 조용히 누락 | 완료 운동 하나라도 실패하면 전체 저장 중단, 재시도 허용 |
| 폰 공유 row의 분/초 혼용 | 90초가 잘못 저장/복원 | 시간/라운드 세트는 초, 유산소는 분 |
| 세트 진행 문구 번역 키 불일치 | 한국어에서도 Set 1 of 5 노출 | 기존 번역 카탈로그와 보간 타입 일치 |
| KG 버튼의 중복 capsule | 상단 뒤로가기와 큰 장식 영역 중첩 | native trailing toolbar label, 내부 capsule/padding 제거; 중량 미지원 세션은 단위 버튼 숨김 |
| 기본 설정/루틴에 무조건 중량 노출 | 시간/HIIT에 불필요한 필드 | 입력 유형에 따라 중량 필드 제한 |

## Verification

관련 iOS 유닛 테스트 119개(5 suites) 통과. 실제 WatchSetInputPolicy 소스로 macOS에서 경계값/무중량/지원 유형 22개 검사 통과. 워치 유닛 및 UI 테스트 타겟 모두 build-for-testing 통과. iOS 운동 저장 UI 테스트와 크런치 추가 중량 입력·kg/lb 변환·중량 제거 UI 테스트 통과. 크런치 테스트의 화면 첨부도 확인했다. 워치 런타임 미설치로 워치 UI 테스트는 실행 불가하며, 테스트 코드를 추가해 향후 실행 가능하게 유지했다.

## 출시 전 남은 검증·설계

- 41mm/45mm/Ultra와 큰 글씨에서 Crown, 추가 중량 토글, 모든 하단 버튼 조작을 실제 검증해야 한다.
- 워치↔폰 실제 연결 및 재연결 후 추가 중량/무중량 기록 보존 확인이 필요하다.
- Farmers Walk/Trap Bar Carry/Sled Push/Pec Deck Isometric Hold는 기존 5개 입력 타입만으로 거리·시간·중량을 동시에 표현할 수 없다. 현재 기존 기록 의미를 임의로 바꾸지 않았다. 이를 지원하는 별도 타입과 양 플랫폼 UI/통계/동기화 설계가 필요하다.
- 보조 머신의 assistance weight, 밴드 강도, 덤벨 한 손당/합계 중량 정의는 별도 제품 정책이 필요하다.
- 이번 수정만으로 1.0 출시 준비 완료를 선언하지 않는다.

## Prevention

- 운동 입력은 라이브러리 → 템플릿 → 세트 UI → 검증 → 영속화 → WatchConnectivity까지 함께 검사한다.
- 선택 중량의 nil은 사용자 선택이다. 이전 기록이 없을 때만 기본 중량으로 fallback한다.
- 단위 변경은 라벨 변경이 아니라 값 변환이다. 완료 세트와 초안도 같은 의미를 유지해야 한다.
- 완료 상태 캐시는 수정 가능한 필드 전체를 반영하거나 제거한다.
- UI 표기 단위와 저장 단위의 왕복 테스트를 작성한다.

## Lessons Learned

종목의 JSON 분류만 맞아도 사용자는 다른 필드를 볼 수 있다. 저장된 템플릿, 숨겨진 프리필, 입력 모드 및 저장 검증을 하나의 흐름으로 점검해야 한다.

Crown 입력의 focusable host와 바인딩은 [Apple digitalCrownRotation 문서](https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:))를 참고했다.

## 133개 운동 전수 목록 (코드 기준)

유형별 수: 중량 + 횟수 87, 횟수 + 선택 중량 24, 시간 8, 시간 + 유산소 지표 10, 반복/라운드 + 시간 4

| ID | 입력 | 장비 | 조사 결과 |
|---|---|---|---|
| barbell-bench-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| incline-barbell-bench-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| decline-barbell-bench-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| dumbbell-bench-press | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| dumbbell-fly | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| cable-crossover | 중량 + 횟수 | cable | 현재 유형 유지 |
| chest-press-machine | 중량 + 횟수 | chestPressMachine | 현재 유형 유지 |
| pec-deck | 중량 + 횟수 | pecDeckMachine | 현재 유형 유지 |
| push-up | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| dip-chest | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| conventional-deadlift | 중량 + 횟수 | barbell | 현재 유형 유지 |
| sumo-deadlift | 중량 + 횟수 | barbell | 현재 유형 유지 |
| barbell-row | 중량 + 횟수 | barbell | 현재 유형 유지 |
| pull-up | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| chin-up | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| lat-pulldown | 중량 + 횟수 | latPulldownMachine | 현재 유형 유지 |
| seated-cable-row | 중량 + 횟수 | cable | 현재 유형 유지 |
| dumbbell-row | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| t-bar-row | 중량 + 횟수 | barbell | 현재 유형 유지 |
| face-pull | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| overhead-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| dumbbell-shoulder-press | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| lateral-raise | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| front-raise | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| rear-delt-fly | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| arnold-press | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| upright-row | 중량 + 횟수 | barbell | 현재 유형 유지 |
| shoulder-press-machine | 중량 + 횟수 | shoulderPressMachine | 현재 유형 유지 |
| barbell-curl | 중량 + 횟수 | barbell | 현재 유형 유지 |
| dumbbell-curl | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| hammer-curl | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| preacher-curl | 중량 + 횟수 | barbell | 현재 유형 유지 |
| cable-curl | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| tricep-pushdown | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| skull-crusher | 중량 + 횟수 | barbell | 현재 유형 유지 |
| overhead-tricep-extension | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| dip-triceps | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| close-grip-bench-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| barbell-squat | 중량 + 횟수 | barbell | 현재 유형 유지 |
| front-squat | 중량 + 횟수 | barbell | 현재 유형 유지 |
| goblet-squat | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| leg-press | 중량 + 횟수 | legPressMachine | 현재 유형 유지 |
| leg-extension | 중량 + 횟수 | legExtensionMachine | 현재 유형 유지 |
| leg-curl | 중량 + 횟수 | legCurlMachine | 현재 유형 유지 |
| romanian-deadlift | 중량 + 횟수 | barbell | 현재 유형 유지 |
| walking-lunge | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| bulgarian-split-squat | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| hip-thrust | 중량 + 횟수 | barbell | 현재 유형 유지 |
| calf-raise | 중량 + 횟수 | machine | 현재 유형 유지 |
| hack-squat | 중량 + 횟수 | hackSquatMachine | 현재 유형 유지 |
| step-up | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| good-morning | 중량 + 횟수 | barbell | 현재 유형 유지 |
| plank | 시간 | bodyweight | 현재 유형 유지 |
| crunch | 횟수 + 선택 중량 | bodyweight | 횟수 기본, 추가 중량 선택/제거 |
| hanging-leg-raise | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| russian-twist | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| ab-wheel-rollout | 횟수 + 선택 중량 | other | 현재 유형 유지 |
| cable-crunch | 중량 + 횟수 | cableMachine | 중량 + 횟수 유지 |
| mountain-climber | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| dead-bug | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| barbell-shrug | 중량 + 횟수 | barbell | 현재 유형 유지 |
| wrist-curl | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| clean-and-press | 중량 + 횟수 | barbell | 현재 유형 유지 |
| power-clean | 중량 + 횟수 | barbell | 현재 유형 유지 |
| thruster | 중량 + 횟수 | barbell | 현재 유형 유지 |
| kettlebell-swing | 중량 + 횟수 | kettlebell | 현재 유형 유지 |
| turkish-get-up | 중량 + 횟수 | kettlebell | 현재 유형 유지 |
| running | 시간 + 유산소 지표 | bodyweight | 현재 유형 유지 |
| walking | 시간 + 유산소 지표 | bodyweight | 현재 유형 유지 |
| cycling | 시간 + 유산소 지표 | machine | 현재 유형 유지 |
| swimming | 시간 + 유산소 지표 | bodyweight | 현재 유형 유지 |
| rowing-machine | 시간 + 유산소 지표 | machine | 현재 유형 유지 |
| elliptical | 시간 + 유산소 지표 | machine | 현재 유형 유지 |
| stair-climber | 시간 + 유산소 지표 | machine | 현재 유형 유지 |
| hiking | 시간 + 유산소 지표 | bodyweight | 현재 유형 유지 |
| jump-rope | 시간 + 유산소 지표 | other | 현재 유형 유지 |
| stationary-bike | 시간 + 유산소 지표 | machine | 현재 유형 유지 |
| burpee | 반복/라운드 + 시간 | bodyweight | 현재 유형 유지 |
| box-jump | 횟수 + 선택 중량 | other | 현재 유형 유지 |
| battle-ropes | 반복/라운드 + 시간 | other | 현재 유형 유지 |
| tabata | 반복/라운드 + 시간 | bodyweight | 현재 유형 유지 |
| sled-push | 반복/라운드 + 시간 | other | 추가 설계 필요: 거리/시간 + 썰매 중량 |
| yoga | 시간 | bodyweight | 현재 유형 유지 |
| pilates | 시간 | bodyweight | 현재 유형 유지 |
| stretching | 시간 | bodyweight | 현재 유형 유지 |
| foam-rolling | 시간 | other | 현재 유형 유지 |
| mobility-work | 시간 | bodyweight | 현재 유형 유지 |
| band-pull-apart | 횟수 + 선택 중량 | band | 밴드 강도는 현재 별도 입력 없음 |
| band-squat | 횟수 + 선택 중량 | band | 밴드 강도는 현재 별도 입력 없음 |
| inverted-row | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| pike-push-up | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| bodyweight-squat | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| single-leg-deadlift | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| cable-lateral-raise | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| concentration-curl | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| tricep-kickback | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| incline-dumbbell-curl | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| reverse-fly | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| lat-pullover | 중량 + 횟수 | dumbbell | 현재 유형 유지 |
| hip-abduction-machine | 중량 + 횟수 | machine | 현재 유형 유지 |
| hip-adduction-machine | 중량 + 횟수 | machine | 현재 유형 유지 |
| glute-bridge | 횟수 + 선택 중량 | bodyweight | 현재 유형 유지 |
| farmers-walk | 중량 + 횟수 | dumbbell | 추가 설계 필요: 횟수 대신 거리/시간 + 중량 |
| ezbar-preacher-curl | 중량 + 횟수 | ezBar | 현재 유형 유지 |
| ezbar-skull-crusher | 중량 + 횟수 | ezBar | 현재 유형 유지 |
| trap-bar-deadlift | 중량 + 횟수 | trapBar | 현재 유형 유지 |
| trap-bar-carry | 중량 + 횟수 | trapBar | 추가 설계 필요: 횟수 대신 거리/시간 + 중량 |
| smith-machine-squat | 중량 + 횟수 | smithMachine | 현재 유형 유지 |
| smith-machine-incline-press | 중량 + 횟수 | smithMachine | 현재 유형 유지 |
| narrow-stance-leg-press | 중량 + 횟수 | legPressMachine | 현재 유형 유지 |
| reverse-hack-squat-machine | 중량 + 횟수 | hackSquatMachine | 현재 유형 유지 |
| hack-squat-calf-raise | 중량 + 횟수 | hackSquatMachine | 현재 유형 유지 |
| incline-chest-press-machine | 중량 + 횟수 | chestPressMachine | 현재 유형 유지 |
| neutral-grip-chest-press-machine | 중량 + 횟수 | chestPressMachine | 현재 유형 유지 |
| seated-shoulder-press-machine | 중량 + 횟수 | shoulderPressMachine | 현재 유형 유지 |
| neutral-lat-pulldown-machine | 중량 + 횟수 | latPulldownMachine | 현재 유형 유지 |
| close-grip-lat-pulldown-machine | 중량 + 횟수 | latPulldownMachine | 현재 유형 유지 |
| tempo-leg-extension-machine | 중량 + 횟수 | legExtensionMachine | 현재 유형 유지 |
| seated-leg-curl-machine | 중량 + 횟수 | legCurlMachine | 현재 유형 유지 |
| reverse-pec-deck-machine | 중량 + 횟수 | pecDeckMachine | 현재 유형 유지 |
| pec-deck-isometric-hold | 중량 + 횟수 | pecDeckMachine | 추가 설계 필요: 시간 + 중량 |
| cable-machine-woodchop | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| cable-machine-pull-through | 중량 + 횟수 | cableMachine | 현재 유형 유지 |
| hanging-knee-raise-bar | 횟수 + 선택 중량 | pullUpBar | 현재 유형 유지 |
| pull-up-bar-isometric-hold | 시간 | pullUpBar | 수정: 횟수 → 시간 |
| dip-station-knee-raise | 횟수 + 선택 중량 | dipStation | 현재 유형 유지 |
| dip-station-support-hold | 시간 | dipStation | 수정: 횟수 → 시간 |
| trx-row | 횟수 + 선택 중량 | trx | 현재 유형 유지 |
| trx-chest-press | 횟수 + 선택 중량 | trx | 현재 유형 유지 |
| medicine-ball-slam | 중량 + 횟수 | medicineBall | 수정: 외부 중량 + 횟수 |
| medicine-ball-russian-twist | 중량 + 횟수 | medicineBall | 수정: 외부 중량 입력 |
| stability-ball-crunch | 횟수 + 선택 중량 | stabilityBall | 현재 유형 유지 |
| stability-ball-hamstring-curl | 횟수 + 선택 중량 | stabilityBall | 현재 유형 유지 |
