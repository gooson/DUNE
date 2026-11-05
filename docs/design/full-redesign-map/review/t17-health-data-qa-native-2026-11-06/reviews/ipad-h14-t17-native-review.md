# iPad normal native review: H14 and T17

Executed source `f97392084401db4c5108f241db1cb19901e072d8`; archive `ipad-f9739208-normal3-passed`. SDK **3 passed, 0 failed, 0 skipped**; this review covers the passed H14 and T17 methods. iPad mini (A20 Pro), iOS Simulator 27.2, Light, English, 1512×2316 PNG. The adjacent JSON hashes all **7 H14 + 17 T17** fresh PNG/AX pairs and exact App/fixture source files. No P1/P2 found in these two methods.

## H14

The normal iPad sheet shows the complete “What is Heart Rate Recovery?” hero, Definition and How It’s Measured paragraphs, and rating guide with original colored dots and Good `> 20 bpm`, Normal `12–20 bpm`, Low `< 12 bpm` rows. Close AX frame is **48×48 pt**. The post-Close captures show the Running recovery info button and underlying workout screen. No clipping or overlapping text is visible at this text size.

## T17

The iPad inspector shows original overview and three suggested prompts, the composed question and fixed `UI test response.` fallback, the focused composer/keyboard, and the unavailable supported-device/Foundation Models explanation. Both Browse routes reach the Health information child; Done returns to Q&A, then Today. AX on the child shows `Latest Workout`, synthetic `Sample bench press`, `45:00`, and the child Done control; native PNG agrees.

The test adds `--ui-health-query-fixture` and one Q&A availability flag per launch. `HealthQueryServiceRouting` only selects `HealthQueryUITestFixture` under DEBUG plus `--uitesting` and this flag. This is synthetic UI test data, not a user health result. Historical phone and Duo fixture records remain attributed to their original runs and flags. T18’s separate Korean title catalog issue does not change these H14/T17 English App bytes or their iPad evidence. No actual-map publication, full CI, or T18 localization result is claimed.
