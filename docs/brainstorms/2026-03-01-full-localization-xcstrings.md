---
tags: [localization, i18n, xcstrings, string-catalog, multilingual]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: 전체 앱 다국어 지원 (String Catalogs)

## Problem Statement

앱의 모든 사용자 대면 텍스트가 영어로 하드코딩되어 있으며, localization 인프라가 전혀 없음. 영어/한국어/일본어 3개 언어를 지원하여 글로벌 사용자 접근성을 확보해야 함.

## Target Users

- 한국어 사용자 (1차 시장)
- 영어 사용자 (글로벌)
- 일본어 사용자 (피트니스 앱 시장 규모 고려)

## Success Criteria

1. Xcode String Catalogs (`.xcstrings`) 기반 localization 인프라 구축
2. 모든 사용자 대면 문자열 en/ko/ja 번역 완료
3. enum displayName 포함 단일 소스 관리
4. Watch 앱 동일 수준 localization
5. 빌드 성공 + localization 누락 경고 0

## Current State Analysis

### 규모
| 항목 | 수량 |
|------|------|
| iOS Presentation 파일 | 126+ |
| watchOS View 파일 | 22 |
| 고유 UI 문자열 | ~280-340개 |
| Enum display values | ~80+ |
| 부분 한국어 파일 | 4개 (Equipment, MuscleGroup, BodyPart, InjurySeverity) |

### 문자열 유형별 분류
1. **Button labels** (~18): "Done", "Cancel", "Edit", "Delete", "Save" 등
2. **Navigation titles** (~26): "Today", "Settings", "Activity" 등
3. **Section headers** (~31): "Workout Defaults", "Data & Privacy" 등
4. **Label components** (~52): "Rest Time", "Default Sets" 등
5. **설명/도움말** (~40+): 멀티 문장 가이던스
6. **에러 메시지** (~30-40): validation, fetch 에러
7. **다이얼로그** (~20): 확인/취소 메시지
8. **Enum display** (~80+): ExerciseCategory, MuscleGroup, Equipment 등

### 유리한 점
- SwiftUI `Text("...")` → `LocalizedStringKey` 자동 변환
- 날짜/숫자 포맷팅 이미 locale-aware (`.formatted()`)
- Enum `displayName` 패턴 일관적

### 도전 과제
- 126+ 파일에 분산된 하드코딩 문자열
- Interpolation 포함 문자열 처리 필요
- 운동/의학 용어 정확한 번역 필요
- watchOS 별도 String Catalog 필요

## Proposed Approach

### 기술 선택: Xcode String Catalogs (.xcstrings)

**이유**: Xcode 15+ 기본 제공, JSON 기반 편집 용이, 자동 문자열 추출 지원, .strings/.stringsdict 통합 대체.

### 아키텍처

```
DUNE/
├── Resources/
│   └── Localizable.xcstrings     ← iOS 앱 문자열
DUNEWatch/
├── Resources/
│   └── Localizable.xcstrings     ← Watch 앱 문자열
```

### 키 네이밍 컨벤션

```
{scope}.{context}.{element}

예시:
- common.button.done
- common.button.cancel
- dashboard.title
- dashboard.section.condition
- settings.section.defaults
- exercise.category.strength
- muscleGroup.chest
- error.fetch.workout
- dialog.endWorkout.title
- dialog.endWorkout.message
```

### 마이그레이션 전략

**Phase 1: 인프라 구축**
- `Localizable.xcstrings` 생성 (iOS, watchOS)
- `project.yml`에 xcstrings 리소스 추가
- `.claude/rules/localization.md` 규칙 추가

**Phase 2: 공통 문자열 추출**
- Button labels, navigation titles, section headers
- 에러 메시지, 다이얼로그 텍스트
- `String(localized:)` 패턴 적용

**Phase 3: Enum displayName 마이그레이션**
- Equipment, MuscleGroup, BodyPart, InjurySeverity, ExerciseCategory 등
- switch → `String(localized:)` 변환
- 기존 한국어 번역 보존

**Phase 4: 화면별 마이그레이션**
- Dashboard → Activity → Wellness → Settings → Sheets
- 각 화면의 Text/Label/Button 문자열 키 적용

**Phase 5: watchOS 마이그레이션**
- Watch 전용 문자열 카탈로그
- iOS와 공유되는 문자열은 동일 키 사용

**Phase 6: 번역 추가**
- 영어 (base) → 한국어 → 일본어 순
- 도메인 전문 용어 검증

## Constraints

- **기술적**: iOS 26+ / Xcode 17 / Swift 6 / String Catalogs
- **xcodegen**: `project.yml`에서 xcstrings 파일을 리소스로 인식해야 함
- **CloudKit**: 동기화 데이터는 localize 대상 아님 (사용자 입력 데이터)
- **Watch**: 별도 타겟이므로 별도 xcstrings 필요

## Edge Cases

- Plural forms (일본어는 대부분 단수=복수이나, 카운터 표현 주의)
- 운동 이름 번역 (국제적으로 영어 원문 사용이 일반적 → 옵션 제공?)
- RTL 언어 미지원 (현재 범위 외)
- 빈 문자열 / nil 처리
- Dynamic Type + 긴 번역 텍스트의 레이아웃 깨짐

## Scope

### MVP (Must-have)
- `.xcstrings` 인프라 구축 (iOS + watchOS)
- 모든 UI 문자열 en/ko/ja 번역
- Enum displayName xcstrings 통합
- Localization 개발 규칙 문서

### Nice-to-have (Future)
- 중국어 간체/번체 추가
- 인앱 언어 전환 (시스템 설정 우회)
- 번역 품질 검수 프로세스
- Screenshot 기반 localization 테스트

## Open Questions

1. 운동 이름 (Bench Press, Squat 등)은 영어 유지 vs 번역?
   → 국제 피트니스 커뮤니티에서는 영어가 표준이므로 영어 유지 권장
2. Watch에서 iOS와 공유하는 문자열을 어떻게 관리?
   → 별도 xcstrings이지만 동일 키+번역 유지
3. Pluralization이 필요한 문자열이 있는지?
   → "N days", "N sets" 등 → stringsdict 대체 문법 사용

## Next Steps

- [ ] `/plan localization` 으로 상세 구현 계획 생성
- [ ] `/work` 로 단계별 실행
