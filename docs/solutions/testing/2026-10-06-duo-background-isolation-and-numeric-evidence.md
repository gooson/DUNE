---
tags: [iphone-duo, simulator-isolation, dynamic-type, numeric-clipping, native-visual-audit, simulator-runtime-compatibility]
category: testing
date: 2026-10-06
severity: important
related_files:
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Posture/PostureDetailView.swift
related_solutions:
  - ../architecture/2026-10-06-duo-short-viewport-and-3d-controls.md
---

# Solution: 사용자 시뮬레이터를 격리하고 숫자의 실제 렌더링을 확인하기

## Problem

### Symptoms

사용자가 iPad Simulator를 사용하는 동안 Duo 검사는 백그라운드로 진행해야 한다. 기존 종료 fallback의 `simctl terminate booted`는 실행 중인 다른 기기와 검사 대상을 구분하지 않는다. 이 변경은 실제 iPad 종료 사건을 주장하는 것이 아니라 코드에서 확인한 대상 선택 위험을 제거한 것이다.

별도의 시각 문제로 실제 90도 / 최대 접근성 글자 크기에서 Life 진행률이 `3…`으로 생략되고 자세 상세의 `/ 100`이 링과 겹쳤다. XCTest의 진입 성공과 접근성의 완전한 문자열은 이러한 픽셀 잘림을 검출하지 못했다.

### Root Cause

- 종료 대상에 runner의 실제 UDID 대신 포괄적인 `booted`를 사용했다.
- Life ring의 고정 지름과 확대된 caption 크기가 맞지 않았다.
- 자세 점수의 고정 36pt / 120pt와 자동 확대되는 분모 caption의 크기가 달랐다.
- 결합된 접근성 요소 안의 비대화형 텍스트에 `isHittable`을 요구하면, 보이는 텍스트도 테스트 탐색 실패로 오판할 수 있다.

## Solution

### Changes Made

| 파일 | 변경 | 검증 범위 |
|---|---|---|
| UITestBaseCase.swift | 유효한 SIMULATOR_UDID만 종료 fallback으로 사용; 없으면 fallback 종료 | simulator isolation host 계약 14건 통과; 실제 iPad 조작 없음 |
| LifeView.swift | caption에 따라 ring 확대, AX hero 세로 배치, percentage intrinsic 크기 | 실제 Closed와 Book 최대 AX native에서 전체 33% 확인; 3pose chart 검사는 별도 |
| PostureDetailView.swift | score font와 ring을 함께 확대하고 72pt / 220pt로 상한 설정 | Xcode 27.1, 실제 0/90/180도, synthetic 86점, 1/1 / skip0 / exit0 / 140.204초 |

해당 수정은 로컬 커밋 `2e26907f`, `878869b8`, `ca42b794`로 분리했다. 일반 폰트의 기존 ring 크기는 유지한다. 공통 ProgressRing 컴포넌트는 수정하지 않았다.

### Key Code

```swift
guard let simulatorID = ProcessInfo.processInfo.environment["SIMULATOR_UDID"],
      UUID(uuidString: simulatorID) != nil else { return }
// simctl terminate에는 simulatorID만 전달한다.
```

검사기는 버튼에 대해서는 전체 frame과 hit testing을 확인하고, 비대화형 숫자는 값과 전체 frame을 확인한다. 실제 그림의 잘림은 원본 native PNG로 별도 판단한다. `FOLD:`는 CLI hinge 제어 뒤 실제 0/90/180도 readback을 기록하며 GUI나 사용자 iPad를 조작하지 않는다.

## Prevention

### Checklist Addition

- [ ] 사용자 기기와 전용 검사 UDID를 기록하고 모든 변경 명령에 전용 UDID를 명시한다.
- [ ] GUI focus, 메뉴, 창 선택 없이 CLI + XCTest로 실행한다.
- [ ] 폰트 확대 시 고정 크기의 원형/차트/수치 열과 텍스트의 크기 관계를 검토한다.
- [ ] 접근성 문자열, 전체 viewport frame, 실제 PNG를 구분해 판정한다.
- [ ] fold target뿐 아니라 physical readback과 런타임 supportedDeviceTypes를 기록한다.
- [ ] 실패 원본을 보존하고 원인이 바뀐 검사만 재실행한다.

### Rule Addition

Claude source rules는 수정하지 않는다. 향후 Codex 실행 지침에 simulator 대상 격리와 비대화형 숫자의 시각 증거 기준을 연결하는 보강을 제안한다.

## Lessons Learned

기능 성공은 화면 렌더링 성공과 다른 증거다. 동작이 통과한 화면에서도 native 픽셀 검사로 결함을 발견했다. 반대로 이미 온전히 보이는 비대화형 숫자에 버튼의 hit-testing 기준을 적용하면 잘못된 실패가 발생한다.

설치된 device type이 모든 runtime과 호환되는 것은 아니다. 이 환경에서 iOS 27.1 runtime은 Duo를 지원하고 iPhone 18 Pro는 iOS 27.0에서 지원한다. Xcode 27.1 빌드 요구와 검사 runtime은 별도로 기록한다. iOS 18.6도 available이므로 이전 OS session 미검증을 runtime 부재로 설명하지 않는다. 실제 upgrade session fixture와 카메라 실기기 검증은 별도의 증거가 필요하다.

증거는 [잔여 검증 보고서](../../reviews/2026-10-06-duo-remaining-route-coverage.md)와 해당 native assets에 보존한다. 이 문서는 155개 route 선언의 전수 실행, 모든 점수/글자/접힘 조합, 실제 카메라 정확도의 완료를 주장하지 않는다.
