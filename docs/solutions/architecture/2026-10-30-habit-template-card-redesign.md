---
tags: [swiftui, habit-templates, dynamic-type, grid, visual-parity]
category: architecture
date: 2026-10-30
severity: minor
status: verified
related_files:
  - DUNE/Presentation/Life/HabitTemplateSheet.swift
  - DUNEUITests/Full/DuoRemainingRouteTests.swift
---

# Habit template cards: 시안에서 네이티브로

## Problem

기존 습관 템플릿은 작은 아이콘, 한 줄 제목, 같은 위계의 일정/목표를2열 고정으로 보여줬다. 긴 제목과 접근성 글씨에서 이름이 잘리고 카드의 선택 맥락을 읽기 어려웠다.

## Solution

기존 HabitTemplate와 prefill→dismiss→onSelect를 유지하고 카드 label만 분리했다. DS와 themeColor(for:)를 사용해 큰 원래 심볼·시간대 레이블·전체 제목·일정/목표를 표현한다. 너비700pt 이상은4열, 나머지는2열이며 접근성 글씨에서는 각각2열/1열이다. ViewThatFits로 아이콘/시간대와 일정/목표를 가로 또는 세로로 배치한다. 장식 심볼은 ScaledMetric을 쓰되52/84pt 상한으로 본문을 밀어내지 않게 한다. 배경은 카드 안에서 잘라 hit area와 스크롤 범위를 유지한다.

## Verification / Limits

표준 빌드와 iPhone 기본·접근성XXXL2/2, iPad 기본1/1, Duo 접힘1/1·펼침1/1이 통과했다. 네 기기의 새 실제 PNG를 직접 보고 제목·시간대·주기·목표의 잘림/겹침이 없음을 확인했다. 실제 캡처는 밝음·영어이며 전체 테마/언어 검증을 뜻하지 않는다. PR858과 `docs/reviews/2026-10-30-l03-habit-template-redesign.md`의 영수증을 따른다.

새 Duo의 migration/runner bootstrap 실패는 통과로 간주하지 않았다. Shutdown 상태의 초기화된 원본을 복제해 별도 소유 기기를 등록했고 정상 부팅 후 한정 재검증이 통과했다. 고정 commit `7acb090dd7d28fb0aea8e1907211ceff15aa450e`의 검토된 hinge helper로 내부 패널을 활성화했다. 공식 devicectl의 LCD 비활성/LCD-1 활성과 새 내부2006×2852 PNG를 확인했으며 수치 angle을 측정했다고 기록하지 않는다. Mac 잠금 해제는 필요하지 않았다.

## Prevention

- 시안의 예시 값이나 진행률을 native 모델에 복사하지 않는다.
- 접근성1열로 카드가 늘어나면 마지막 분류까지 도달하는 테스트의 bounded scroll 범위를 실제 카드 수에 맞춘다.
- 전체 Button label에 안정적인 template.id 식별자를 두고 원래 자동 입력 값을 실제 폼에서 확인한다.
- collector의 refresh-screen도 관련 L01/L02 후보와 portal을 함께 갱신할 수 있다. 기존 수집기의 매칭·우선순위·갤러리/보드 함수로 목표 화면만 추출하고 다른 이미지/항목 및 curated portal 링크는 보존한다. L03 출처만 명시한다.
- 기존 PNG와 브라우저 시안을 새 native 검증 증거로 사용하지 않는다. 테스트 기동 실패/실행수unknown은 통과가 아니다.

## Lessons Learned

실제 iPad sheet 폭은 화면 전체보다 좁을 수 있으므로 기기 이름이 아닌 사용 가능한 너비로 열 수를 결정해야 한다. 시안/코드/실제 캡처와 플랫폼별 검증 상태를 따로 기록하면 제한된 UI 환경에서도 완료 범위를 정직하게 유지할 수 있다. 새로운 .claude 규칙은 추가하지 않았으며 기존 규칙으로 충분하다.

공용 잠금의 해제 여부는 실제 호스트에서 확인하고 표준 lock 아래 원자적으로 실행한다. 다른 환경의 free 보고나 setter exit0만으로 실제 점유·펼침 상태를 추정하지 않는다.
