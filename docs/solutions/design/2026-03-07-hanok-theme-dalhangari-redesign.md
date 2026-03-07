---
tags: [hanok, theme, dalhangari, wave, animation, swiftui, design-system]
date: 2026-03-07
category: solution
status: implemented
---

# Hanok Theme Redesign: 달항아리 Moon Jar Curves

## Problem

Hanok 테마가 시각적으로 조잡하게 보이는 문제:
1. 과도한 장식 요소 (산, 지붕 문양, 한지 텍스처, 격자 패턴 등 6개 decorative shapes)
2. 탁한 jade/slate 색상 팔레트
3. 단순 sine 파형으로 한옥 곡선 특성 미표현
4. 요소 간 시각적 조화 부재

## Solution

### 디자인 철학: Modern Korean Minimalism

- **달항아리 (Moon Jar)** 비대칭 곡선: 완벽하지 않은 자연스러운 비대칭이 핵심
- **수묵 (Ink Wash)** 색상 팔레트: ink → celadon → ivory 그라데이션
- **여백의 미**: 장식 요소 전면 제거, 파형과 그라디언트만으로 깊이감 표현

### 핵심 구현

#### 1. DalhangariWaveShape — 비대칭 유기적 파형

```swift
// 기본 비대칭: sin(angle) * (1 + asymmetry * sin(angle/3))
// 유기적 변주: + organicBlend * sin(3*angle + phase)
// 미세 불규칙: + 0.15 * sin(0.5*angle + phase/3)
```

- `asymmetry` 파라미터: 달항아리 특유의 좌우 비대칭
- `organicBlend` 파라미터: 3차 하모닉스로 도자기 표면의 미세 굴곡
- WaveSamples 캐시: frequency 기반 static 캐시로 `path(in:)` 성능 보장

#### 2. 3-Layer Parallax 시스템

| Layer | 역할 | opacity | driftDuration |
|-------|------|---------|---------------|
| Far | 원경 수묵 안개 | 0.08 | 28s |
| Mid | 달항아리 시그니처 곡선 | 0.18 | 22s |
| Near | 전경 깊이 + 수묵 번짐 크레스트 | 0.45 | 18s |

#### 3. Breath Modulation — 단일 phase 파생

별도 `@State breathPhase` 대신 기존 drift phase에서 파생:
```swift
amplitude * (1 + breathIntensity * sin(phase * 0.13))
```
- irrational ratio (0.13)로 base wave와 주기 정렬 방지
- 별도 애니메이션 드라이버 불필요 (6→3 for tab background)

#### 4. Ink-Wash Crest Highlight

```swift
// 넓은 반투명 번짐 (ink wash blur)
shape.stroke(crestColor.opacity(crestOpacity * 0.48), lineWidth: crestWidth * 2.6)
    .blur(radius: 1.1)
// 코어 하이라이트 라인
shape.stroke(crestColor.opacity(crestOpacity), lineWidth: crestWidth)
    .blur(radius: 0.25)
```
- `.drawingGroup()` + `.blendMode(.screen)`으로 GPU 오프로드
- gradient mask로 하단 자연 소멸

#### 5. 색상 팔레트 (27 colorsets)

| 카테고리 | 색상 | Light | Dark |
|---------|------|-------|------|
| 수묵 ink | HanokInk | #2C2C2E | #1C1C1E |
| 청자 celadon | HanokCeladon | #A8C5B8 | #7A9E8A |
| 백자 ivory | HanokIvory | #F5F0E8 | #3A3632 |
| 먹 번짐 mist | HanokMist | #B8C5C8 | #4A5558 |
| 중간톤 mid | HanokMid | #8FA5A0 | #5A7570 |
| 깊은톤 deep | HanokDeep | #6B8580 | #3D5550 |

## Prevention

### 테마 디자인 시 체크리스트
- [ ] 장식 요소 3개 이하로 제한
- [ ] 색상 팔레트는 3-color harmony 기반
- [ ] 파형 알고리즘에 비대칭/유기적 파라미터 포함
- [ ] `.drawingGroup()` 사용하여 blur/blendMode GPU 오프로드
- [ ] 별도 animation @State 최소화 — 기존 phase에서 파생 가능한지 먼저 검토
- [ ] `.task(id:)` AnimationKey에 animation 동작에 영향을 주는 모든 프로퍼티 포함

### 수묵 breath 패턴 재사용
irrational ratio 기반 breath modulation은 다른 테마의 유기적 움직임에도 적용 가능.
별도 @State 없이 기존 animation phase에서 파생하면 animation driver 수를 절반으로 줄일 수 있음.
