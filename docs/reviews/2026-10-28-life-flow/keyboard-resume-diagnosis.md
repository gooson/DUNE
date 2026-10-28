# 키보드 복구 후 실패 지점 분리

사용자 복구 확인 후 601aaf8c에서 같은 selector를 재개했다. New Habit 폼이 열리고 이름 필드 포커스와 Weekly Swim 입력값 일치가 확인됐다. 이전 메뉴→폼 실패 원인은 해당 실행에서 해소됐다.

새 실패는 UITestHelpers.dismissKeyboardIfPresent가 존재만 확인한 Return 키를 탭한 것이다. 해당 AX frame은 x300.7,y1087,width99,height54로402×874pt viewport 밖이며 XCUITest hit point는-1,-1이었다. helper의 버튼 선택 조건에 isHittable 검사가 없었다.

이는 이전 메뉴 실패와 다른 확인된 테스트 helper 원인이다. 동일 원인 재시도 횟수는 새로 숨기지 않고 기존 이력과 함께 보존한다. 실행기가 종료된 뒤 keyboard/toolbar Done 후보를 exists && isHittable 조건으로 제한하고 해당 selector1회로 확인한다. 앱 코드는 변경하지 않는다.
