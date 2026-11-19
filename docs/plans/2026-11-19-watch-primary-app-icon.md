---
topic: Watch 기본 앱 아이콘 동기화
date: 2026-11-19
status: implemented
confidence: high
related_solutions: [2026-02-26-watchos-app-icon-validation, 2026-11-16-themed-app-icon-and-launch-branding]
---

# Watch 기본 앱 아이콘 동기화

App Store Connect의 빌드 자산에서 iOS는 인터리브 82/P04를 표시하고 Watch는 예전 능선 로고를 표시한다. 두 타깃의 AppIcon 설정은 유효하지만 서로 다른 PNG를 포함한다.

## 변경과 검증

1. `DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`를 승인된 iOS 기본 아이콘과 같은 불투명 1024px 원본으로 교체한다. 원형 마스크는 시스템에 맡긴다.
2. `scripts/generate-app-icon-assets.swift`의 기본 생성 경로에서 기본 아이콘을 Watch 카탈로그에도 기록한다. 임시 `--output-dir` 실행은 지정한 출력에만 쓴다. Watch 전용 카탈로그 메타데이터와 iOS 대체 아이콘 목록을 보존한다.
3. PNG 일치, 크기와 알파, 임시 출력의 격리를 검사한다. 기기용 빌드에 포함되는 Watch 앱의 아이콘 이름과 컴파일된 아이콘 이미지를 확인한다. 기존 업로드는 원래 바이너리를 유지하므로 스토어 확인에는 새 빌드가 필요하다.
