---
tags: [dashboard, siri, documentation, design-system]
date: 2026-11-02
category: solution
status: implemented
---

# DUNE 프로젝트 문서 포털

[대시보드](../../index.html)는 Siri 구현 설명과 기존 HTML 109개를 연결한다. 개요·Siri 연동·전체 색인·공통 문서 뷰어가 하나의 DUNE Glass 디자인 시스템을 사용한다.

## 실행

저장소 루트에서 실행한다. 전용 서버는 원본 파일을 수정하지 않고 응답에 공통 스타일을 적용하며, 보안이 격리된 중첩 시안에도 같은 시스템을 전달한다.

```bash
python3 scripts/build-docs-dashboard.py
python3 scripts/serve-docs-dashboard.py --port 8765
```

브라우저에서 `http://127.0.0.1:8765/index.html`을 연다. 포털 자체는 외부 폰트·라이브러리 없이 동작한다. 기존 개별 문서의 외부 의존성은 유지한다. 파일을 직접 열거나 JavaScript를 끄더라도 정적 목록과 실제 링크를 확인할 수 있다. Markdown 읽기와 전체 프레임 연결은 로컬 HTTP를 기준으로 제공한다.

## 문서 구조와 탐색

- **문서 개요** (`#overview`): 전체 구성과 네 기준 맵의 역할, Siri 요약, 경로 날짜 기준 최근 실제 화면 자료.
- **Siri 연동** (`#siri`): 정형 조회·자유 질문·고정 문구·운동 템플릿·습관 완료의 실행 구조와 소스 근거, 검증 범위.
- **전체 문서 색인** (`#library`): 제목·경로·주제 검색, 분류/주제 교차 필터, 체계순/제목순/경로 날짜순 정렬.
- **공통 문서 뷰어** (`#doc=...`): HTML·Markdown·소스·이미지, 상위 문서·목차·연결 자료·관련 문서·이전/다음. 내부 링크도 같은 틀에서 연결한다.

전체 HTML은 기준 맵 4개·디자인 시안 29개·실제 화면 자료 54개·레이아웃 7개·편집 원본 15개다. 분류는 문서의 역할이며 개별 검증 통과를 뜻하지 않는다. 기준일은 파일 수정일이 아닌 경로 안의 ISO 날짜다. 날짜가 없는 문서는 `—`로 표시한다.

데스크톱 사이드바는 아이콘 레일로 접고 펼칠 수 있다. 950px 이하에서는 배경 포커스를 차단하는 모바일 메뉴로 전환한다. 기준 문서는 접이식 그룹으로 묶는다. 검색 창은 상단 버튼 또는 **⌘K / Ctrl+K**로 열며, 방향키·Enter·Escape로 조작한다. 제목뿐 아니라 주제·경로·문서 분류도 검색한다. 원본 새 창 열기, 수정 키 클릭, 브라우저 뒤로/앞으로, 직접 주소와 새로고침, 넓게 보기, 색인 검색 조건 복귀를 지원한다.

## 하나의 디자인 시스템

[`design-system.json`](design-system.json)이 색·재질·타이포그래피·간격·반경·움직임·시안 보호 범위의 공통 원본이다. 생성기는 여기서 `design-system.css`와 라이트/다크 사구 배경 SVG를 만든다. 브라운·골드·아이보리의 반투명 표면, 하이라이트, 그림자, 블러를 포털과 하위 문서가 함께 사용한다.

- **시스템 / 라이트 / 다크**를 선택한다. 시스템 모드는 OS 색상 모드의 변경을 따른다. 선택과 사이드바 상태를 저장해 새로고침 뒤에도 유지한다.
- `theme-init.js`가 첫 화면 전에 테마를 적용하고 `workspace.js`가 모드·메뉴·검색을 제어한다.
- `document-ux.js`는 하위 메뉴의 구조·검색·본문 위치 표시·시안 보호 경계를 담당한다. `document-system.js`와 `reader-content.css`가 모든 하위 HTML의 제목·본문·설명·표·카드·컨트롤을 맞춘다. 생성된 공통 토큰을 그대로 사용한다.
- `serve-docs-dashboard.py`는 `data-srcdoc`에 담긴 중첩 HTML까지 재귀 처리한다. `standalone-system.js`가 모드·검색 단축키·문서 이동을 부모와 동기화한다. 기존 CSP와 `sandbox="allow-scripts"`를 유지한다.
- 원본 HTML 파일, 앱 화면 시안의 보호된 기기/그래프 영역, 실제 캡처 이미지 참조를 보존한다. 앱 UI나 새로운 앱 테마를 구현한 작업은 아니다.

로컬 서버는 캐시를 남기지 않도록 응답한다. 뷰어는 예전 일반 HTTP 서버의 HTML 캐시를 피하기 위해 읽기 URL에 `_dune=1`을 붙인다. 문서 경로와 탐색 해시에서는 이 내부 매개변수를 제거한다.

## 생성과 유지 관리

`template.html.in`은 화면 원본, `dashboard.js`는 페이지/색인, `reader.js`는 본문과 링크 탐색, `dashboard.css`·`workspace.css`는 공통 토큰을 소비하는 포털 표현이다. `scripts/build-docs-dashboard.py`는 숨김 경로·node_modules·대시보드 자신을 제외한 HTML 목록, 링크 그래프와 이전 주소 별칭을 생성한다. 제목 없는 테마는 기존 테마 manifest, 편집 원본은 파일명을 사용한다. 수동 문서 목록은 만들지 않는다.

HTML 추가·삭제·제목 변경 또는 디자인 토큰 변경 후 생성기를 다시 실행한다. 시안 보호 범위를 조정할 때도 JSON의 `protection`을 수정한다. Siri 구현을 바꾸면 템플릿의 설명·14종·기간 10개·등록 단축어 10개와 원본 검증 보고의 최신 결론을 함께 확인한다.

```bash
python3 scripts/build-docs-dashboard.py --check
python3 -B -m unittest scripts.tests.test_serve_docs_dashboard
node --check docs/dashboard/dashboard.js
node --check docs/dashboard/reader.js
node --check docs/dashboard/theme-init.js
node --check docs/dashboard/document-system.js
node --check docs/dashboard/document-ux.js
node --check docs/dashboard/workspace.js
node --check docs/dashboard/standalone-system.js
```

생성물 검사는 Swift 동작 검증을 대신하지 않는다. Siri 근거는 [Intents](../../DUNE/App/Intents/HealthQueryIntent.swift), [Shortcuts](../../DUNE/App/Intents/DUNEShortcuts.swift), [조회 서비스](../../DUNE/Data/Services/HealthQueryService.swift), [자연어 계획](../../DUNE/Data/Services/HealthQueryAssistant.swift), [검증 기록](../reviews/2026-10-30-siri-health-queries/README.md)이다. 시스템 음성은 아직 실기기 검증이 남은 상태로 표시한다.

## 확인한 범위

2026-10-31 기준 고유 HTML 103개, 연결 리소스 1,723개·그래프 연결 2,200개를 확인했다. 원본 HTML의 로컬 본문 링크에서 미해결 파일은 0개였다. 응답 변환 계약 테스트 4개는 전체 103개 HTML과 중첩 문서를 검사하며 CSP·sandbox·이미지 참조·한국어·중복 처리 보존을 확인한다.

실제 브라우저에서 검색·필터·빈 결과·초기화·정렬, HTML→Markdown, 기준 맵→시안, 소스/실제 화면 갤러리, 검색 복귀, 직접 주소/새로고침, 뒤로/앞으로, 넓게 보기, 이전 테마 주소의 이동을 확인했다. 최신 시스템 변경 뒤에는 데스크톱 사이드바 접기/저장, 모드 전환/저장과 OS 모드 일치, 전역 검색의 키보드 조작/Escape 종료, 모바일 메뉴/배경 포커스 차단/이동/닫기를 확인했다. 390px 네 페이지와 872px·1440px 대표 화면에서 바깥 가로 넘침이 없었다. 격리된 Activity 시안의 내부 모드 동기화·⌘K·기존 시안 버튼 동작도 확인했다. 103개를 모두 개별 화면으로 육안 검수했다는 뜻은 아니다.

[기본 창](preview.png) · [데스크톱 다크](preview-desktop.png) · [데스크톱 라이트](preview-light.png) · [모바일 메뉴](preview-mobile-menu.png) · [빠른 검색](preview-command.png) · [색인](preview-index.png) · [하위 문서](preview-reader.png)는 이 포털의 브라우저 캡처다. 앱 소스 변경이 없어 Xcode 빌드·시뮬레이터·네이티브 앱 캡처는 실행하지 않았다.

## 하위 메뉴 UX

`document-ux.js`를 포털과 각 문서 응답에서 함께 사용한다. 링크 목적지와 기존 이벤트가 붙은 기기/시안 버튼은 유지한다.

- 연결 문서가 12개를 넘으면 처음에는 접는다. 펼치면 주제·제목/경로 검색, 결과 수, 6개 단위의 첫 목록과 더 보기를 제공한다. 추가 표시는 12개씩 늘어나며 새 항목으로 키보드 포커스를 옮긴다.
- 레이아웃 맵의 42개 링크는 기준·공통, Today, Activity, Wellness, Life, Watch, 위젯·실시간, Siri로 묶는다. 검색·주제·펼침·표시 수는 세션에 저장해 문서를 열었다 돌아와도 복원한다. 저장소 접근이 제한된 격리 프레임은 현재 문서 안에서 동작한다.
- 짧은 연결 메뉴는 문서 종류가 표시된 카드형 링크로, 본문 바로가기는 현재 구간을 표시하는 가로 탐색으로 정리한다. 본문 이동은 자식 프레임의 탐색 이력을 추가하지 않는다. 동적 시안 필터로 링크가 다시 만들어지면 연결과 위치 표시를 재설정한다.
- 테마 목록에는 검색을 추가하고 기존 테마 선택 동작을 유지한다. 뷰어 목차는 시안 내부의 제목을 제외하며 실제 문서 제목이 바뀌면 갱신한다.
- `body.phone`처럼 화면 폭을 뜻하는 루트 클래스는 시안 보호 영역으로 취급하지 않는다. 기기·그래프·팔레트의 실제 하위 영역을 보호하며, 나머지 설명 카드·표·캡처 프레임의 고정 배경을 공통 표면으로 맞춰 모드별 색 대비를 유지한다.

브라우저에서 42개 링크의 6→18개 표시, Watch 3개 필터, 검색 결과 없음/초기화, 아래 방향키·Enter로 Markdown 열기, 뒤로 복귀 시 검색 조건 복원, Escape 닫기를 확인했다. 테마 검색 후 Ocean 선택, Siri 바로가기의 SQ03/SQ07 현재 위치, 기능군 변경 시 14→2→14개 메뉴 재생성, 격리 시안의 모드 동기화도 확인했다. 390px에서 레이아웃 문서 내부의 가로 넘침이 없고 기존 Duo 버튼이 동작했다. 밝음/어두움 설명 카드의 글자와 배경도 실제 계산 스타일로 확인했다.

[개선된 하위 메뉴](preview-submenus.png) · [모바일 하위 메뉴](preview-submenus-mobile.png)

## 재개 후 보완 · 2026-11-02

중단된 로컬 서버를 다시 실행했다. 테마 목록 검색에 빈 결과 안내와 검색 초기화 버튼을 추가하고, Escape로 검색을 비우며 문서 이동 후 검색어를 세션에서 복원한다. 기존 테마 선택 로직은 유지한다.

브라우저에서 전체 16개 항목 → 없는 검색어 0개 → 초기화 16개, Ocean 검색/선택, 레이아웃 맵 이동 후 뒤로 복귀 시 검색 복원, Escape 초기화를 확인했다. 390px에서 빈 결과 안내와 초기화 버튼이 보이고 문서 내부의 가로 넘침이 없었다. 레이아웃 맵의 42개 링크도 유지된다. 응답 변환 계약 검사와 생성물/구문 검사를 다시 실행했다.

[테마 검색 빈 결과](preview-theme-search-empty.png) · [모바일 검색 빈 결과](preview-theme-search-empty-mobile.png)

## 머지 전 리뷰 반영 · 2026-11-02

최신 main을 기준으로 목록을 109개로 재생성하고 검색창의 문서 수를 자동 집계와 연결했다. 컨디션 단축어의 추가 등록 문구 두 개를 반영하고, 등록 문구 표의 두 번째 셀 태그를 복원했다. 새 T02 배치 시안의 `.sheet`와 밝음/어두움 테마 시안의 `.sample`은 실제 시안 보호 영역으로 등록했다.

로컬 서버는 loopback Host만 받으며 숨김·상위 경로, 범위 밖 또는 숨김 파일로 향하는 심볼릭 링크, 디렉터리 목록을 차단한다. 공개 문서와 인덱스, HEAD 요청은 유지한다. 회귀 검사는 실제 HTTP 요청 파서를 메모리 연결로 실행하므로 포트를 점유하지 않는다.

```bash
python3 -B -m unittest scripts.tests.test_serve_docs_dashboard scripts.tests.test_build_docs_dashboard
```

생성물 계약은 등록 문구의 두 열 구조와 Swift 소스의 전체 등록 문구, 검색창 수와 고유 HTML 목록의 일치를 확인한다. 이전 103개/42개 검증 기록은 당시 소스 기준의 이력이다.
