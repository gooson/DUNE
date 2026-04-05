---
name: copy-voice
description: "문서와 UI 텍스트의 톤앤매너 가이드. 단어 선택, 메시지 패턴. 사용자 대면 텍스트 작성 시 자동으로 참조됩니다."
---

# Copy & Voice Guide — DUNE Health App

## Tone

- **Calm & Supportive**: 건강 데이터를 판단 없이 전달
- **Data-Informed**: 수치 기반이되 위협적이지 않게
- **Concise**: 짧고 명확한 문장, 불필요한 수식어 최소화
- **Korean-first**: UI 텍스트는 한국어, 단위/약어는 영어 유지

## Principles

1. **사실 전달, 판단 최소화**: "컨디션이 나쁩니다" → "평소보다 낮은 수치입니다"
2. **행동 유도보다 정보 제공**: "운동하세요" → "회복이 충분합니다"
3. **짧은 문장**: 카드 UI에 맞게 1-2줄 이내
4. **숫자는 항상 formattedWithSeparator 경유**: 1000 → 1,000

## Word Choices

### Preferred Terms
| Instead of | Use |
|-----------|-----|
| 에러/오류 | 데이터를 불러올 수 없습니다 |
| 실패 | 다시 시도해 주세요 |
| 성공적으로 저장됨 | 저장되었습니다 |
| 잘못된 입력 | {필드}를 확인해 주세요 |
| 없음/N/A | — (em dash) |
| 나쁨/위험 | 평소보다 낮음 |
| 좋음/최고 | 평소보다 높음 |

### Words to Avoid
- "위험", "경고" — 의료 앱이 아니므로 공포 유발 금지
- "완벽", "최고" — 과장 표현 금지
- "실패했습니다" — 사용자 탓으로 느껴지는 표현

## Score Display

- 점수 범위: 0-100
- 점수가 없을 때: "--" (double dash)
- 점수 라벨: "컨디션", "수면 점수", "신체 점수" (한국어)
- 변화량: "+3", "-5" (부호 항상 표시), 변화 없음은 표시 안 함

## Error Messages

- Pattern: **무엇이 안 됐는지 + 어떻게 하면 되는지**
- 예시: "수면 데이터를 불러올 수 없습니다. Apple Health 권한을 확인해 주세요."
- Empty state에서 비난 금지: "데이터가 없습니다" → "아직 기록이 없습니다"

## Empty States

- Pattern: **상태 설명 + 행동 제안** (강요하지 않음)
- 예시: "아직 운동 기록이 없습니다. Apple Watch로 운동하면 자동으로 기록됩니다."
- 첫 사용자 시나리오 항상 고려

## watchOS 텍스트 가이드

- 카드/레이블: 최대 2단어 (화면이 좁아 긴 문장 불가)
- 빈 상태: "기록 없음" 수준의 초간결 메시지
- 알림: 핵심 정보만 (예: "운동 완료 · 12세트")
- 버튼: 아이콘 우선, 텍스트는 1단어

## Pluralization (ko/ja)

한국어와 일본어는 영어와 달리 단수/복수 구분이 거의 없으므로 별도 plural rule이 불필요한 경우가 많습니다.

| 언어 | 복수형 | 예시 |
|------|--------|------|
| en | `%lld days` (plural variation 필요) | "1 day" / "3 days" |
| ko | `%lld일` (단수=복수 동일) | "1일" / "3일" |
| ja | `%lld日` (단수=복수 동일) | "1日" / "3日" |

- 영어에서 plural variation이 필요한 경우 xcstrings의 `variations.plural` 기능 사용
- ko/ja는 대부분 단일 형태로 충분. 예외: 조사 변화 ("1개를" vs "3개를" — 한국어 조사는 숫자가 아닌 앞 글자의 받침에 의존)
- 숫자+단위 패턴은 `%lld` 보간으로 통일: `String(localized: "\(count) sets completed")`

## Dynamic Type & Translation Length

번역된 텍스트는 영어보다 길어질 수 있으며, Dynamic Type 확대 시 더 심해집니다.

| 언어 | 영어 대비 길이 | 주의 영역 |
|------|---------------|----------|
| ko | 80-120% | 조사가 붙으면 영어보다 길어질 수 있음 |
| ja | 60-100% | 한자가 짧지만, 히라가나 설명은 길어짐 |

- **카드 UI**: 최대 너비 제한이 있는 곳에서는 `.lineLimit(2)` + `.minimumScaleFactor(0.8)` 방어
- **버튼 레이블**: 2단어 이내 유지 (ja는 특히 4글자 이내)
- **Dynamic Type Accessibility 크기**: xxxLarge 이상에서 레이아웃 확인 필수
- 긴 번역이 예상되는 곳은 `fixedSize(horizontal: false, vertical: true)` 로 세로 확장 허용

## Units & Formatting

- 체중: kg (소수점 1자리)
- 심박수: bpm (정수)
- HRV: ms (정수)
- 수면: 시간 분 (예: "7시간 30분")
- 볼륨: kg (정수, 천단위 구분)
- 거리: km (소수점 1자리)
