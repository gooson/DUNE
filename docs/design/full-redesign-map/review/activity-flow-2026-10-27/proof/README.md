---
tags: [activity, validation, provenance]
date: 2026-10-27
category: review
status: reviewed
---

# 원본 검증 기록

실행 결과 JSON·원래 로그의 해시·문서 당시 소스 해시와 Duo 패널 확인을 보존한다. `.md.txt`는 원래 로컬 증거를 수정하지 않고 보존한 텍스트다. 오류·중단·부분 수집은 통과 증거와 구분한다. 각도 확인은 불가능했으며 패널 활성 상태만 검증했다. `duo-panel-capture.py.txt`는 사용한 task-local 호스트 어댑터의 보존본이고 앱 소스나 공통 실행기를 변경하지 않는다. 외부 helper는 소스 URL·커밋·SHA만 기록하며 앱에 포함하지 않는다.
