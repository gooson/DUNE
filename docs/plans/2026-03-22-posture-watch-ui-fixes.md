---
tags: [watchos, posture, ui, bugfix]
date: 2026-03-22
category: plan
status: approved
---

# Plan: watchOS 자세 모니터링 UI 수정

## 문제

1. **await 경고 2건**: `WatchPostureMonitor.swift`에서 `self?.method()` 호출이 `@MainActor` Task 내에서 불필요한 implicit await 생성
2. **설정 진입점 부재**: toolbar figure.stand 버튼이 제거된 후 PostureMonitorSettingsView로 진입할 UI 없음
3. **아이콘 색상**: 이전 toolbar 아이콘이 앱 tint(warmGlow)를 받아 부자연스러운 갈색 표시

## 영향 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | `self?.` → `guard let self` + `self.` (2곳) |
| `DUNEWatch/Views/CarouselHomeView.swift` | `.toolbar` gear 아이콘 추가 |

## 구현 단계

### Step 1: await 경고 수정
- `startSedentaryCheckTimer()` Task 내부: `self?.periodicCheck()` → `guard let self` + `self.periodicCheck()`
- `startDeviceMotionCollection()` Task 내부: `self?.finishDeviceMotionCollection()` → `guard let self` + `self.finishDeviceMotionCollection()`

### Step 2: CarouselHomeView gear 아이콘
- `.toolbar { ToolbarItem(placement: .topBarTrailing) }` 에 gear 아이콘 추가
- `NavigationLink(value: WatchRoute.postureSettings)` 사용
- `.foregroundStyle(.secondary)` + `.font(.system(size: 12))` 로 subtle하게

## 테스트 전략

- Watch 빌드 성공 확인 (`xcodebuild build -scheme DUNEWatch`)
- await 경고 0건 확인
- 시뮬레이터에서 gear 아이콘 표시 + 탭 시 설정 화면 진입 확인

## 리스크

- watchOS toolbar `.topBarTrailing` 배치가 스크롤 시 숨겨질 수 있음 → navigationTitle과 함께 표시되므로 수용 가능
- gear 아이콘이 posture 전용이면 향후 일반 설정 확장 시 변경 필요 → MVP 범위에서 수용
