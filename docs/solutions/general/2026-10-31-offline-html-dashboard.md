---
tags: [html, dashboard, siri, documentation, offline, link-inventory]
category: general
date: 2026-10-31
status: implemented
severity: minor
related_files:
  - index.html
  - scripts/build-docs-dashboard.py
  - scripts/serve-docs-dashboard.py
  - scripts/tests/test_serve_docs_dashboard.py
  - docs/dashboard/design-system.json
  - docs/dashboard/workspace.js
  - docs/dashboard/document-ux.js
  - docs/dashboard/standalone-system.js
  - docs/dashboard/template.html.in
  - docs/dashboard/dashboard.css
  - docs/dashboard/dashboard.js
  - docs/dashboard/reader.js
  - docs/dashboard/reader-content.css
  - docs/dashboard/README.md
related_solutions:
  - docs/solutions/architecture/2026-10-30-grounded-siri-health-queries.md
---

# Solution: Siri 구현 설명과 기존 HTML을 연결한 로컬 대시보드

## Problem

### Symptoms

Siri의 현재 지원 범위와 디자인 시안·실제 앱 캡처가 서로 다른 문서에 나뉘어 있어 한곳에서 확인하기 어려웠다. 103개 HTML에는 제목 없는 편집 조각과 과거 검증 기록도 섞여 있었다.

### Root Cause

전체 HTML을 찾는 공통 진입점이 없었고, 디자인 시안에서 표현한 능력과 실제 코드·실행 증거의 범위가 달랐다. 기존 Siri 검증 보고도 최신 머리말과 과거 실행 표를 함께 보존하므로 최신 상태를 구분해야 했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `index.html` | 문서 개요·Siri 연동·전체 색인의 세 페이지 | 하나의 문서 탐색 진입점 |
| `scripts/build-docs-dashboard.py` | HTML 수집·제목 추출·경로 분류·정적 링크 생성·`--check` | 목록 누락과 오래된 생성물 탐지 |
| `docs/dashboard/template.html.in` | 화면 원본과 경로별 설명 | 생성물과 편집 원본 분리 |
| `docs/dashboard/dashboard.css`, `dashboard.js` | DUNE 글로시 표현, 페이지 탐색, 교차 검색·정렬 | 문서 구조와 동작 분리 |
| `docs/dashboard/reader.js`, `reader-content.css` | 하위 문서·Markdown·소스·이미지의 공통 읽기, 갤러리 표면 | 끊기지 않는 문서 탐색 |
| `docs/dashboard/README.md` | 소스 근거와 재생성 방법 | 다음 작업의 갱신 경로 명확화 |

### Key Code

```bash
python3 scripts/build-docs-dashboard.py
python3 scripts/build-docs-dashboard.py --check
```

HTML 목록을 정적 링크로 생성하므로 `file://`와 JavaScript 비활성 상태에서도 원본 문서에 접근할 수 있다. 검색·분류는 브라우저에서만 동작하며 별도 서버 API를 사용하지 않는다. 전체 본문 탐색은 로컬 HTTP를 기준으로 검증한다. iframe은 선택한 하나만 로드하고 읽기를 끝내면 `about:blank`로 비운다.

사용자 피드백에 따라 홍보형 제목·장식 영역·카드 나열을 제거하고 전문 문서 포털로 재구성했다. 개요에서는 문서 목적·역할을, Siri에서는 실행 구조와 검증 상태를, 색인에서는 문서명·경로·분류·주제·기준일을 제공한다. 전체 103개는 기준 맵 4개·시안/레이아웃 33개·실제 화면 51개·편집 원본 15개로 합계가 일치한다. 날짜는 파일 수정일이 아닌 경로 기준일이다.

후속 요청으로 DUNE 브라운·골드·아이보리의 글로시 표면과 목적별 기준 맵 카드를 적용했다. 모든 문서의 본문 링크를 수집해 상위·연결·관련 문서를 제공하고, HTML 안의 링크도 같은 뷰어에서 연다. Markdown은 DOM 노드로 렌더링해 원시 HTML·이벤트 속성을 평가하지 않는다. 원본 시안의 색과 네이티브 PNG 픽셀은 보존한다.

프레임의 `src`를 반복 지정하면 브라우저 이력에 자식 문서가 쌓여 상위 뒤로 가기가 동작하지 않을 수 있다. 자식은 `location.replace`로 교체하고 상위 해시가 탐색 이력을 소유한다. 이전 주소의 meta refresh는 생성 시 별칭으로 수집하고, 이미 열린 리디렉션 대상도 다시 로딩 상태에 묶이지 않게 처리한다. 읽기 요청에는 취소와 15초 대기 한도를 둔다.

Siri 설명은 코드 기준 정형 조회·자유 질문·정확한 고정 문구·운동 템플릿·습관 완료의 다섯 경로로 나눴다. 자연어 모델의 조회 계획 역할, 직접 계산한 결과, 시스템 음성, 실기기 미검증을 각각 표시한다. 앱 코드는 바꾸지 않았다.

### Verification

- 정적 확인: 고유 HTML 103개가 전체 색인과 일치한다. 로컬 문서·CSS·JS 링크, 내부 fragment ID, 생성물 `--check`, JavaScript 구문 검사를 확인한다.
- 실제 IAB 조작: 개요·Siri·색인 간 이동, 다섯 실행 경로 전환, Siri 검색 5개, 실제 화면/주제 교차 필터 4개, 빈 결과 0개, 초기화 103개, 경로 날짜순 정렬을 확인했다.
- Siri 디자인 시안을 공통 뷰어에서 열어 제목·본문과 연결 문서를 확인했다. 문서 이탈 시 프레임을 비우며 원본 테마의 외부 아이콘 경고는 포털 코드의 검증 결과와 구분한다.
- 390px·872px·1440px에서 문서 가로 넘침이 없었다. 넓은 화면은 접을 수 있는 사이드바, 좁은 화면은 모바일 메뉴·축소된 표 열·한 열 문서 체계로 전환된다.
- [기본 창](../../dashboard/preview.png)·[넓은 창](../../dashboard/preview-desktop.png)·[색인](../../dashboard/preview-index.png)을 보존했다. 앱·시스템 Siri 캡처가 아니다. 앱 소스 변경이 없어 Xcode 빌드·앱 UI 테스트는 실행하지 않았다.
- 후속 최종 상태: 103개 원본 HTML의 로컬 본문 링크에서 미해결 파일 0개, 고유 연결 리소스 1,723개·연결 2,200개를 확인했다. HTML→Markdown, 테마 맵→시안, 소스 읽기, 실제 갤러리 표면, 직접 링크/새로고침, 상위 복귀, 검색 유지, 뒤로/앞으로, 넓게 보기, 이전 테마 주소의 이동을 실제 브라우저로 확인했다. [공통 문서 뷰어](../../dashboard/preview-reader.png)를 보존했다.


### Shared design system and isolated documents

`design-system.json` 하나에서 라이트/다크 색·재질·타입·간격·반경과 시안 보호 선택자를 관리한다. 생성된 CSS와 사구 SVG를 포털이 사용하고, 같은 CSS를 하위 문서에 적용한다. 시스템 모드는 OS 변경을 따르며 선택과 사이드바 상태를 저장한다. 사이드바 아이콘 레일·모바일 메뉴·접이식 기준 문서·⌘K 검색을 공통 탐색으로 제공한다.

일부 HTML은 `sandbox="allow-scripts"`인 불투명 출처의 `data-srcdoc` 프레임을 포함한다. 부모 DOM 접근만으로는 그 안에 시스템을 적용할 수 없다. 전용 로컬 서버가 응답을 만들 때 중첩 HTML에 동일한 스타일/브리지를 삽입한다. 원본 파일·CSP·sandbox는 유지한다. 부모/직접 자식의 Window 식별자를 확인하는 메시지로 모드·검색·문서 이동을 연결하며, 실제 앱 시안과 이미지 영역은 보호 선택자로 구분한다.

뷰어 URL의 `_dune=1`은 과거 일반 서버의 HTML 캐시를 피한다. 서버의 새 응답은 `no-store`로 제공한다. 전역 검색의 Escape는 명시적으로 닫고 이전 포커스로 복귀시킨다. 자식 프레임은 계속 `location.replace`를 사용해 브라우저 문서 이력을 보존한다.

```bash
python3 scripts/serve-docs-dashboard.py --port 8765
python3 -B -m unittest scripts.tests.test_serve_docs_dashboard
```

응답 변환 계약 테스트 4개는 전체 103개 HTML과 중첩 문서의 보안 설정·이미지 참조·한국어·중복 처리 보존을 검사한다. 브라우저에서는 세 가지 모드, 저장/새로고침, 1440px 사이드바 접기, 390px 네 페이지의 가로 넘침과 메뉴/Escape, 빠른 검색, 격리된 Activity 시안의 내부 모드·⌘K·기존 버튼을 확인했다. 전체 문서를 각각 육안 검수한 것은 아니다. 최신 화면은 [관리 안내](../../dashboard/README.md)의 브라우저 캡처를 따른다.

## Prevention

- HTML·제목·공통 토큰을 바꾸면 생성기를 실행하고 `--check`로 목록과 CSS/SVG 동기화를 확인한다.
- 격리된 중첩 문서의 스타일링은 전용 서버로 제공하고 보안 경계를 약화하지 않는다. 시안 보호 선택자는 공통 JSON에서 관리한다.
- Siri 소스가 바뀌면 14종·등록 단축어 10개·기간 10개·고정 문구·모델 경로 설명을 함께 확인한다.
- 문서의 ‘실제 화면’ 분류를 모든 검증 통과 의미로 사용하지 않는다. 날짜·기기·부분 성공은 원본 보고를 따른다.
- 기존 문서 안의 과거 링크·증거를 대시보드 작업에서 수정하거나 새 검증으로 승격하지 않는다.

## Lessons Learned

정적 HTML 목록은 오프라인 접근과 누락 검증을 함께 지원한다. 구현 설명에는 시안보다 소스를 먼저 확인하고, 실행 이력은 최신 결론과 과거 기록을 구분해야 한다.

문서 허브의 통일성에는 표면뿐 아니라 탐색 이력·목차·원본 열기·상위 복귀도 포함된다. 시안과 캡처를 보존하면서 공통 읽기 틀과 설명 표면을 통일할 수 있다.

## 하위 메뉴와 시안 보호 경계 · 2026-10-31

공통 색상만 적용해도 기존 링크 묶음의 탐색 비용은 줄지 않는다. 레이아웃 맵의 42개 링크를 접이식 탐색기로 바꾸고 주제·검색·결과 수·더 보기·세션 복원을 함께 제공했다. 짧은 메뉴·본문 바로가기·테마 목록도 동일한 `document-ux.js`에서 처리한다. 원본 앵커를 이동해 실제 목적지를 유지하며 기기/시안 버튼의 기존 이벤트를 보존한다.

기존 `.phone` 보호 선택자가 `body.phone`까지 포함해 문서 전체를 시안으로 제외한 것이 밝은 메뉴·빈 버튼 대비 문제의 원인이었다. 루트 html/body를 보호 대상에서 제외하고 실제 미리보기·그래프·팔레트만 보호한다. 보호 영역 밖의 불투명 설명 카드·표·캡처 프레임은 공통 표면으로 맞춘다. 숨김 링크가 `display:grid!important`에 의해 다시 나타나지 않도록 메뉴 안의 `[hidden]` 우선순위도 보장한다.

동적 시안은 본문과 메뉴를 다시 생성한다. 링크가 교체되면 위치 관찰과 이벤트를 정리한 뒤 새 노드에 연결하고, 뷰어 목차도 변경된 실제 제목에 맞춰 갱신한다. 본문 이동 중에는 선택한 위치를 표시하고 사용자 스크롤을 받으면 자동 관찰로 돌아간다. 변경 검증과 최신 브라우저 캡처는 [관리 안내](../../dashboard/README.md)의 하위 메뉴 UX 절을 따른다.

## 테마 검색의 복구 경로 · 2026-11-02

테마 목록을 검색해 항목이 모두 숨겨지면 결과 수만 0으로 표시돼 다음 행동이 불분명했다. 공통 메뉴 컴포넌트의 테마 검색에 빈 결과 안내·초기화 버튼·Escape 초기화·세션 검색어 복원을 추가했다. 같은 토큰과 빈 상태 표면을 사용하며 기존 테마 선택 이벤트를 유지한다.

브라우저로 16→0→16개 결과, Ocean 선택, 문서 이동/복귀 후 검색 복원, Escape와 390px 배치를 확인했다. 최신 캡처는 [관리 안내](../../dashboard/README.md)의 재개 후 보완 절에 보존한다.

## 머지 전 보완 · 2026-11-02

실제 main 동기화 후 최종 목록은 HTML 109개다. 검색창의 고정 문서 수를 생성기 집계로 바꾸고 컨디션 단축어의 추가 등록 문구와 올바른 두 열 표를 반영했다. 새 T02 시안의 보호 범위도 같은 JSON 원본에서 관리한다.

로컬 문서 서버의 일반 파일 제공 경로가 숨김 파일과 외부 심볼릭 링크까지 허용하던 문제를 수정했다. loopback Host와 저장소 범위를 검증하고 숨김/상위 경로, 외부·숨김 대상 링크, 목록 열거를 거부한다. 메모리 HTTP 연결로 실제 GET/HEAD 파서를 실행하는 접근 계약과 문서 생성물 구조/등록 문구 계약으로 회귀를 방지한다.
