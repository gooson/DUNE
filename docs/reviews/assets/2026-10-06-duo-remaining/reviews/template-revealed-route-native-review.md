# Template 새 경로 native delta 검토

범위: `book-max-template-form-lazy-reveal-fixed` Book/maxAX 활성 2853×2007 캡처 005/010/018/020과 관련 AX 계층. 테스트는 마지막 identity assertion에서 실패했으므로 전체 동작 통과로 판정하지 않는다.

- **005 New Template:** `Exercises (0)` 아래 `Add Exercise` 아이콘과 전체 문구가 모달 안에 온전히 보인다. 서로 겹치거나 잘리지 않는다.
- **010 New Exercise — 조치 필요:** `Primary Muscles`의 `Shoulders` 칩이 `Sho / ul- / der / s`처럼 네 줄로 쪼개져 글자 단위로 읽어야 한다. `Chest`, `Back`, `Biceps` 등 주변 칩도 비슷하게 잘게 줄바꿈된다. 칩 자체끼리 겹치지는 않지만 최대 AX에서 선택지의 시각적 가독성이 낮다. AX에는 `create-custom-exercise-muscle-shoulders`의 완전한 `Shoulders` 라벨이 있으므로 시각 레이아웃 문제다.
- **018 Template 목록:** `Codex Circuit Builder`의 `2 exercises · Squat, Bench Press`와 재생 버튼이 한 행 안에 온전히 보인다. 내부 겹침은 없다.
- **020 첫 세션:** `Exercise 1 of 2`, `Set 1 of 3`, `Planned reps: 6`, `KG 80` 및 증감 버튼이 온전히 읽힌다. 다음 `REPS`가 뷰포트 하단에서 끊기는 것은 스크롤 경계이며 내부 잘림으로 볼 근거는 없다.

이 보고서는 위 네 뷰포트의 픽셀 판정이며 저장·편집·시작 경로 전체 성공이나 화면 밖 상태를 보증하지 않는다.
