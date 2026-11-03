---
tags: [review, morning-briefing, condition-detail, review-ship]
date: 2026-11-03
category: review
status: reviewed
---

# Code Review Report

Scope: origin/main df53412c와 전체 working tree·관련 untracked 산출물. 초기 committed/staged 변경은 없으며 tracked patch는1363줄이다. 기존 수정은 전부 같은 채팅의 두 화면 개선이다.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 |0|없음|
| P2 |2|Resolved|
| P3 |2|Resolved|

## Findings

### [P2] data-001 · Fractional HRV changes lose their sign

- File: `DUNE/Domain/UseCases/BriefingTemplateEngine.swift:61`
- Status: Resolved
- Issue: Int(delta) converts real sub-1 ms changes into zero.
- Suggestion: Format the signed Double and add positive/negative fractional cases.

### [P2] data-002 · Missing history fallback displayed as weekly average

- File: `DUNE/Domain/UseCases/BriefingTemplateEngine.swift:86`
- Status: Resolved
- Issue: The producer falls back to the current score when recentScores is empty.
- Suggestion: Omit the average highlight when there is no history and test the missing-history case.

### [P3] arch-001 · Weekly progress normalization duplicated in the view

- File: `DUNE/Presentation/Dashboard/MorningBriefingView.swift:52`
- Status: Resolved
- Issue: Identical current rule is duplicated across view and engine; maintenance risk, no present divergence. Reclassified from reviewer P2.
- Suggestion: Expose normalized progress in Sections and render directly.

### [P3] simple-001 · Unused weekly narrative is still generated

- File: `DUNE/Domain/UseCases/BriefingTemplateEngine.swift:39`
- Status: Resolved
- Issue: weeklyMessage has no production consumer after the selected design. Dead work rather than a current functional bug; reclassified from reviewer P2.
- Suggestion: Remove field and private legacy formatter, update its old tests to the current contract.

## Review coverage

보안·성능은 finding0. 구조·데이터·단순성을 별도 읽기 전용 agent로 검토했다. Agent-Native는 지침/prompt 변경이 없어 스킵했다. Localization은 부모가 직접10개 새 키의 en/ko/ja, LocalizedStringKey/helper, programmatic String, 숫자 포매터와 단위 면제를 확인했다. App quality gate는 기존 unit33·iPhone4 unique/iPad2·실제 이미지·소스 해시 근거를 확인하며 범위 밖의 전체 회귀를 요구하지 않는다. Duo T04/T09 두 자세의 캡처 제한은 공개된 미검증 항목이며 현재 compact/regular/AX 핵심 게이트와 구분한다.

## Resolve / final review

두 P2는 데이터 리뷰어가 현재 delta에서 Resolved로 재확인했다. 부모도 네 finding을 현재 소스에서 재확인했다. 주간 진행률은 Sections로 옮겼고 사용하지 않는 weeklyMessage와3개 카탈로그 키를 제거했다. 최종 관련 unit suite35개와 영향받는 브리핑 UI1개가 통과했다. 최종 pr-reviewer는 이전 지적4건을 현재 diff에서 해결된 것으로 재확인했으며 새 finding은 없다.

- data-001: Formats the signed original Double; literal expected ±0.5/±0.0001 tests.

- data-002: Average highlight requires nonempty recentScores; dedicated no-history test.

- arch-001: Sections now owns weeklyGoalProgress and the View renders it directly.

- simple-001: Removed weeklyMessage field/formatter; old tests now check highlights/supporting text.

최종 품질 게이트는 PASS WITH NOTES이며 Duo 미캡처 범위는 PR에 공개한다. 원격 main은 df53412c로 기준이 동일하고 현재 변경은 이번 작업에만 속한다. 로컬 full build는 성공한 대상 테스트의 컴파일 근거를 재사용하므로 pre-commit의 중복 build만 `DAILVE_SKIP_PRECOMMIT_BUILD=1`로 생략하며 다른 hook 검사는 유지한다.
