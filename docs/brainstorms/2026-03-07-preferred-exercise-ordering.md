---
tags: [settings, exercise, quick-start, watch, ios, preferences]
date: 2026-03-07
category: brainstorm
status: approved
---

# Brainstorm: Preferred Exercise Ordering

## Problem Statement

현재 Quick Start 계열 화면은 `Popular`/`Recent` 중심으로 노출되지만, 사용자가 직접 "자주 쓰는 운동"을 고정하는 개념이 없다. 그 결과 iPhone 앱과 Apple Watch에서 원하는 운동을 반복적으로 빠르게 찾기 어렵다.

## Target Users

- 반복적으로 같은 운동 몇 개를 빠르게 시작하는 사용자
- iPhone과 Watch 양쪽에서 동일한 Quick Start 우선순위를 기대하는 사용자
- 설정에서 선호 운동을 한 번 정해 두고 계속 재사용하고 싶은 사용자

## Success Criteria

1. 설정에서 선호 운동을 쉽게 찾고 지정할 수 있다.
2. iPhone과 Watch 모두 `Recent → Preferred → Popular` 순서를 동일하게 적용한다.
3. 같은 운동이 여러 섹션에 중복 노출되지 않는다.
4. Watch 기존 루틴 카드는 유지하되, 그 다음 운동 추천 순서만 새 정책으로 바뀐다.

## Proposed Approach

### 1. 설정 UX

- `Settings`에 전용 진입점 `Preferred Exercises`를 추가한다.
- 동시에 기존 `Exercise Default` 편집 화면에도 `Preferred Exercise` 토글을 추가한다.
- 전용 화면과 편집 화면 둘 다 제공해 discoverability와 편의성을 같이 확보한다.

### 2. 저장 모델

- 기존 `ExerciseDefaultRecord`에 `isPreferred` 플래그를 추가한다.
- 선호 운동만 설정한 경우에도 record를 유지해 Quick Start와 Watch sync에서 공통으로 재사용한다.
- 기존 per-exercise defaults 아키텍처와 같은 저장소를 써서 CloudKit 동기화 패턴을 유지한다.

### 3. 노출 우선순위

- iPhone Quick Start 허브: `Recent → Preferred → Popular`
- Watch 홈 캐러셀: `Routine → Recent → Preferred → Popular → All Exercises`
- Watch 전체 운동 화면: 상단 우선 섹션도 동일하게 `Recent → Preferred → Popular`

## Constraints

- `ExerciseDefaultRecord` 변경은 SwiftData schema migration이 필요하다.
- Watch exercise library payload는 iPhone과 Watch target 양쪽 DTO를 함께 바꿔야 한다.
- cached application context에 이전 payload가 남아 있을 수 있으므로 Codable backward compatibility가 필요하다.

## Edge Cases

- 선호 운동이 recent에도 있으면 recent에만 노출한다.
- 선호 운동이 popular에도 있으면 preferred에만 노출한다.
- 선호 운동만 있고 default weight/reps가 없는 경우에도 설정 레코드는 유지한다.
- 과거 variant ID로 저장된 record는 canonical representative exercise로 정규화해 표시한다.
- Watch가 구버전 payload를 decode할 때 `isPreferred` 키가 없어도 실패하지 않아야 한다.

## Scope

### MVP (Must-have)

- [x] 전용 `Preferred Exercises` 진입점
- [x] `Exercise Default` 편집 화면의 선호 토글
- [x] iPhone/Watch Quick Start 순서 통일
- [x] canonical 중복 제거
- [x] Watch sync 반영

### Nice-to-have (Future)

- [ ] 선호 운동 drag reorder
- [ ] 선호 운동 개수 제한/추천 배지
- [ ] 선호 운동만 별도 위젯/컴플리케이션 연결

## Open Questions

- 섹션 제목은 구현자가 결정한다.
- Watch 루틴 카드는 유지하고 운동 추천 순서만 변경한다.

## Next Steps

- [x] `/run`으로 구현, 검증, 리뷰, 문서화까지 진행
