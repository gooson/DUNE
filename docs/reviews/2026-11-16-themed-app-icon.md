---
tags: [ios, app-icon, review, theme, splash]
date: 2026-11-16
category: solution
status: reviewed
---

# Code Review Report

> 날짜:2026-11-16
> 범위:82·71·87 아이콘 선택, 기본P04·8테마 자동 팔레트, 시작 화면 연동,112개 발전 시안과20팔레트 컬러랩.
> 기준:origin/main36839aa0d7d1d7a411a176c2e59395e402f9f34d.

## Summary

| 우선순위 | 발견 | 최종 상태 |
|---|---|---|
| P1 - Critical | 0 | 미해결 없음 |
| P2 - Important | 1 | test-001 해결 |
| P3 - Minor | 2 | docs-001 해결 · capture-001 오판으로 폐기 |

## 리뷰 범위와 방식

원래 체크아웃은 최신 main보다747개 커밋 뒤에 있고 Watch·CardioAtlas·운동 장소·번역·화면맵의 별도 미커밋 작업을 포함했다. 초기 상태와 선별 목록을 로컬에 보존하고 최신 기준의 `codex/dune-icon-settings` 브랜치에 아이콘 변경만 옮겼다. `Workout location` 번역과 Watch 문서 문단, 별도 앱 변경은 제외했다. 원래 체크아웃은 변경하지 않았다. 중단된 미리보기 VM 검사·보고서도 실행하거나 PR에 넣지 않았다.

전체 시안에는11000줄 이상의 텍스트와 생성 데이터·base64·이미지가 있다. review 스킬의2000줄 예외에 따라 주 에이전트가 보안·성능·아키텍처·데이터 정합성·단순성을 소스 그룹별로 직접 검토했다. 생성 데이터는 고유 시안112개·이미지 경로·팔레트20개·색 형식을 구조적으로 확인했다. Python AST와 JavaScript 구문 검사는 브라우저/VM 시나리오를 실행하지 않았다.

독립 `app-quality-gate`와 최종 `pr-reviewer`는 `gpt-6-sol`, medium, 읽기 전용으로 수행했다. 지침·프롬프트 변경이 없어 Agent-Native는 생략했다. 최종 리뷰는 실제 main 통합 diff, 생성 프로젝트, 자산·호출부·문서 링크를 확인했고 P1/P2/P3 결함은 없었다. 이후 문서 규칙을 대조하며 발견한 P3 형식 문제는 아래와 같이 별도 처리했다.

## 관점별 결과

- 보안: 인증 정보 노출·원격 실행·안전하지 않은 UI 삽입을 발견하지 않았다. 메모는 텍스트/값으로 표시하고 아이콘 이름은 닫힌 enum에서 만든다.
- 성능: 런타임 조합은3형태×8테마다. UIKit 요청은 직렬화하고 이미 적용된 이름은 건너뛴다. 이미지 변환은 개발용 CLI에서 수행한다.
- 아키텍처: 저장 모델은 Foundation만 사용하는 Domain에, SwiftUI 표현은 Presentation 확장에 둔다. UIKit 조정은 iOS 서비스로 한정한다. main의 AppTheme·저장 키 계약을 유지한다.
- 정합성: 형태와 테마를 독립 저장하고 진행 중·비활성 상태의 마지막 요청을 보존한다. 실패 시 재시도 경로가 있으며24조합을 기본1개와 대체23개에 매핑한다.
- 단순성: 시작 화면과 설정 미리보기가 같은 View를 사용하며 별도 프레임워크를 추가하지 않는다.
- 번역: 새20개 키에 en/ko/ja와 manual 추출 상태를 등록했다. 기존 DUNE/Try Again은 영어 개발 언어 fallback과 기존 ko/ja를 사용한다. UI는 enum rawValue 대신 번역된 displayName을 표시한다.
- 자산:24개 아이콘은1024px 불투명 PNG다. 미리보기·투명 시작 로고의 디렉터리/Contents/파일 참조를 확인했다. 대체 아이콘 설정은 iOS에만 추가했다.

## Findings와 처리

### docs-001 · P3 · Resolved

새 레이아웃·리뷰 문서에 필수 YAML frontmatter가 없고 네이티브 문서 본문이 영어였다. 메타데이터를 추가하고 한국어로 정리했다. 앱 코드·테스트 assertion·기존 캡처 증거는 바꾸지 않았다. 최종 문서·참조 검사를 통과해야 해결 완료로 유지한다.

미해결 P1/P2 발견사항은 없다. 실제 기준 브랜치 통합은 결함이 아닌 필수 검증 게이트로 관리한다. 이전 브랜치의 캡처를 최신 main의 완료 증거로 사용하지 않는다.

## 검증과 한계

최신 main 통합 앱에서 `DUNETests/AppIconStyleTests`4/4가 통과했다. 소유 iPhone18Pro4FBA2086-77FE-470C-958F-D4A882918C84, iOS27.2를 사용했다. 해당 테스트가 앱 컴파일을 포함하므로 별도 build-only를 반복하지 않았다. 빌드 후 문자열 formatter `--check --check-manual`, 테마맵 `--check`, diff 공백 검사를 수행한다. 최종 UI·캡처 결과는 아래에 기록했다.

필수 UI 범위는 iPhone·iPad 각각 아이콘 설정 흐름과 세 스플래시 두 selector다. 전체 회귀·실물 기기 홈 화면 표현·Duo 자세는 범위에 포함하지 않는다. Watch·visionOS 아이콘은 변경하지 않았다. iOS 프로세스 실행 전 정적 화면은82/P04이고 이후 SwiftUI 스플래시가 저장한 선택을 따른다.

### test-001 · P2 · Resolved

최신 main 통합 iPad에서 형태 선택·미리보기는 변경됐고 오류 안내는 없었지만 시스템 적용 완료 접근성 값을10초 안에 받지 못했다. 통과한 iPhone 흐름도 시스템 적용 지연이 나타났다. 같은 성공 기대를 유지하면서 시스템 콜백 대기를90초로 보정하고 실패한 설정 selector만 한 번 조건부 재실행한다. 실패 당시 PNG와 receipt는 실제 갤러리 diagnostics/verification에 보존한다. 재실행 성공을 확인한 뒤 머지한다.

최종 결과: 단위4/4·iPhone UI2/2·iPad 고유 UI2/2 통과와 최신 통합 캡처18장을 보존했다. iPad 설정은 한 번의 조건부 재실행에서 통과했다. 앱 코드와 성공 assertion은 유지했고 대기와 실패 진단만 보정했다. 기존 P1/P2를 현재 diff에 대조한 결과 미해결 항목은 없다.

### capture-001 · P3 · Stale after fix

글자가 빠졌다는 시각 판독은 원본 픽셀 대조로 반증됐다. 정상 참조 PNG와 의심 PNG4개의 세 이름·Theme 영역 RGB가 바이트 단위로 같고, footer의 글자 마스크2692개 픽셀도 같다. 앱/캡처 결함으로 취급하지 않는다. 불필요한2초 대기는 제거했고 최종 테스트 소스는 앞서 통과한90초 대기 버전과 일치한다. 대조 근거는 실제 갤러리 verification/text-pixel-comparison.json에 보존했다. 추가 촬영은 통과했지만 최종 증거는 원래 검증된 통합 캡처18장이다.
