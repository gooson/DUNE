---
tags: [swiftui, body-composition, accessibility, design-map, native-evidence]
date: 2026-11-05
category: plan
status: implemented
---

# H06 신체 기록 이력 행 표현

## 목적과 범위

실제 H05 머지 `e4dca920540ba78277063df6c862cee295abb74e`에서 H06은 `BodyHistoryDetailView`의 목록이다. Wellness의 Body Changes로 진입하며 수동 SwiftData 기록과 Apple Health 읽기 전용 항목을 날짜 내림차순으로 합친다. 기존 실제 H06 네 장은 과거 화면 정체성 참고이고, 새 소스의 검증 결과가 아니다. H05 Form의 실제 캡처·상태와 H04 비교 화면은 이 작업의 변경 대상이 아니다.

날짜를 조금 더 선명하게 표시하고, 있는 측정값만 Weight·Body Fat·세 번째 신체값 순서로 캡슐에 담는다. 기존 category SF Symbol과 DUNE 신체 색을 쓰되, 밝은 외관에서만 아이콘 색을 기존 신체 색과 검정을 35% 섞어 더 진하게 한다. 어두운 아이콘·캡슐 배경·값 글자는 유지하고 값에는 의미상 기본 대비를 사용한다. 가로 폭이 부족하면 세로로 바꾸고 접근성 큰 글씨에서는 처음부터 세로로 읽는다. 접근성 이름은 기존 번역된 필드 이름과 실제 값·단위를 함께 제공한다. 수동 `record.muscleMass`는 기존 번역된 **Muscle Mass (kg)**와 수치를 말한다. Apple Health 행의 세 번째 값은 `fetchLeanBodyMass`에서 온 **Lean Body Mass**이므로 기존 category 이름과 수치·kg를 말한다. 두 출처를 같은 측정으로 부르지 않고 단위를 두 번 읽지 않는다.

수동 행의 원래 더 보기와 길게 눌러 Edit/Delete, Apple Health 행의 빨간 심장과 읽기 전용 동작을 유지한다. 값, 단위, 정렬, 빈 상태, 화면 제목, 행 AX ID, HealthKit 쿼리·SwiftData 변경, 저장 경로, H05 공유 Form, Watch와 문자열 카탈로그는 바꾸지 않는다.

## Affected Files

| 파일 | 변경 |
| --- | --- |
| `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift` | 기존 행 안의 날짜·지표값 표현만 강화하고 폭·큰 글씨에 맞게 배치 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 수정·저장 helper에서 수동 행 존재 확인 직후 H06 목록 캡처 한 번 추가하고, 캡슐이 새 AX 요소가 됨에 따라 기존 두 저장값 검사는 category·값·단위를 가진 정확한 AX label로 조회 |
| `docs/design/layout-map/body-history-h06.html` 및 index/README | H06 전용 배치 계약·진입 링크 |
| `docs/design/theme-map/themes/dune-body-history-h06.html` 및 manifest/README/index | DUNE 밝음·어두움·좁은 폭/큰 글씨 정적 시안 |
| `docs/design/phone-design-map/actual/`의 H06 네 상태 | 검토한 새 네이티브 PNG/AX 뒤에만 해당 H06 이미지·행·보드 갱신 |
| `docs/design/full-redesign-map/review/`의 H06 갤러리 | 실제 사례·기기·소스·캡처 해시와 미검증 범위 기록 |

## Implementation Steps

1. 현재 머지의 문서 해시와 H04/H05 메타데이터를 확인하고 H06 레이아웃·테마 맵 일곱 파일만 추가한다. 브라우저 시안의 날짜·수치·기호는 예시이며 SF Symbol 실물이나 네이티브 캡처가 아님을 표시한다. 테마 빌드와 `--check`를 실행한다.
2. `BodyHistoryDetailView`의 행 표현만 변경한다. H05 머지 이후 검사 파일에는 캡처 한 줄을 더하고 아래의 두 결과 조회를 새 AX label에 맞춘다. 기존 H04/H05 검사·helper·키보드 Done 경로를 그대로 둔다. 새 assertion·selector·unit test는 만들지 않는다. 기존 Add의 91.2 kg과 Edit의 88.8 kg 결과 확인은 `Weight: 91.2 kg`/`Weight: 88.8 kg` AX label로만 조회 대상을 바꾸고, 대기·hittable·dismiss 검사는 그대로 둔다. H05 Done과 H04 방법은 바꾸지 않는다.
3. 한 번에 소유 기기 한 대만 사용한다. Duo 접힘에서 기존 `testBodyAddFlowSavesRecord` 추가·`testBodyHistoryRowOpensEditFormAndSaves` 기본 수정·`testBodyHistoryEditAndSaveAtMaximumAccessibilityTextSize` MAX 수정 세 사례를 실행하고, 같은 Duo 펼침 기본 수정 한 사례를 실행한 뒤 기기를 삭제한다. 일반 iPhone 기본 수정, iPad A20 기본 수정을 각각 별도 소유 기기로 이어서 실행하고 사용 후 삭제한다. 기존 12ecc 소스의 Duo 접힘 세 사례 Passed는 수정 전 역사 증거로 보존한다. 출처별 AX 수정 뒤에는 접힘 세 사례를 새로 실행하고 나머지 세 프로필을 이어서 총 **현행 소스의 기존 사례 여섯 건을 네 순차 실행**에서 확인한다. Add는 값 하나만 있는 수동 행과 새 Weight AX 결과 조회도 증명한다. 실행기 잠금·deadline·소스 핀을 유지한다.
4. 실제 H06 목록의 날짜·값·아이콘·수동 더 보기·Apple Health 심장, 긴 글씨에서 캡슐과 편집 행동의 도달성, 값 글자의 명암비를 각 기기 PNG/AX로 검토한다. 수동 수정·저장·목록 복귀는 기존 테스트가 검증한다. 새 HealthKit 행이 실제로 관찰되지 않으면 읽기 전용 네이티브 증거라고 표시하지 않는다. 영어 이외 언어·어두운 외관을 실행하지 않았다면 그 한계를 남긴다.
5. 검토한 기기별 실제 PNG/AX를 각 H06 디자인맵 행과 갤러리에 연결한다. 다른 화면의 111개 카드 순서·메타데이터·보드 픽셀을 보존하고, 기존 H06 네 장은 역사적 참고로만 둔다. 새 게시 파일과 출처를 독립 검토한 뒤 PR로 완료한다.

## 검증 기준과 위험

출처별 접근성 이름 수정은 수동 muscle label 조건만 바꾸며 기존 H05 검사·키보드 경로를 보존했다. 가로 캡슐의 압축·가림과 큰 글씨의 세로 배치는 구현 전 주요 위험이었다. [Apple ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)의 제한 축 배치 기준에 맞춰 가로안 다음 세로안을 두고, [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)의 기호 식별·큰 글씨 가독성을 새 네이티브 PNG/AX에서 확인했다. 12ecc 접힘 세 사례의 성공은 수정 전 역사로 보존했으며, 현행 438d 소스는 네 프로필 여섯 사례와 선택 캡처 12쌍을 검증했다. 밝은 접힘 표본 아이콘 대비는 6.03:1이고, 출처별 접근성 이름 P2는 수정·독립 검토와 실제 AX 확인으로 해소했다. 다른 언어·어두운 외관·VoiceOver 음성은 검증하지 않았다. H05의 이미 통과한 앱/입력 검사는 이 문서만을 이유로 반복하지 않았다.

## 완료 결과

현행 앱 소스 `438d9e8376fc4929cbf977893055eb4124d4d318`에서 계획한 기존 UI 여섯 사례가 네 순차 실행에서 모두 통과했다. 일반 iPhone·iPad·Duo 접힘·펼침의 실제 PNG/AX 12쌍을 독립 검토하고 [H06 네이티브 갤러리](../design/full-redesign-map/review/h06-body-history-native-2026-11-05/index.html)에 게시한다. 수정 전 12ecc의 세 사례 통과는 역사적 성공으로 따로 보존한다. 밝은 접힘 표본 아이콘 대비는 6.03:1이고, 수동 Muscle Mass와 Apple Health Lean Body Mass 명칭을 실제 행 AX에서 구분했다. 다른 언어·어두운 외관·VoiceOver 음성·실사용 HealthKit 쓰기와 전체 회귀는 이번 검증 범위가 아니다.
