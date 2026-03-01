---
tags: [wave, theme, animation, dark-mode, desert, ocean, forest, visual]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: 테마별 웨이브 그래픽 및 애니메이션 고도화

## Problem Statement

각 테마(Desert/Ocean/Forest)의 웨이브가 테마 이름에 걸맞은 독자적 개성을 충분히 전달하지 못하고 있으며, 특히 다크모드에서 Forest 테마의 가시성이 심각하게 떨어진다.

### 현재 상태 요약

| 테마 | Shape | 레이어 | 특수 효과 | 정체성 수준 |
|------|-------|--------|----------|------------|
| Desert | 단순 sine wave | 1 (+ optional secondary) | 없음 | **낮음** — 기본 sine, 사막 느낌 없음 |
| Ocean | Harmonic-enriched sine | 3 (parallax) | Curl crests, foam, stroke | **높음** — 이미 파도 느낌 |
| Forest | Ridge-line + triangle pulse | 3 (parallax) | Ukiyo-e grain texture | **중간** — 실루엣은 독특하나 다크모드 불가 |

### 핵심 문제

1. **Forest 다크모드 가시성 부재**: ForestDeep dark RGB(0.059, 0.180, 0.122)에 opacity 0.14 → 검정 배경에서 실질 alpha ~0.02 수준으로 거의 투명
2. **Desert 정체성 부재**: 단순 sine wave 1개로는 "사막"을 연상할 수 없음. Ocean/Forest 대비 시각적 빈약
3. **Ocean 역동성 부족**: 3-layer parallax는 있으나 curl이 미묘하여 "큰 파도"의 역동성이 부족

## Target Users

- 앱 사용자: 테마 선택 시 각 테마가 명확히 구분되는 시각적 경험을 기대
- 다크모드 사용자: 전체 사용자의 상당수 (iOS 기본 다크모드 비율 높음)

## Success Criteria

1. **Forest 다크모드**: 3개 레이어가 모두 식별 가능 (배경 대비 충분한 명도차)
2. **Desert 정체성**: 스크린샷만으로 "사막/모래언덕" 연상 가능
3. **Ocean 역동성**: 표면 레이어 curl이 드라마틱하게 부서지는 느낌 전달
4. **성능 유지**: 현재 프레임레이트/배터리 소모 수준 유지 (path 연산 증가 최소화)

## 분석: 각 테마별 개선 방향

---

### A. Forest — 다크모드 가시성 + 분위기 강화

**근본 원인**: 다크모드 색상 자체가 너무 어둡고, opacity까지 낮아서 이중으로 투명해짐.

| 레이어 | 색상 (dark) | opacity | 실질 가시도 |
|--------|------------|---------|-----------|
| Near (ForestDeep) | RGB(0.059, 0.180, 0.122) | 0.14 | 거의 보이지 않음 |
| Mid (ForestMid) | RGB(0.137, 0.302, 0.196) | 0.10 | 겨우 보임 |
| Far (ForestMist) | RGB(0.561, 0.725, 0.588) | 0.06 | 희미하게 보임 |

**개선 방안:**

1. **다크모드 전용 색상 밝기 상향**: ForestDeep dark → RGB(0.15, 0.35, 0.22) 수준으로 밝게
   - 원래 light 모드의 ForestMid 수준으로 끌어올림
   - ForestMid dark도 비례하여 상향
   - Asset catalog 수정만으로 코드 변경 없음

2. **다크모드 전용 opacity 부스트**: `@Environment(\.colorScheme)` 감지하여 다크모드에서 opacity 계수 1.5~2x
   - 장점: 색상과 독립적으로 제어 가능
   - 단점: 코드 분기 추가 (현재 colorScheme 분기 없는 설계)

3. **밤 숲 분위기 — 달빛/반딧불 효과**:
   - 다크모드에서 실루엣 상단에 은은한 달빛 림라이트 (얇은 밝은 stroke)
   - 또는 ForestMist를 다크모드에서 약간 파란빛으로 전환 → "달빛 비추는 먼 산"
   - 숲의 다크모드 = "밤 숲"으로 재해석

4. **추천 조합**: 방안 1(색상 밝기 상향) + 방안 3(밤 숲 분위기) 병행
   - 색상 상향으로 기본 가시성 확보
   - 달빛 림라이트로 다크모드만의 독자적 분위기 부여

---

### B. Desert — 모래 언덕 정체성 부여

**현재**: `WaveShape` (단순 sine wave) 1개 + optional secondary. 어떤 테마인지 모름.

**개선 방향: "모래 언덕 + 사막 바람"**

1. **DesertDuneShape 신규 Shape 생성**:
   - 비대칭 dune profile: 바람맞이쪽(windward) 완만, 바람등쪽(leeward) 급경사
   - 수학적 모델: `sin(angle) + skew * sin(2*angle)` (skew로 비대칭 제어)
   - 참고: Ocean의 harmonic enrichment 패턴 재활용 가능

2. **Multi-layer parallax (2~3층)**:
   - Far: 넓고 완만한 큰 언덕 (저주파, 느린 drift)
   - Near: 작은 모래 물결 / ripple (고주파, 빠른 drift)
   - 깊이감 확보 + 사막의 광활함 표현

3. **사막 바람 효과**:
   - 표면 레이어에 미세한 고주파 ripple (sand ripple) 추가
   - 또는 wind particle effect (매우 가벼운 점 몇 개가 바람 방향으로 이동)

4. **열기/아지랑이 효과** (nice-to-have):
   - shimmer overlay: 투명한 노이즈 레이어가 느리게 흔들림
   - 단, 성능 주의 — pre-rendered 텍스처 사용 (Forest grain과 동일 패턴)

5. **추천 조합**: 방안 1(비대칭 dune shape) + 방안 2(2-layer parallax)
   - 최소 변경으로 최대 정체성 확보
   - 기존 `WaveShape`는 유지하고 Desert 전용 shape 추가

---

### C. Ocean — 파도 역동성 강화

**현재**: 3-layer parallax + curl + foam + stroke. 이미 가장 정교함.

**개선 방향: "더 드라마틱한 파도"**

1. **Curl 크기 증가**:
   - 현재 `curlHeight: 1.5` → 2.0~2.5로 상향
   - `curlWidth: 0.1` → 0.12~0.15로 넓혀서 더 넓은 curl 곡선
   - 코드 변경 없이 파라미터 조정만

2. **Curl 개수 증가**:
   - 현재 surface layer만 `curlCount: 1` (life=0)
   - → 기본 2개, train=3개로 상향하여 역동적인 바다 표현

3. **Foam/거품 강화**:
   - foam opacity 증가 + foam depth 증가
   - 부서지는 파도 아래 흰 거품이 더 넓고 뚜렷하게

4. **Wave amplitude/steepness 파라미터 미세 조정**:
   - Surface layer의 `steepness` 상향 → 더 날카로운 파봉
   - `crestSharpness` 상향 → 고주파 디테일 강화
   - 파라미터 조정만으로 코드 변경 최소화

5. **추천 조합**: 방안 1(curl 파라미터 상향) + 방안 3(foam 강화) + 방안 4(steepness 미세 조정)
   - 새 Shape 생성 없이 기존 파라미터 튜닝으로 역동성 대폭 향상

---

## Constraints

### 기술적 제약
- **성능**: `path(in:)` 호출은 애니메이션 프레임마다 실행됨. 샘플 수 증가는 최소화
- **배터리**: watchOS도 동일 테마 적용 — Watch에서도 원활해야 함
- **pre-computation**: 현재 패턴 유지 — init 시 연산, path는 sin + scale만
- **Asset catalog 규칙**: 색상은 xcassets, Color(red:green:blue:) 인라인 금지

### 설계 제약
- **DS.Opacity 범위**: 다크모드 배경 gradient opacity >= 0.06 (Correction #127, #128)
- **colorScheme 분기 최소화**: 현재 코드에 colorScheme 분기 없음. Asset catalog에 위임하는 패턴 유지 권장
- **Watch 동기**: iOS 변경 시 Watch도 동기화 (Correction #69, #138)

## Edge Cases

- **Reduce Motion**: `accessibilityReduceMotion` 존중 — 이미 `guard !reduceMotion` 패턴 적용됨
- **Weather 오버라이드**: Today 탭에서 날씨 색상이 테마 색상을 대체할 때 가시성 확인 필요
- **Theme 전환 애니메이션**: `.id(theme)` 기반 — 새 Shape 추가 시에도 이 패턴 유지
- **iPad multitasking**: compact size에서도 레이어 구분 가능해야 함

## Scope

### MVP (Must-have)

#### Forest 다크모드 가시성 (P1)
- [ ] ForestDeep/ForestMid/ForestMist 다크모드 색상 밝기 상향 (Asset catalog)
- [ ] Tab/Detail/Sheet 모든 계층에서 다크모드 가시성 검증
- [ ] Weather 오버라이드 시에도 가시성 유지 확인

#### Desert 테마 정체성 (P1)
- [ ] `DesertDuneShape` 생성: 비대칭 sand dune profile
- [ ] 2-layer parallax: Far(큰 언덕) + Near(sand ripple)
- [ ] `DesertTabWaveBackground` / Detail / Sheet 구현
- [ ] Watch용 간소화 버전

#### Ocean 역동성 강화 (P2)
- [ ] Surface layer curl 파라미터 상향 (curlHeight, curlCount, curlWidth)
- [ ] Foam opacity/depth 증가
- [ ] Steepness/crestSharpness 미세 조정
- [ ] Tab preset별 역동성 차등 확인 (train > today > wellness > life)

### Nice-to-have (Future)
- Forest 다크모드 달빛 림라이트 stroke
- Forest 반딧불 파티클 효과
- Desert 아지랑이(shimmer) 텍스처 오버레이
- Desert 바람 파티클 (모래 알갱이 날림)
- Ocean 파도 부서짐 후 물보라(spray) 파티클
- 테마별 Weather condition과 wave 상호작용 고도화

## Open Questions

1. **Desert layer 수**: 2-layer로 충분한가, 3-layer까지 갈 것인가?
   - 2-layer 추천: Desert은 Ocean/Forest보다 단순한 지형이므로 과도한 레이어는 부자연스러움
2. **Forest 다크모드 접근법**: 색상만 밝히는 것으로 충분한지, opacity 부스트도 병행할지?
   - 색상 밝히기 우선 → 불충분 시 opacity 추가 조정
3. **Ocean curl 개수**: 모든 탭에서 2개? life 탭은 현재 0인데 1로 올릴지?
   - life="잔잔한 호수" 컨셉이므로 0 유지 추천
4. **Watch 적용 범위**: Desert/Forest shape 변경을 Watch에도 동일 적용? 성능 테스트 필요

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] Forest 다크모드 색상 후보 선정 + 스크린샷 비교
- [ ] DesertDuneShape 수학적 모델 프로토타이핑
