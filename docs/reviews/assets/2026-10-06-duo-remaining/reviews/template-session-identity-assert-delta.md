# Template direct-session identity assertion — 2026-10-07

The Book max-AX template rerun reached the Circuit row and presented `template-workout-container-screen`. Native `020-hierarchy.txt` shows direct workout session entry: navigation title `Barbell Squat`, static text `Exercise 1 of 2` with identifier `workout-session-screen`, and the library name `바벨 스쿼트`. The previous visual identity assertion accepted only the Circuit navigation title or uppercase transition text, so it failed before the already-existing final workout assertions despite successful navigation.

Changed only that assertion in `testTemplateListSupportsCreateEditAndTemplateStart` to accept the exact `Exercise 1 of 2` static text scoped by `workout-session-screen`. The Circuit row's two-exercise fixture assertion and final progress/Korean first-exercise assertions remain. `xcrun swiftc -frontend -parse DUNEUITests/Full/ActivityExerciseRegressionTests.swift` passed; parent owns the one-selector native rerun.
