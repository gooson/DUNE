# W15 Weekly workout plan — scoped native evidence

This 2026-11-14 supplement keeps the [Nov 7 HELD review](../weekly-workout-plan-w15-2026-11-07/index.html) and its failures unchanged. The integration source is `15450f83dcedc8628c44a9327aea5497031b375e`. Current publication base `75fc1d6c` includes the native iPad More menu route and later merged screens.

The shared TemplatePlan normal and MAX iPad selectors passed 2/2 in the seven-case batch. That batch had one unrelated W04 MAX failure, so this is scoped evidence. The Phone normal B13 pass is historical. Phone MAX passed the fresh shared selector at `c95e246c7` after the Phone-only settled-scroll correction; its named captures are attached here. The iPad evidence remains from `15450f83d`.

The iPad normal/MAX captures show seven-day current and next-week dates, a selected seeded template, and the full Remove from Plan action. At MAX, content scrolls between the calendar and selected-day pane.

The named PNG/AX pairs retain source UUID, timestamps, and SHA-256 in `manifest.json`. This supplement does not replace old captures or claim Duo coverage.

The earlier Phone MAX assigned screenshot is before scrolling and clips selected-day content. A separate fresh named screenshot from the approved extra run shows the whole Remove from Plan action after the settled 80px/s scroll and before tapping it. AX places the button at y740.7–804, 69 points above the tab bar. The following tap and restored Rest Day passed. The post-remove PNG remains labeled as the state after the tap. The extra Phone batch passed 4/6 globally; W13/W14 authoring failed separately.
