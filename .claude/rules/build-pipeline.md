# Build Pipeline Rules

## 빌드 단일 진입점

빌드 검증은 반드시 스크립트를 통해 수행한다. 직접 `xcodebuild`나 `xcodegen`을 실행하지 않는다.

| 작업 | 명령 | 금지 |
|------|------|------|
| iOS 빌드 | `scripts/build-ios.sh` | `xcodebuild build` 직접 실행 |
| 프로젝트 재생성 | `scripts/build-ios.sh` (내부에서 regen) | `xcodegen generate` 직접 실행 |
| CI xcodegen | `scripts/lib/regen-project.sh` | `xcodegen generate` 직접 실행 |

## 이유

`xcodegen generate`를 직접 실행하면 후처리가 누락된다:
- `project.pbxproj`: objectVersion/compatibilityVersion이 Xcode 26 이전 값으로 생성
- `*.xcscheme`: version, runPostActionsOnFailure, onlyGenerateCoverageForSpecifiedTargets 누락 → perpetual diff

후처리는 `scripts/lib/regen-project.sh`에 집중되어 있으며, `build-ios.sh`가 이를 호출한다.

## 금지 패턴

```bash
# BAD: 후처리 누락
xcodegen generate --spec DUNE/project.yml

# BAD: xcodebuild 직접 실행 (xcodegen 후처리 없음)
xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE

# GOOD: 스크립트 경유
scripts/build-ios.sh
```
