# Design System Rules

## 색상 관리

- xcassets 색상은 `Colors/` 하위 배치 / `Color(red:green:blue:)` 인라인 금지
- light/dark 동일이면 universal만
- 브랜드 컬러에 `.accentColor` 직접 사용 금지 (예외: ring gradient)
- 다크 모드 배경 gradient opacity >= 0.06
- 정적 색상 배열은 `CaseIterable`에서 파생

## 토큰 & 네이밍

- DS.Opacity 용도 기반 네이밍 / 심장 아이콘에 `DS.Color.heartRate`
- DS 토큰 통일 시 용도별 시맨틱 크기 보존
- 카테고리->색상 매핑은 enum extension 단일 소스

## 변경 프로세스

- 비주얼 변경은 v1->v2 2단계
