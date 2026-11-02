# A07 metric icon alignment · source evidence

At current source 3f2ff74b, A06 TrainingVolumeDetailView uses `timer` for current Duration (line 179) and previous Duration (242), and `figure.strengthtraining.traditional` for current Sessions (184) and previous Sessions (248). Its Active Days `calendar` (239) denotes a different metric.

A07 ExerciseTypeDetailView currently uses `clock` for Duration at supporting hero line 202, primary choice 222, and comparison line 335; it uses `calendar` for Sessions at supporting hero 208, primary choice 227, and comparison 349. These are the six proposed glyph-only replacements. The recent-session duration's pre-existing `clock` at line 500 stays intact, as do the exercise-specific equipment/HK icons and all layout, logic and tests. Original 3f2 normal 2/2 is a historical pre-polish capture; it is not evidence of the proposed new glyphs. The approved MAX slot remains unused; the existing guard is held because it pins the old source.
