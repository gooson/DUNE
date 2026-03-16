---
source: review/self
priority: p3
status: done
created: 2026-02-27
updated: 2026-02-27
---

# Watch Equipment 필드 동기화 검증

## 현재 상태

TemplateEntry에 equipment 필드 추가 완료. iOS에서 템플릿 생성 시 equipment 포함.
그러나 WatchConnectivity를 통한 exercise library 동기화 시 equipment 필드가
Watch 측 WatchExerciseInfo에 전달되는지 end-to-end 검증 필요.

## 목표

- iOS 앱에서 `syncExerciseLibraryToWatch()` 호출 시 equipment 포함 확인
- Watch 측 `WatchExerciseInfo` 디코딩 시 equipment 수신 확인
- 기존 equipment 없는 캐시 데이터와 backward compatibility 확인
- 실기기 테스트로 아이콘 정상 표시 확인

## 참고

- Correction #69: Watch DTO 필드 추가 시 양쪽 target 동기화
- `WatchSessionManager.swift` (iOS), `WatchConnectivityManager.swift` (Watch)
