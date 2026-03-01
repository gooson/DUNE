---
tags: [localization, i18n, xcstrings, string-catalog, multilingual]
date: 2026-03-01
category: brainstorm
status: reviewed
---

# Brainstorm: Localization 미적용 텍스트 전수 조사 및 수정

## Problem Statement

xcstrings 인프라와 `String(localized:)` 패턴이 대부분 적용되어 있으나, 일부 displayName 프로퍼티에 `String(localized:)` 래핑이 누락되어 있고, xcstrings에 ko/ja 번역이 빠진 키가 있음. 전수 조사하여 완전한 3개 언어 지원을 달성해야 함.

## Target Users

- 한국어 사용자 (1차 시장)
- 영어 사용자 (글로벌)
- 일본어 사용자

## Success Criteria

1. 모든 `displayName: String` 프로퍼티가 `String(localized:)` 래핑 완료
2. xcstrings에 모든 사용자 대면 키의 ko/ja 번역 존재
3. 탭 타이틀 (Today, Activity, Wellness, Life)은 모든 locale에서 영어 유지
4. 빌드 성공

## 현재 상태 분석

### 코드 수정 필요: displayName에 `String(localized:)` 누락

| 파일 | 라인 | 프로퍼티 | 하드코딩 값 |
|------|------|----------|------------|
| `AppTheme+View.swift` | 287-288 | displayName | "Desert Warm", "Ocean Cool" |
| `VolumePeriod+View.swift` | 6-9 | displayName | "1W", "1M", "3M", "6M" |
| `HealthMetric+View.swift` | 148, 153 | displayName | "BMI", "VO2 Max" |
| `Equipment+View.swift` | 27 | displayName | "TRX" |
| `WorkoutActivityType+View.swift` | 16 | displayName | "HIIT" |
| **합계** | | | **11개 문자열** |

### 코드 수정 불필요 (SwiftUI 자동 LocalizedStringKey)

SwiftUI의 Text, Button, Label, Section, navigationTitle 등은 문자열을 자동으로 `LocalizedStringKey`로 변환. xcstrings에 키와 번역만 추가하면 자동 적용:
- navigationTitle ~27개
- Button labels ~40개
- Section headers ~31개
- Text labels 다수

### 영어 유지 (번역 제외)

- **AppSection 탭 타이틀**: Today, Activity, Wellness, Life → 브랜드/앱 고유 용어로 취급
- **운동 이름**: Bench Press, Squat 등 → 국제 피트니스 표준 영어 유지

### 이미 양호한 영역

- BodyPart, ExerciseCategory, MuscleGroup, InjurySeverity 등 주요 enum: `String(localized:)` 적용 완료
- Validation/Error 메시지: `String(localized:)` 적용 완료
- QuickStartPopularityService 한국어: 데이터 정규화용 (사용자 비노출), 수정 불필요
- 총 473개 `String(localized:)` 인스턴스 사용 중

## Proposed Approach

### Phase 1: 코드 수정 (displayName 래핑)

5개 파일의 11개 문자열에 `String(localized:)` 래핑 추가.

### Phase 2: xcstrings 번역 추가

xcstrings 파일에서 ko/ja 번역이 누락된 키를 찾아 번역 추가.
- SwiftUI 자동 추출 키 (Text, Button, navigationTitle 등)
- Phase 1에서 추가한 displayName 키

### Phase 3: 탭 타이틀 영어 고정 확인

AppSection.title이 모든 locale에서 영어로 표시되는지 확인.
- `title` 프로퍼티가 `String` 반환 → SwiftUI `Tab(section.title, ...)` 에서 자동 localize 되지 않음 확인
- 또는 xcstrings에서 해당 키의 번역을 영어로 유지

## Constraints

- **기술적**: iOS 26+ / Swift 6 / xcstrings 단일 소스
- **규칙**: 약어(HIIT, BMI 등)도 `String(localized:)` 래핑 필수 (localization.md)
- **규칙**: 구조화된 키 금지, 영어 텍스트 = 키 (localization.md)

## Scope

### MVP (이번 작업)
- displayName `String(localized:)` 래핑 (5개 파일, 11개 문자열)
- iOS xcstrings 누락 번역 추가 (ko/ja)
- 탭 타이틀 영어 고정 확인

### Future
- watchOS xcstrings 동기화
- 번역 커버리지 자동 검증 스크립트
- Dynamic Type + 긴 번역 레이아웃 테스트

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] `/work` 로 실행
