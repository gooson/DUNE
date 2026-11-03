---
tags: [swiftui, personal-records, dynamic-type, swift-charts, native-evidence]
category: testing
date: 2026-11-03
status: reviewed
severity: important
related_files:
  - DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift
  - DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift
  - DUNE/Presentation/Activity/PersonalRecords/Components/RewardProgressSection.swift
  - DUNE/Presentation/Activity/PersonalRecords/Components/AchievementHistorySection.swift
  - DUNE/Presentation/Shared/NotificationPersonalRecordsPushView.swift
related_solutions:
  - docs/solutions/architecture/2026-10-14-personal-record-pace-history-chart.md
---

# 개인 기록 기간 선택과 읽을 수 있는 보상 화면 검증

## Problem

기존 개인 기록은 월·6개월·년만 제공했고 알림 경로는 획득한 배지 키를 전달하지 않았다. 개편 중 실제 UI 검사에서 상위 접근성 그룹의 하위 식별자 누락, 접근성 계층에 없는 차트 끝값, 큰 글씨에서 작은 기간 세그먼트와 고정 폭 배지의 가독성 문제가 드러났다. 좁은 Duo 최대 글씨에서는 히어로 제목과 NEW도 단어 중간에서 나뉘었다.

## Solution

전체 기간 최고 기록과 선택 기간의 차트를 분리한다. 기존 TimePeriod에 일·주를 노출하고 한 기준 시각으로 달력 경계를 계산한다. 알림 소비자에도 실제 배지 키를 전달하고 보상 갱신을 독립시킨다. 기존 pace 조회·취소·이력 제한은 유지한다.

원래 아이콘·단위·공유 동작을 보존하며 실제 보상과 달성 이력을 강조한다. 접근성 글씨에서는 시스템 메뉴 Picker를 사용하고 일반 크기는 기존 세그먼트를 유지한다. 배지 폭은 caption 크기에 맞춰 확장한다. 선택 기간의 실제 마지막 기록·단위·날짜를 별도 접근 가능한 요약에 표시한다. 작은 부제·날짜는 디자인 시스템의 secondary 색으로 대비를 확보한다.

접근성 크기의 최고 기록 제목과 NEW·공유 버튼은 두 줄로 분리한다. 원래 MAX 검사에서 새 최근 기록을 가정해 실패한 뒤, 기존 어제 러닝 운동을 원래 PR 저장 API로 등록하는 DEBUG 전용 옵션을 추가했다. 이 옵션은 MAX 검사만 사용하며 일반 실행 데이터는 바꾸지 않는다. 이 수정의 76d 네이티브 검사는 실제 1/1 통과했다. 이후 실제 차트 이미지에서 겹친 월 눈금을 확인해 접근성 크기의 눈금 간격만 넓히고, 플롯 전체 캡처를 추가했다. 최종 7ce674d4의 원래 Duo 접힘 MAX 검사는 1/1 통과했고, 전체 플롯을 포함한 15개 PNG·접근성 체크포인트의 독립 검토에서 날짜축 겹침 해소를 확인했다.

## Verification

관련 VM 검사는 19개를 통과했으며 이후 UI 수정은 해당 VM·검사 소스를 바꾸지 않았다. b0dafb05의 일반 크기 Activity·알림 검사는 iPhone·iPad·Duo 접힘·펼침에서 각각 2개씩 통과했다. b0 iPad 다크 최대 글씨 검사 1/1은 후속 접근성 변경 전의 과거 보조 증거다. 최종 7ce Duo 접힘 다크 MAX 검사 1/1 및 15개 체크포인트를 확인했다. 일반 크기 b0 캡처의 재사용은 내용·배치 범위이며 DEBUG 파동 위상·픽셀이나 접근성 식별자 동일성을 주장하지 않는다. Duo 최대 글씨 실패 원본도 보존한다.

비교 맵은 기존 이미지를 출처·기기 정보가 불명확한 과거 원본으로 표시하고 이후 이미지는 실제 source·selector·PNG·AX와 연결한다. Duo 각도·활성 화면은 실제 읽기 결과를 보존한다. 초기 부팅의 migration 경고를 이후 검사 통과와 구분하며 수리됐다고 주장하지 않는다. Phone의 당시 registry 원본은 남지 않아 표준 생성·등록 성공을 작업자 증언으로 구분한다.

## Prevention

- 기간 경계 검증과 전체 최고 기록 보존을 함께 검사한다.
- 섹션 존재나 중앙 좌표만으로 가독성을 판단하지 않고 실제 글자·이미지를 확인한다.
- 소스·상태가 유지된 범위에서만 기존 검증을 재사용하고 원래 revision·실패 기록을 보존한다.
- 비동기 fixture의 서로 다른 실제 값을 같은 상태로 설명하지 않는다.

## Lessons Learned

테스트 통과와 화면 가독성은 별도로 확인해야 한다. 공유 화면도 실제 각 진입 경로의 결과를 확인하고 비교 맵은 해당 행만 갱신한다.
