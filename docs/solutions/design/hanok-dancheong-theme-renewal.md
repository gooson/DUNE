---
tags: [theme, hanok, dancheong, color-palette, animation, wave-background]
date: 2026-03-05
category: solution
status: implemented
---

# 한옥 테마 단청 리뉴얼

## Problem

한옥 테마가 earth-tone 갈색 위주(#d3a474 accent, #8a6913 mid)로 구성되어 한옥의 전통적인 옥색(jade)/단청 색감이 부족했음. 배경 애니메이션도 단순 drift만 있어 유기적인 느낌이 없었음.

## Solution

### 1. 색상 팔레트 전환 (27 colorset)

| 카테고리 | 이전 | 이후 | 근거 |
|---------|------|------|------|
| Primary (Accent/Mid/Mist) | 갈색/베이지 | 옥색/jade (#5B9E8F, #3A7D6E) | 한옥 단청의 녹색 기조 |
| Score | 갈색 gradient | 오방색: 적(#C83F23), 녹(#5B9E8F), 황(#D4A843), 청(#2B5279), 흑(#3A3A3A) | 단청 오방색 체계 |
| Deep/Bronze | 갈색 어두운 톤 | 짙은 녹색(#1E3A3A) | 한옥 기와/서까래 |
| Weather | 일반 색상 | jade-tinted 변형 | 통일감 |

### 2. Breath Animation (바람 흔들림)

`HanokWaveOverlayView`에 `breathIntensity` 파라미터 추가:
- `@State breathPhase` + `.task(id: breathIntensity)` 패턴
- `easeInOut(duration:).repeatForever(autoreverses: true)` 애니메이션
- `modulatedAmplitude = amplitude * (1 + breathIntensity * sin(breathPhase))`
- 레이어별 차등 강도: Far=0.05, Mid=0.08, Near=0.12

### 3. 한지 텍스처 색조

`HanjiTextureView` fiber 색상을 cream(0.95, 0.90, 0.82) → jade(0.82, 0.92, 0.88)로 변경.

## Key Decisions

1. **기존 asset 이름 유지**: `HanokAccent`, `HanokMid` 등 이름은 변경하지 않고 색상값만 교체 → 코드 변경 최소화
2. **breathIntensity default=0**: 기존 호출부 영향 없음, 한옥 테마만 사용
3. **`.task(id: breathIntensity)`**: 정적 문자열 대신 실제 값을 task ID로 사용 (Correction Log 규칙 준수)
4. **레이어별 breath 차등**: parallax 효과와 결합하여 깊이감 강화

## Prevention

- 새 애니메이션 추가 시 `.task(id:)` 키는 반드시 content-aware 값 사용 (정적 문자열 금지)
- 테마 색상 변경은 항상 light/dark 양쪽 검증
- xcassets 색상 변경은 Python batch 스크립트로 일괄 처리 (수작업 오류 방지)
