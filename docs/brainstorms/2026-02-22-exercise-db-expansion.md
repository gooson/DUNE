---
tags: [exercise, database, equipment, technogym, alias, muscle-map, expansion]
date: 2026-02-22
category: brainstorm
status: draft
---

# Brainstorm: 운동 및 장비 데이터베이스 대규모 확장

## Problem Statement

현재 127개 운동, 8개 장비 타입으로는 사용자가 헬스장에서 마주하는 실제 운동/기구의 다양성을 충분히 커버하지 못함. 특히:

1. **장비 세분화 부족**: "machine"이라는 단일 카테고리에 체스트 프레스, 레그 프레스, 스미스 머신 등 수십 종류가 뭉쳐 있음
2. **Technogym 등 브랜드 장비 미지원**: 한국 대형 헬스장의 70%+ 가 Technogym/Life Fitness 장비 사용. 장비 이름이 다르면 운동을 못 찾음
3. **이미지 없음**: 텍스트만으로 "Pec Deck"과 "Cable Crossover"의 차이를 이해하기 어려움
4. **동의어/별명 없음**: "시티드 로우" = "Seated Cable Row" = "케이블 시티드 로우" — 검색에서 놓침

## Target Users

- **헬스 초보자**: 기구 이름을 모르거나, 한국어/영어 명칭이 혼란스러운 사용자
- **Technogym 헬스장 이용자**: 기구에 표시된 이름으로 운동을 찾고 싶은 사용자
- **다양한 운동 루틴 사용자**: 127개 이상의 운동 변형을 기록하고 싶은 중급+ 사용자
- **운동 기록 앱 전환자**: 기존 앱에서 사용하던 운동명으로 검색하는 사용자

## Success Criteria

1. **운동 수**: 127 → 500-800개 (주요 strength/cardio/flexibility 운동 커버)
2. **장비 타입**: 8 → 20-30개 (machine을 세분화 + 특수 장비 추가)
3. **별명 시스템**: 운동당 평균 2-3개 검색 가능한 alias (한/영 혼용)
4. **이미지**: 장비별 참고 이미지 + 운동별 근육 하이라이트 다이어그램
5. **검색 적중률**: 사용자가 입력한 운동명의 90%+ 가 기존 운동에 매칭

## Current State Analysis

### 현재 데이터베이스 구조

```json
{
  "id": "barbell-bench-press",
  "name": "Barbell Bench Press",
  "localizedName": "바벨 벤치프레스",
  "category": "strength",
  "inputType": "setsRepsWeight",
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["triceps", "shoulders"],
  "equipment": "barbell",
  "metValue": 5.0
}
```

### 현재 운동 분포 (127개)

| 카테고리 | 수 | 비율 |
|----------|-----|------|
| Strength | ~73 | 57% |
| Bodyweight | ~20 | 16% |
| Cardio | ~13 | 10% |
| HIIT | ~5 | 4% |
| Flexibility | ~5 | 4% |
| Compound/Olympic | ~11 | 9% |

### 현재 장비 타입 (8개)

`barbell`, `dumbbell`, `machine`, `cable`, `bodyweight`, `band`, `kettlebell`, `other`

### 부족한 영역

- **Machine 세분화**: smith machine, leg press, hack squat, cable tower, pec deck 등이 모두 "machine"
- **Technogym 특화 장비**: Selection line, Artis line, Pure Strength line 장비 이름 미반영
- **특수 장비**: TRX, 짐볼, 메디신볼, 폼롤러(기구로), 풀업바, 딥스바, 파워랙 등
- **운동 변형**: Incline/Decline/Close-grip 등 기본 변형 외에 Single-arm, Pause, Tempo 변형 미포함
- **스포츠/무술**: 복싱, 태권도, 크로스핏 WOD 등

## Decisions

| 항목 | 결정 | 근거 |
|------|------|------|
| 확장 규모 | 500-800 exercises | 주요 피트니스 앱(Strong, JEFIT) 수준 |
| 브랜드 접근 | 장비에 브랜드 없음, alias로 해결 | "Technogym Chest Press" → alias로 "chest-press-machine" 매칭 |
| 장비 세분화 | machine → 15+ 하위 타입 | smith-machine, cable-tower, leg-press-machine 등 |
| 이미지 전략 | 1) 근육 하이라이트 SVG, 2) 장비 일러스트 | 기존 MuscleMapView 확장 + 장비별 일러스트 |
| Alias 저장소 | exercises.json에 `aliases` 배열 추가 | 별도 파일보다 단일 소스 관리 용이 |
| Dedup 전략 | alias 기반 fuzzy matching + Levenshtein distance | false positive 최소화하면서 높은 적중률 |

## Proposed Approach

### Phase 1: 데이터 스키마 확장

**ExerciseDefinition 필드 추가:**

```json
{
  "id": "barbell-bench-press",
  "name": "Barbell Bench Press",
  "localizedName": "바벨 벤치프레스",
  "aliases": ["Flat Bench Press", "플랫 벤치", "Bench Press"],
  "category": "strength",
  "inputType": "setsRepsWeight",
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["triceps", "shoulders"],
  "equipment": "barbell",
  "metValue": 5.0,
  "difficulty": "intermediate",
  "tags": ["compound", "push", "powerlifting"]
}
```

**새 필드:**
- `aliases: [String]` — 검색용 별명 (한/영 혼합, optional)
- `difficulty: String` — "beginner" / "intermediate" / "advanced" (optional)
- `tags: [String]` — 검색 및 필터링용 자유 태그 (optional)

### Phase 2: Equipment 세분화

**현재 8개 → 25개+ 장비 타입:**

| 카테고리 | 새 장비 타입 | 설명 |
|----------|-------------|------|
| Free Weights | `barbell`, `dumbbell`, `kettlebell`, `ez-bar`, `trap-bar` | 기존 + EZ바, 트랩바 추가 |
| Machines | `smith-machine`, `leg-press-machine`, `hack-squat-machine`, `chest-press-machine`, `shoulder-press-machine`, `lat-pulldown-machine`, `cable-machine`, `pec-deck-machine`, `leg-extension-machine`, `leg-curl-machine`, `rowing-machine-gym` | "machine" 해체 → 구체적 기구 |
| Cable | `cable-tower`, `functional-trainer` | cable을 세분화 |
| Bodyweight | `bodyweight`, `pull-up-bar`, `dip-station`, `parallel-bars` | 맨몸 보조 기구 |
| Accessory | `band`, `trx`, `medicine-ball`, `stability-ball`, `foam-roller`, `ab-wheel`, `battle-rope` | 소도구 확장 |
| Cardio Machines | `treadmill`, `stationary-bike-machine`, `elliptical-machine`, `rowing-erg`, `stair-master`, `ski-erg` | cardio 장비 세분화 |
| Other | `bench`, `power-rack`, `plyo-box`, `other` | 보조 장비 |

**하위 호환성**: 기존 "machine" → 각 운동에 맞는 specific machine으로 migration. 기존 사용자의 custom exercise에서 "machine"을 사용 중이면 유지.

### Phase 3: 운동 대규모 추가

**목표 분포 (500-800 exercises):**

| 카테고리 | 현재 | 목표 | 추가 예시 |
|----------|------|------|----------|
| Strength | 73 | 300-400 | DB Incline Fly, Cable Rear Delt, Smith Machine Squat, ... |
| Bodyweight | 20 | 60-80 | Handstand Push-Up, Muscle-Up, L-sit, Pistol Squat, ... |
| Cardio | 13 | 40-60 | Assault Bike, Ski Erg, Sprints, Water Rowing, ... |
| HIIT | 5 | 30-40 | Thrusters (DB), Wall Balls, Kettlebell Snatch, ... |
| Flexibility | 5 | 30-50 | Cat-Cow, Pigeon Stretch, Hip Flexor Stretch, ... |
| Olympic | 6 | 20-30 | Snatch, Clean & Jerk, Hang Clean, Push Press, ... |
| Sports | 0 | 20-30 | Boxing Bag Work, Shadow Boxing, Swimming Drills, ... |

**데이터 수집 소스:**
- Wger Workout Manager (오픈소스 운동 DB, CC-BY-SA)
- ExRx.net 운동 분류 체계 참조 (구조만, 콘텐츠는 자체 작성)
- ACE/NASM 인증 교재의 운동 분류
- 직접 작성 (한국 헬스장 특화 운동)

### Phase 4: Alias 시스템 및 검색 개선

**Alias 규칙:**
1. 같은 운동의 다른 이름: "Bench Press" = "Flat Bench" = "벤치 프레스"
2. 약어: "RDL" → "Romanian Deadlift"
3. Technogym 장비명: "테크노짐 체스트 프레스" → "chest-press-machine" 운동 매칭
4. 한국식 표기 변형: "스쿼트" = "스콰트" = "squat"

**검색 알고리즘 개선:**
```
1. Exact match (id, name, localizedName)
2. Alias match (aliases 배열 순회)
3. Fuzzy match (Levenshtein distance ≤ 2)
4. Keyword match (태그 기반)
5. No match → CustomExercise 생성 유도
```

### Phase 5: 이미지 전략

**두 종류의 이미지:**

1. **근육 하이라이트 다이어그램** (기존 MuscleMapView 활용)
   - 운동별 primaryMuscles → 진한 색, secondaryMuscles → 연한 색
   - SVG Path 기반, 앱 번들에 포함 (용량 최소)
   - 이미 brainstorm 존재: `2026-02-17-exercise-visual-guide.md`

2. **장비 참고 일러스트**
   - 각 Equipment 타입별 1장의 벡터 일러스트
   - 용도: ExercisePickerView에서 장비 필터 시 + ExerciseDetailSheet
   - 형태: SF Symbols 우선, 부족한 것은 커스텀 SVG
   - **Technogym 등 브랜드 이미지 사용 불가** → 일반적 기구 형태의 일러스트

## Constraints

- **JSON 파일 크기**: 800개 운동 × ~200B = ~160KB. 번들 크기에 미미한 영향
- **하위 호환성**: 기존 `ExerciseRecord`는 `exerciseDefinitionID: String`으로 참조. ID 변경 불가
- **Equipment enum 확장**: Equipment enum에 case 추가 시 CaseIterable 코드, switch 문, View extension 전체 업데이트 필요
- **CloudKit 스키마**: ExerciseRecord의 `rawEquipment: String` 필드는 자유 문자열이므로 Equipment enum 확장에 영향 없음
- **테스트**: ExerciseLibraryService에 기존 테스트 있으면 새 데이터 추가 시 업데이트 필요
- **번역**: 500-800개 운동의 한국어 localizedName 필요

## Edge Cases

1. **기존 사용자의 "machine" equipment**: migration 스크립트로 specific machine으로 매핑하되, 매핑 불가 시 "machine" 유지
2. **CustomExercise와 새 운동 ID 충돌**: 사용자가 이미 "smith-machine-squat"이라는 custom exercise를 만든 경우 → dedup 로직 필요
3. **alias false positive**: "row" → "Barbell Row"와 "Rowing Machine" 둘 다 매칭. 컨텍스트 기반 우선순위 필요
4. **MET 값 정확도**: 운동 변형별 MET 값이 다를 수 있음 (Pause Squat vs. Regular Squat). 기본값 사용 + 사용자 오버라이드 허용
5. **없는 근육 그룹**: 현재 13개 MuscleGroup으로 일부 운동 커버 불가 (예: hip flexors, rotator cuff). 향후 MuscleGroup 확장 필요할 수 있음

## Scope

### MVP (Must-have)

- [ ] ExerciseDefinition에 `aliases` 필드 추가 (optional `[String]?`)
- [ ] ExerciseDefinition에 `difficulty` 필드 추가 (optional `String?`)
- [ ] ExerciseDefinition에 `tags` 필드 추가 (optional `[String]?`)
- [ ] Equipment enum 세분화 (8 → 25개)
- [ ] Equipment+View.swift 에 새 장비의 displayName, localizedName, icon, description 추가
- [ ] exercises.json 확장 (127 → 500+ exercises)
- [ ] 각 운동에 2-3개 aliases 추가 (한/영 혼합)
- [ ] ExerciseLibraryService 검색에 alias 매칭 추가
- [ ] 기존 운동의 equipment 값을 세분화된 타입으로 migration
- [ ] 하위 호환 처리: 기존 "machine" 값 → fallback 로직

### Nice-to-have (Future)

- [ ] Levenshtein distance 기반 fuzzy search
- [ ] 장비별 벡터 일러스트 이미지
- [ ] 운동별 동작 GIF/애니메이션
- [ ] 사용자 기여 alias 시스템 (CloudKit 공유)
- [ ] MuscleGroup 확장 (hip flexors, rotator cuff, adductors, abductors)
- [ ] 운동 난이도 기반 추천 시스템
- [ ] 대체 운동 추천 (같은 근육, 다른 장비)

## Open Questions

1. **Equipment migration 전략**: 기존 사용자의 ExerciseRecord에서 "machine"으로 저장된 기록 → 각 운동의 새 equipment로 자동 migration? 아니면 "machine"을 legacy로 유지하고 새 운동만 세분화된 타입 사용?
2. **MuscleGroup 확장 타이밍**: 500+ 운동 추가 시 hip flexors/rotator cuff 등이 필요한 운동이 상당수. 이번에 같이 확장할지, 별도 작업으로 분리할지?
3. **한국어 번역 품질 보장**: 500개 운동의 localizedName 품질을 어떻게 검증할지? (헬스 커뮤니티 표준 용어 사용)
4. **JSON 파일 분할**: 800개 운동을 단일 exercises.json에 넣을지, category별로 분할할지?

## Next Steps

- [ ] `/plan exercise-db-expansion` 으로 상세 구현 계획 생성
- [ ] Equipment enum 확장 → 영향 범위 파악 (switch 문 등)
- [ ] 운동 데이터 수집 및 JSON 생성 작업
