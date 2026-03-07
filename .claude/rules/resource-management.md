# Resource Management Rules

## Single Source of Truth

| 리소스 유형 | 소스 위치 | 참조 타겟 |
|------------|----------|----------|
| 테마 색상 (232+) | `Shared/Resources/Colors.xcassets` | 전체 (DUNE, Watch, Widget, Vision, VisionWidgets) |
| 번역 문자열 | `Shared/Resources/Localizable.xcstrings` | DUNE, DUNEWidget, DUNEVision |
| Watch 전용 문자열 | `DUNEWatch/Resources/Localizable.xcstrings` | DUNEWatch |
| iOS 전용 색상 | `DUNE/Resources/Assets.xcassets/Colors/` | DUNE |
| iOS Equipment icons | `DUNE/Resources/Assets.xcassets/Equipment/` | DUNE (512px) |
| Watch Equipment icons | `DUNEWatch/Resources/Assets.xcassets/Equipment/` | DUNEWatch (128px) |
| App Icon | 타겟별 `Resources/` | 플랫폼 요구사항 상이 |
| exercises.json | `DUNE/Data/Resources/` | Watch는 WatchConnectivity sync |

## Equipment Icons 분리 근거

iOS(512×512px)와 watchOS(128×128px)의 Equipment icons은 해상도와 파일명 패턴이 다르므로 타겟별 분리 유지.
- iOS: `barbell.png` (6-21KB per icon)
- Watch: `equipment.barbell.png` (1-3KB per icon)
- 둘 다 `universal` idiom + `template-rendering-intent` 사용

## 중복 금지 기준

| 상황 | 정책 |
|------|------|
| 동일 파일 (byte-for-byte) | 즉시 `Shared/Resources/`로 통합 |
| 동일 컨텐츠, 다른 포맷/해상도 | 타겟별 유지 + 원본 소스 위치 명시 |
| 완전 독립 리소스 | 타겟 내 보관 |

## 새 타겟 추가 시 체크리스트

1. `Shared/Resources/Colors.xcassets` 참조 추가 (project.yml sources)
2. 사용자 대면 문자열이 있으면 `Shared/Resources/Localizable.xcstrings` 참조 추가
3. 타겟별 AppIcon 생성 (플랫폼 요구사항 확인)
4. entitlements 분리 (플랫폼별 capability 상이)
5. 이 문서의 Single Source of Truth 테이블 업데이트

## project.yml 참조 패턴

```yaml
# Shared 리소스 참조 표준 형식
- path: ../Shared/Resources/Colors.xcassets
  group: Shared/Resources
- path: ../Shared/Resources/Localizable.xcstrings
  group: Shared
```
