# Custom exercise muscle chips — three-pose maxAX native delta

Reviewed `custom-muscle-max-all-poses-viewport-fixed` active captures 008 Closed, 010 Open, and 012 Book, plus their AX hierarchy. The scoped test and wrapper passed 1/1, skipped 0, exit 0 in 249.517 s.

- Closed (008): `Primary Muscles` breaks only between whole words; Chest, Back, and **Shoulders** are whole on separate one-line pills. The heading-to-first-pill gap is clear. Biceps continues at the lower viewport edge, a normal scroll cutoff.
- Open (010): the heading remains on one line with a clear gap; Chest, Back, Shoulders, Biceps, and Triceps each fit a one-line pill without overlap or interior clipping.
- Book (012): the two-line heading and visible pills retain the same clear spacing; **Shoulders** is whole. This agrees with the earlier Book-specific fix review.

The AX hierarchy exposes full `Shoulders` labels at in-window positions in all three poses. The partially visible Input Type area above the scrolled content is not an interior chip defect. No actionable visual regression in this delta. This pixel review does not establish VoiceOver speech or other unshown form states.
