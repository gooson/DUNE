# Passport 100회 단위 업적 · 2026-10-30

CA04의 기존 1·5·10·20·50·100회 업적은 유지하고, 200·300·400회…처럼 100회마다 계속 이어지도록 변경했다. 다음 업적도 다음 100회 목표와 현재 진행률을 표시한다. 선택한 운동 시점까지 같은 종목의 유효하고 중복 없는 이력에서 첫 달성 기록과 날짜를 계산한다. 저장 모델이나 기존 업적 ID를 변경하지 않아 기존 이력에도 다시 계산해 적용한다.

## 새 실제 화면

[index.html](index.html)의 PNG는 이번 소스에서 실행한 XCTest 원본이다. opt-in `--ui-cardio-count-milestones`가 350개의 예시 달리기 기록을 추가하고 기존 Atlas fixture의 최근 달리기를 연다. 실제 사용자 이력이 아니다. 200·300회 업적, 다음 400회 목표와 완료 버튼으로 같은 상세에 복귀하는 경로를 확인한다. 이미지 편집이나 기존 PNG 재사용은 하지 않았다. 원본 출처·SHA-256은 [capture-index.json](capture-index.json), 소스 해시는 [evidence/source-hashes.json](evidence/source-hashes.json)에 보존한다.

- iPhone 18 Pro / iOS 27.0 / 한국어·다크·기본 글씨: 관련 UI 1건 통과, 새 CA04 2장.
- iPad Pro 13-inch / iOS 27.0의 CA04: 테스트 본문 시작 로그 없이 300초 제한/124로 종료되어 새 캡처 미완료다. 표준 실행기는 소유 프로세스 그룹 정지를 보고했다. 새 기동 정상화 근거가 없어 재시도하지 않았다. [시간 초과 기록](evidence/ipad-timeout-status.json)과 원본 로그를 보존한다.
- Duo 접힘·펼침의 CA04: 이전 장소 검색 작업에서 발생한 iOS 27.1 앱/AX/테스트 기동 장애가 복구되지 않아 새 캡처 미완료다. 이전 900초/124 실패 이후 정상화 근거가 없으므로 같은 실패를 반복하지 않았다. 이전 PNG를 새 구현의 증거로 사용하지 않는다.
- Watch에는 이 진행 모델/Passport 화면 소비자가 없다. 밝은 모드·최대 글씨·전체 앱 UI는 이번 데이터 확장 검증에 포함하지 않았다. 그리드·색·번역 문구는 변경하지 않았다.

## 검증

실제 Foundation 도메인 소스와 기존 테스트 파일을 그대로 복사한 macOS Swift Package에서 15개 테스트 정의, 매개변수를 포함한 26개 사례가 통과했다. 99/100/101, 199/200/201, 299/300/350, 1000/1001과 다음 1100 목표, 기존 ID/날짜, 첫 달성 귀속, 중복/다른 종목/유효하지 않은 기록 제외, 과거 기록 선택과 삭제 재계산을 포함한다. 전체 iOS 단위 테스트 스위트 통과로 확대하지 않는다. [단위 실행 기록](evidence/focused-unit.json)과 원본 로그를 보존했다.

UI는 전용 worktree 소유 시뮬레이터에서 표준 `scripts/test-ui.sh`, `DUNEUITests-DesignCapture`, 단일 `CardioAtlasCountMilestoneUITests/testPassportShowsHundredCountMilestonesAndNextTarget` selector, 300초 deadline으로 실행했다. 기기별 실행 영수증은 evidence에 보존한다. 빌드 전후 문자열 카탈로그 `--check --check-manual`, 소스 해시 일치, PNG 원본 해시 및 `git diff --check`를 확인했다. 관련 iPhone UI 1건 통과를 iPad/Duo 또는 전체 UI 통과로 확대하지 않는다.
