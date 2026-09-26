---
tags: [watch, watchconnectivity, swiftdata, rpe, rest-duration, workout-duration]
date: 2026-09-19
category: solution
status: implemented
---

# Watch 완료 기록과 전송 데이터 일치

## Problem

SessionSummaryView가 로컬 기록과 WatchConnectivity payload를 각각 생성하면서 세 가지 불일치가 발생했다.

- 사용자가 선택한 운동 강도를 로컬 저장 직전 세트 RPE 평균으로 덮어썼다.
- CompletedSetData.restDuration을 WorkoutSet에 전달하지 않아 영구 기록과 후속 bulk sync에서 누락했다.
- 로컬은 종목별 배분 시간을 저장하지만 즉시 전송은 전체 세션 시작/종료 시각을 사용했다. 3종목 30분 운동을 iPhone이 90분으로 계산할 수 있었다.

## Solution

- `WatchWorkoutRecordBuilder.makeRecord`로 세트 매핑과 완료 기록 생성을 추출했다. 선택 강도는 최종값으로 유지하고 세트 RPE와 휴식시간도 별도로 보존한다.
- SessionSummaryView는 저장한 ExerciseRecord 목록에서 `makeUpdate(from:)`를 호출한다. 전송 종료 시각은 `record.date + record.duration`이다.
- WatchConnectivityManager의 bulk sync도 동일 변환 함수를 사용한다. DTO 스키마와 iPhone 수신 형식은 유지한다.
- 기존 데이터의 값은 소급 수정하지 않는다. 별도 검토 항목인 일시정지 시간의 운동 시간 포함 문제는 이번 범위 밖이다.

## Validation

- `scripts/build-ios.sh` 성공: iOS 및 포함된 Watch 앱 컴파일 확인.
- `WatchWorkoutRecordBuilderTests`: 4개 테스트, 매개변수별 8개 케이스 통과.
- 검증 내용: 세트 RPE와 다른 사용자 강도 보존, 휴식시간 nil/0/90/120 및 Codable 왕복, 1종목/3종목 전송 시간 합계, SwiftData 저장 후 새 ModelContext에서 재조회한 bulk payload 일치.
- 실행 가능한 watchOS 시뮬레이터가 없어 테스트는 `/tmp/watch-summary-regression`의 macOS Swift Package에서 실행했다. 실제 builder·ExerciseRecord·WorkoutSet과 테스트 파일을 복사하고, CompletedSetData 및 필요한 DTO/enum 선언을 원문 그대로 추출했다. 실제 WatchConnectivity 전송 및 Watch UI 테스트는 실행하지 않았다.

## Prevention

- 전송 payload는 저장한 모델에서 생성해 즉시 전송과 재동기화 경로의 값이 같도록 유지한다.
- 세트 RPE와 사용자의 세션 강도는 독립 값이다. 저장 시 계산값으로 사용자 선택을 덮어쓰지 않는다.
- 모델 매핑 변경은 필드 단위 검증과 저장 후 재조회·Codable 왕복 검증을 함께 수행한다.

## Lessons Learned

동일 운동을 여러 저장소로 전달할 때 각 경로에서 데이터를 따로 조립하면 시간과 사용자 입력이 쉽게 달라진다. 저장 기록을 전송의 기준으로 삼으면 이 불일치를 줄일 수 있다.
