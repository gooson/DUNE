# Workout share/return — Book maxAX native delta

Reviewed active native 015 (completion), 016–017 (system share), 019 (after dismiss), and 021 (return), with their AX hierarchy. The already-passed 013 keyboard/CTA checkpoint was reused. The test passed 1/1; no recipient was selected and nothing was sent.

- Completion (015): `Workout Complete!`, Korean exercise name `바벨 벤치프레스`, effort `7/10 Hard`, and the one-set count are visible without glyph clipping or overlap. The name/count line sits very close to the sheet's right edge.
- Share sheet (016–017): caption `바벨 벤치프레스 Workout` wraps into two complete lines; its close control remains clear. System actions below the viewport follow the sheet's normal scroll behavior.
- After closing (019): the completion sheet returns at its prior lower scroll position; preview and `Share Workout` CTA remain whole and unobstructed. The upper summary is above this viewport, not clipped within it. Return (021) shows the exercise detail with its `Start Workout` CTA whole.

**Actionable copy issue:** the completion summary and AX label say `바벨 벤치프레스 · 1 sets`. Singular count should read `1 set`. This is text correctness, not an observed clipping failure.

Pixel/AX review only; no VoiceOver speech or share delivery was verified.
