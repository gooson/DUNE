import Foundation

/// Provides exercise descriptions and form cues for common exercises.
/// Descriptions are stored here rather than in exercises.json to avoid bloating the data file
/// and to make updates independent of the exercise library.
enum ExerciseDescriptions {
    static func description(for exerciseID: String) -> String? {
        descriptions[exerciseID]
    }

    static func formCues(for exerciseID: String) -> [String] {
        cues[exerciseID] ?? []
    }

    // MARK: - Descriptions

    private static let descriptions: [String: String] = [
        // Chest
        "barbell-bench-press": "Compound chest exercise performed lying on a flat bench, pressing a barbell upward.",
        "incline-barbell-bench-press": "Upper chest focused press performed on an incline bench at 30-45 degrees.",
        "decline-barbell-bench-press": "Lower chest focused press performed on a decline bench.",
        "dumbbell-bench-press": "Chest press using dumbbells for greater range of motion and independent arm work.",
        "dumbbell-fly": "Isolation exercise targeting the chest with a wide arc motion.",
        "cable-crossover": "Cable-based chest isolation with constant tension throughout the movement.",
        "push-up": "Bodyweight chest exercise also engaging triceps and shoulders.",

        // Back
        "barbell-row": "Compound back exercise pulling a barbell toward the torso while hinged forward.",
        "pull-up": "Upper body pulling exercise using bodyweight, targeting lats and biceps.",
        "lat-pulldown": "Cable machine exercise mimicking pull-up motion with adjustable resistance.",
        "seated-cable-row": "Horizontal pulling exercise targeting mid-back muscles.",
        "dumbbell-row": "Single-arm back exercise allowing focused unilateral training.",
        "deadlift": "Full-body compound lift picking a barbell from the floor. Targets posterior chain.",
        "t-bar-row": "Heavy compound row using a landmine or T-bar setup.",

        // Shoulders
        "overhead-press": "Standing shoulder press with barbell, targeting all three deltoid heads.",
        "dumbbell-shoulder-press": "Seated or standing press with dumbbells for shoulder development.",
        "lateral-raise": "Isolation exercise for lateral deltoids using dumbbells.",
        "front-raise": "Anterior deltoid isolation using dumbbells or a plate.",
        "face-pull": "Rear deltoid and rotator cuff exercise using cables.",
        "reverse-fly": "Rear deltoid isolation performed bent over or on a machine.",

        // Arms
        "barbell-curl": "Bicep isolation exercise using a barbell with supinated grip.",
        "dumbbell-curl": "Classic bicep exercise with dumbbells, allowing wrist rotation.",
        "hammer-curl": "Bicep and brachialis exercise with neutral grip dumbbells.",
        "tricep-pushdown": "Tricep isolation using a cable machine with various attachments.",
        "skull-crusher": "Lying tricep extension with barbell or EZ-bar.",
        "dip": "Compound exercise for triceps and lower chest using bodyweight.",

        // Legs
        "barbell-squat": "King of leg exercises. Compound movement targeting quads, glutes, and hamstrings.",
        "front-squat": "Quad-dominant squat variation with barbell in front rack position.",
        "leg-press": "Machine-based compound leg exercise with adjustable foot placement.",
        "leg-extension": "Quad isolation exercise on a machine.",
        "leg-curl": "Hamstring isolation exercise on a machine.",
        "romanian-deadlift": "Hip-hinge movement targeting hamstrings and glutes with minimal knee bend.",
        "bulgarian-split-squat": "Single-leg squat with rear foot elevated for unilateral strength.",
        "calf-raise": "Isolation exercise for gastrocnemius and soleus muscles.",
        "hip-thrust": "Glute-dominant exercise using a barbell across the hips.",
        "lunge": "Unilateral leg exercise stepping forward or backward.",

        // Core
        "plank": "Isometric core exercise maintaining a push-up position.",
        "crunch": "Core flexion exercise targeting the rectus abdominis.",
        "russian-twist": "Rotational core exercise with or without weight.",
        "hanging-leg-raise": "Advanced core exercise raising legs while hanging from a bar.",
        "ab-wheel-rollout": "Anti-extension core exercise using an ab wheel.",

        // Cardio
        "running": "Cardiovascular exercise performed outdoors or on a treadmill.",
        "cycling": "Low-impact cardio on a stationary or outdoor bicycle.",
        "rowing": "Full-body cardio exercise on a rowing machine.",
        "jump-rope": "High-intensity cardio using a jump rope.",
        "elliptical": "Low-impact cardio on an elliptical machine.",
    ]

    // MARK: - Form Cues

    private static let cues: [String: [String]] = [
        "barbell-bench-press": [
            "Retract shoulder blades and arch upper back",
            "Grip slightly wider than shoulder width",
            "Lower bar to mid-chest, press back up",
            "Keep feet flat on the floor"
        ],
        "barbell-squat": [
            "Bar on upper traps, feet shoulder-width apart",
            "Break at hips and knees simultaneously",
            "Keep chest up and knees tracking over toes",
            "Descend until thighs are parallel or below"
        ],
        "deadlift": [
            "Bar over mid-foot, hip-width stance",
            "Hinge at hips, grip just outside knees",
            "Keep back flat and chest up",
            "Drive through heels, lock out hips at top"
        ],
        "overhead-press": [
            "Bar at shoulder height, grip just outside shoulders",
            "Brace core and squeeze glutes",
            "Press bar overhead, moving head through at top",
            "Lock out with bar over mid-foot"
        ],
        "pull-up": [
            "Grip slightly wider than shoulders",
            "Initiate by depressing shoulder blades",
            "Pull until chin clears the bar",
            "Control the descent, full extension at bottom"
        ],
        "barbell-row": [
            "Hinge forward to ~45 degrees",
            "Pull bar to lower chest or upper abdomen",
            "Squeeze shoulder blades at the top",
            "Control the descent, avoid momentum"
        ],
    ]
}
