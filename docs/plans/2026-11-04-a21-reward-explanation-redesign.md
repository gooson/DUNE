---
tags: [a21, rewards, swiftui, native-sheet, dynamic-type]
date: 2026-11-04
category: plan
status: implemented
---

# A21 보상 설명 개편과 실제 화면 검증

앱 검증 소스는 `9208e68ca8f2cd1b9e209fd7c9fb40a8164547ef`다. 원본 iPhone 1/1과 개편 선택 검사 6/6을 구분해 보존했다. [실제 전후 비교](../design/full-redesign-map/review/a21-reward-help-native-2026-11-04/index.html)에는 단일 원본 iPhone, 네 기기·자세의 개편 화면, 큰 글씨와 알림 진입 증거를 담았다.

## 목적과 영향 파일

기존 네 설명을 제목 히어로와 아이콘별 불투명 카드로 강조한다. 별·메달·트로피·깃발, 기존 정보 버튼, 중간 높이 시스템 시트와 스크롤·닫기를 보존한다. 실제 보상 경로에 맞게 설명만 고치며 점수·배지 계산과 저장은 유지한다.

| 파일 | 역할 |
|---|---|
| `DUNE/Presentation/Activity/PersonalRecords/Components/RewardProgressSection.swift` | 기존 private 설명 시트, 공통 팔레트·카드·제목 접근성 |
| `Shared/Resources/Localizable.xcstrings` | 수정한 설명 세 문장의 수동 en/ko/ja 번역 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Activity 진입, 전체 본문 읽기, 기본·최대 글씨, 실제 닫기·복귀 |
| `DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift` | 실제 알림 Personal Records 소비자의 열기·닫기·뒤로 복귀 |
| `docs/design/phone-design-map/` | 실제 inline 시트 A21 등록, 네 기기 맵·보드 갱신 |
| `docs/design/layout-map/`, `docs/design/theme-map/` | 배치·표현 계약과 실제 결과 연결 |

## 구현 단계와 기준

1. 실제 머지된 A20 기반에서 원본 `495d93be` iPhone을 먼저 촬영하고 1/1 SDK·PNG·AX를 보존했다. 일회성 원본 테스트는 보존·기기 정리 뒤 제거했다.
2. `ScoreHeroPalette`와 기존 네 SF Symbol을 재사용했다. 본문은 카드 전체 폭에서 자연스럽게 줄바꿈하고 최대 콘텐츠 폭680pt를 둔다. 고정 본문 높이나 글자 축소를 추가하지 않았다.
3. 새 활동 마일스톤과 새 유산소 PR의 포인트, 레벨당200점, 근력 최고 기록의 표시, 운동일 기준 배지를 설명한다. 원래 계산 경로의 마일스톤40점·유산소 PR60점·레벨200점은 바꾸지 않았다.
4. 실제 두 소비자(Activity와 알림) 및 iPhone·iPad·Duo 접힘·펼침을 확인했다. 큰 글씨는 정확한 전체 라벨·폭·겹치는 읽기 구간·앞/끝 도달·양의 진행을 검사한다. 진행 제스처는 실제 보이는 텍스트 구간 안에서 시작한다. 기본 시스템 손잡이로 닫고 원래 화면 복귀를 확인한다.
5. 누락됐던 실제 inline A21을 등록해 맵은110→111행이 됐다. 기존 모든 행과 Activity20개 타일의 픽셀은 보존했다. 네 A21 이미지를 새로 만들고 기존15개 출력만 갱신했다.

## 핵심 검증과 제한

| 범위 | 실제 결과 |
|---|---|
| 원본 iPhone `495d93be` | 1/1, 개편 검사와 별도 |
| 개편 Duo 접힘 | 기본·어두운 최대 글씨2/2 |
| 개편 Duo 펼침 | 기본1/1, 180°/LCD-1 readback |
| 개편 iPhone | Activity와 실제 알림 소비자2/2 |
| 개편 iPad mini (A20 Pro) | 기본1/1, 실제 설치된 기기형·SDK 확인 |
| 합계 | 개편6/6, 실패·스킵0, 사용 후 소유 기기0 |

11개 앱·테스트·실행기 소스 바이트는 cc0 이후 문서 체크포인트에서도 동일하다. cc0의 iOS 빌드·iOS/Watch 단위 CI와 카탈로그 포맷·수동 번역 검증을 해당 범위에서 재사용했다. 로컬 UI는 위 선택 검사만 실행했다. 실제 캡처는 영어이며 한국어·일본어는 카탈로그·소스 검토 범위다. VoiceOver 음성, 모든 언어·밝기 조합을 관찰했다고 주장하지 않는다.

## 실패 보존과 해결

- `d87a163a`: 2개 중 기본1통과·MAX1실패. 거의 화면 높이인 Badges 본문에 작은 이동이 효과가 없었다. 원본 SDK1820개 파일을 그대로 보존했다.
- `400c4e8f`: 2개 중 기본1통과·MAX1실패. Levels 본문이29pt만 보였는데 제스처 전후 프레임이 같았다. SDK1598개 파일을 보존하고, 양의 진행 판정을 유지한 채 드래그 시작점을 보이는 본문 안으로 옮겼다.
- `cc0cbfb6`: 호스트·게스트의 `errno28` 캡처 오류다. SDK에 Info.plist가 없고 최종 관찰13개 파일만 남았으므로 검사 집계를 추정하지 않았다. 미사용 캐시 정리 후 같은 논리 검사 ID의 조건부 두 번째 실행으로 확인했다. 원래 실패 두 번과 추가 실행 사용 기록은 유지했다.
- `9208e68c` iPad 준비: 존재하지 않는 A21 Pro 기기형으로 생성 전 실패했다(기기0·UI0). 설치 SDK의 A20 Pro 식별자를 확인하고 private iPad 전용 복사본·새 보존 접두사로 남은1개만 실행했다. 이미 통과한5개는 재실행하지 않았다.

세 실패 이력과 기기 준비 실패는 [발행 증거](../design/full-redesign-map/review/a21-reward-help-native-2026-11-04/evidence.json)에 구분했다. 독립 소스·네이티브·발행 검토의 미해결 P1/P2/P3은0이다. 머지 후에도 재사용 중인 작업트리는 유지하고, 사용이 끝난 소유 리소스만 확인·정리한다. 다른 작업 소유로 앱이 보호하는 워크트리는 보존한다.
