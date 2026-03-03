---
tags: [notification, today-tab, navigation, deep-link, read-unread, watch]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 알림 구조 개선 (Today 허브 + 운동 상세 이동)

## Problem Statement

현재 알림의 진입점과 이동 규칙이 분산되어 있어, 사용자가 알림을 확인하고 원하는 운동 상세 화면까지 이동하는 흐름이 일관되지 않다.
특히 푸시 알림 탭/인앱 알림 탭 시점에 목적지 이동 기준, 스택 보존 기준, 대상 데이터 누락 시 fallback 기준이 명확하지 않다.

## Target Users

- iPhone/iPad에서 Today 탭을 중심으로 운동/건강 인사이트를 확인하는 사용자
- Watch까지 포함해 동일한 알림 경험(확인 상태/히스토리 정책)을 기대하는 사용자
- 푸시 알림에서 바로 관련 운동 상세로 진입하려는 사용자

## Success Criteria

1. Today 탭 상단 벨 아이콘으로 알림 허브에 1탭 진입 가능
2. 알림 허브 기본 정렬은 최신순 고정
3. 알림 내역 탭/푸시 탭 모두 해당 운동 상세 화면으로 이동
4. 이동 시 기존 NavigationStack을 초기화하지 않고 유지
5. 대상 데이터가 없으면 "찾을 수 없음" 상태를 명확히 표시
6. 읽음/미읽음 상태 관리 및 벨 아이콘 배지 반영
7. 알림 히스토리 보관 정책은 무제한
8. iPhone/iPad/Watch를 함께 고려한 단일 정책 정의

## Proposed Approach

### 1) Information Architecture

- Today 탭 `toolbar` 우측에 벨 아이콘 추가
- 벨 아이콘 탭 → `NotificationHubView` push
- 허브 리스트: 최신순 단일 섹션(초기 MVP는 필터/그룹핑 없음)

### 2) Notification Data Model

알림 엔티티(예시):

- `id`: UUID
- `createdAt`: Date (정렬 기준)
- `kind`: workout | health | system
- `title` / `body`
- `route`: 목적지 정보 (예: workoutId, source)
- `isRead`: Bool
- `openedAt`: Date?
- `source`: inApp | push

저장 정책:

- 히스토리 무제한 보관
- 읽음/미읽음 상태 영속화
- 배지 카운트 = `isRead == false` 개수

### 3) Navigation & Deep Link Policy

핵심 원칙:

- 알림 탭 시 목적지는 기본적으로 "해당 운동 상세"
- 기존 stack은 clear하지 않음 (현재 스택 유지)

라우팅 흐름:

1. 허브 row 탭 또는 푸시 응답 수신
2. `NotificationRouteResolver`가 `route`를 실제 destination으로 변환
3. 대상 탭 전환이 필요하면 전환하되, 각 탭 stack state는 유지
4. destination push 수행
5. 성공/실패와 무관하게 알림은 읽음 처리

### 4) Not Found Fallback

대상 운동이 삭제/동기화 지연 등으로 존재하지 않으면:

- 전용 fallback 화면 표시 (`NotificationTargetNotFoundView`)
- 메시지: "해당 운동을 찾을 수 없습니다"
- 액션:
  - "알림 목록으로 돌아가기"
  - "운동 기록 열기" (대체 진입)

### 5) Read/Unread UX

- 기본: 새 알림은 미읽음
- 허브 진입 시 자동 전체 읽음은 하지 않음
- row 탭 시 개별 읽음 처리
- 상단 액션으로 "모두 읽음 처리" 제공 가능 (MVP 포함 권장)

### 6) Cross-Platform Policy (iPhone / iPad / Watch)

- iPhone/iPad: 동일한 허브 구조/정렬/읽음 정책 사용
- Watch:
  - 알림 확인 entry 제공
  - Watch에서 직접 상세 라우팅이 제한되는 경우 iPhone handoff/deep link로 연결
  - 읽음 상태는 가능한 범위에서 동기화(최소한 iPhone 기준 source of truth 유지)

## Constraints

### 기술적 제약

- 현재 앱은 탭별 `NavigationStack` 구조이므로, 전역 deep link 처리 시 탭 전환 + 목적지 push 조합 설계 필요
- 푸시 진입 시 앱 라이프사이클 상태(terminated/background/foreground)별 처리 경로 분리 필요
- Watch는 iOS와 동일한 화면 구조가 아니므로 목적지 매핑 정책을 단순화해야 함

### 데이터 제약

- 무제한 보관은 저장소 증가 이슈를 동반
- 대상 운동 삭제 시 route payload가 stale 될 수 있음

## Edge Cases

- 푸시 수신 직후 데이터 동기화 전이라 대상 미조회: 재시도 1회 후 fallback
- 동일 알림 중복 수신: dedup key로 병합 처리
- 사용자가 빠르게 연속 탭: 중복 push 방지(라우팅 lock)
- 알림 탭 중 대상 탭/화면이 이미 열려 있는 경우: 중복 화면 누적 방지
- Watch 오프라인 상태: 로컬 캐시 기준 표시 후 온라인 복귀 시 동기화

## Scope

### MVP (Must-have)

- [ ] Today 탭 상단 벨 아이콘 진입
- [ ] NotificationHubView (최신순 단일 리스트)
- [ ] 읽음/미읽음 상태 저장 + 배지 카운트
- [ ] 알림 탭/푸시 탭 → 운동 상세 라우팅
- [ ] 현재 스택 유지 정책 적용
- [ ] 대상 없음 fallback 화면
- [ ] 무제한 히스토리 보관
- [ ] iPhone/iPad/Watch 공통 동작 정책 문서화 및 최소 구현

### Nice-to-have (Future)

- 타입 필터(운동/건강/시스템)
- 날짜 그룹핑(오늘/이번 주/이전)
- 알림 검색
- 읽음/미읽음 일괄 관리 고도화
- 오래된 알림 soft archive 옵션

## Open Questions

1. 무제한 보관을 유지하되 성능 보호를 위한 페이징 기준(예: 50개 단위)을 MVP에 포함할지?
2. Watch에서 "운동 상세"를 직접 열지, 항상 iPhone handoff로 통일할지?
3. 읽음 상태 동기화를 로컬 우선으로 둘지(간단), CloudKit 동기화까지 MVP에 포함할지?

## Next Steps

- [ ] `/plan notification-navigation-structure-improvement` 으로 구현 계획 생성
- [ ] 라우트 모델/딥링크 스키마 확정 (`route` payload contract)
- [ ] Today toolbar + 허브 화면 wireframe 확정
- [ ] iPhone/iPad/Watch별 QA 시나리오 작성
