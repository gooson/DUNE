import SwiftUI

// MARK: - Shared data for muscle map visualizations

struct MuscleMapItem: Identifiable {
    let id: String
    let muscle: MuscleGroup
    let position: CGPoint  // Normalized (0...1)
    let size: CGSize       // Normalized (0...1)
    let cornerRadius: CGFloat

    init(muscle: MuscleGroup, position: CGPoint, size: CGSize, cornerRadius: CGFloat) {
        self.id = "\(muscle.rawValue)-\(position.x)-\(position.y)"
        self.muscle = muscle
        self.position = position
        self.size = size
        self.cornerRadius = cornerRadius
    }
}

// MARK: - SVG Body Part (high-quality shapes)

/// SVG-based muscle body part from react-native-body-highlighter (MIT license).
/// Attribution: https://github.com/HichamELBSI/react-native-body-highlighter
struct MuscleBodyPart: Identifiable {
    let id: String
    let muscle: MuscleGroup
    let pathData: [String]
    /// X offset for back body SVG paths (0 for front)
    let xOffset: CGFloat

    init(id: String, muscle: MuscleGroup, pathData: [String], xOffset: CGFloat = 0) {
        self.id = id
        self.muscle = muscle
        self.pathData = pathData
        self.xOffset = xOffset
    }

    var shape: MuscleBodyShape { MuscleBodyShape(pathData, xOffset: xOffset) }
}

// MARK: - Body Outline

enum MuscleMapData {
    static func bodyOutline(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let cx = width * 0.5
        // Head
        path.addEllipse(in: CGRect(x: cx - 18, y: height * 0.02, width: 36, height: 42))
        // Neck
        path.addRect(CGRect(x: cx - 8, y: height * 0.1, width: 16, height: height * 0.03))
        // Torso
        path.addRoundedRect(in: CGRect(x: cx - width * 0.18, y: height * 0.13, width: width * 0.36, height: height * 0.32), cornerSize: CGSize(width: 12, height: 12))
        // Left arm
        path.addRoundedRect(in: CGRect(x: cx - width * 0.3, y: height * 0.15, width: width * 0.1, height: height * 0.28), cornerSize: CGSize(width: 8, height: 8))
        // Right arm
        path.addRoundedRect(in: CGRect(x: cx + width * 0.2, y: height * 0.15, width: width * 0.1, height: height * 0.28), cornerSize: CGSize(width: 8, height: 8))
        // Left leg
        path.addRoundedRect(in: CGRect(x: cx - width * 0.14, y: height * 0.47, width: width * 0.12, height: height * 0.38), cornerSize: CGSize(width: 8, height: 8))
        // Right leg
        path.addRoundedRect(in: CGRect(x: cx + width * 0.02, y: height * 0.47, width: width * 0.12, height: height * 0.38), cornerSize: CGSize(width: 8, height: 8))
        return path
    }

    // MARK: - Muscle Positions (RoundedRect — legacy, used by ExerciseMuscleMapView / MuscleMapView)

    static let frontMuscles: [MuscleMapItem] = [
        // Chest
        MuscleMapItem(muscle: .chest, position: CGPoint(x: 0.42, y: 0.21), size: CGSize(width: 0.12, height: 0.08), cornerRadius: 6),
        MuscleMapItem(muscle: .chest, position: CGPoint(x: 0.58, y: 0.21), size: CGSize(width: 0.12, height: 0.08), cornerRadius: 6),
        // Shoulders
        MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.33, y: 0.16), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
        MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.67, y: 0.16), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
        // Biceps
        MuscleMapItem(muscle: .biceps, position: CGPoint(x: 0.27, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
        MuscleMapItem(muscle: .biceps, position: CGPoint(x: 0.73, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
        // Forearms
        MuscleMapItem(muscle: .forearms, position: CGPoint(x: 0.25, y: 0.38), size: CGSize(width: 0.05, height: 0.08), cornerRadius: 4),
        MuscleMapItem(muscle: .forearms, position: CGPoint(x: 0.75, y: 0.38), size: CGSize(width: 0.05, height: 0.08), cornerRadius: 4),
        // Core
        MuscleMapItem(muscle: .core, position: CGPoint(x: 0.5, y: 0.33), size: CGSize(width: 0.12, height: 0.12), cornerRadius: 6),
        // Quads
        MuscleMapItem(muscle: .quadriceps, position: CGPoint(x: 0.42, y: 0.55), size: CGSize(width: 0.1, height: 0.14), cornerRadius: 6),
        MuscleMapItem(muscle: .quadriceps, position: CGPoint(x: 0.58, y: 0.55), size: CGSize(width: 0.1, height: 0.14), cornerRadius: 6),
        // Calves
        MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.42, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
        MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.58, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
    ]

    static let backMuscles: [MuscleMapItem] = [
        // Traps
        MuscleMapItem(muscle: .traps, position: CGPoint(x: 0.5, y: 0.15), size: CGSize(width: 0.16, height: 0.06), cornerRadius: 6),
        // Rear delts
        MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.33, y: 0.17), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
        MuscleMapItem(muscle: .shoulders, position: CGPoint(x: 0.67, y: 0.17), size: CGSize(width: 0.08, height: 0.06), cornerRadius: 8),
        // Lats
        MuscleMapItem(muscle: .lats, position: CGPoint(x: 0.4, y: 0.26), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 8),
        MuscleMapItem(muscle: .lats, position: CGPoint(x: 0.6, y: 0.26), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 8),
        // Triceps
        MuscleMapItem(muscle: .triceps, position: CGPoint(x: 0.27, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
        MuscleMapItem(muscle: .triceps, position: CGPoint(x: 0.73, y: 0.27), size: CGSize(width: 0.06, height: 0.1), cornerRadius: 6),
        // Lower back
        MuscleMapItem(muscle: .back, position: CGPoint(x: 0.5, y: 0.37), size: CGSize(width: 0.14, height: 0.08), cornerRadius: 6),
        // Glutes
        MuscleMapItem(muscle: .glutes, position: CGPoint(x: 0.42, y: 0.48), size: CGSize(width: 0.1, height: 0.08), cornerRadius: 8),
        MuscleMapItem(muscle: .glutes, position: CGPoint(x: 0.58, y: 0.48), size: CGSize(width: 0.1, height: 0.08), cornerRadius: 8),
        // Hamstrings
        MuscleMapItem(muscle: .hamstrings, position: CGPoint(x: 0.42, y: 0.6), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 6),
        MuscleMapItem(muscle: .hamstrings, position: CGPoint(x: 0.58, y: 0.6), size: CGSize(width: 0.1, height: 0.12), cornerRadius: 6),
        // Calves
        MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.42, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
        MuscleMapItem(muscle: .calves, position: CGPoint(x: 0.58, y: 0.75), size: CGSize(width: 0.07, height: 0.1), cornerRadius: 4),
    ]

    // MARK: - SVG Body Parts (high-quality shapes for recovery map)
    // Source: react-native-body-highlighter (MIT License)
    // ViewBox: 0 0 724 1448

    static let svgFrontParts: [MuscleBodyPart] = [
        // Chest (left + right)
        MuscleBodyPart(id: "front-chest", muscle: .chest, pathData: [
            "M272.91 422.84c-18.95-17.19-22-57-12.64-78.79 5.57-12.99 26.54-24.37 39.97-25.87q20.36-2.26 37.02.75c9.74 1.76 16.13 15.64 18.41 25.04 3.99 16.48 3.23 31.38 1.67 48.06q-1.35 14.35-2.05 16.89c-6.52 23.5-38.08 29.23-58.28 24.53-9.12-2.12-17.24-4.38-24.1-10.61z",
            "M416.04 435c-15.12.11-34.46-6.78-41.37-21.48q-1.88-3.99-2.84-12.18c-2.89-24.41-5.9-53.65 8.44-74.79 4.26-6.26 10.49-7.93 18.36-8.56q11.66-.92 23.32-.35c10.58.53 18.02 2.74 26.62 7.87 12.81 7.65 19.73 14.52 22.67 29.75 4.94 25.57.24 64.14-28.21 74.97q-12.26 4.67-26.99 4.77z",
        ]),

        // Shoulders / Deltoids (left + right)
        MuscleBodyPart(id: "front-shoulders", muscle: .shoulders, pathData: [
            "M274.06 311.69q3.94 2.77 4.33 8.14.04.48-.38.73c-9.98 5.88-24.35 7.45-28.82 19.75-2.31 6.36-.97 17.35-1.43 23.68q-.55 7.51-5.73 14.07-10.37 13.11-13.81 16.67c-3.41 3.53-6.81 1.76-10.69-.47-15.42-8.87-24.95-25.45-22.52-43.22 2.05-14.92 12.71-25.79 24.06-35.02 16.99-13.82 35.58-17.99 54.99-4.33z",
            "M450.39 320.75q-.95-.52-.7-1.58c1.57-6.61 5.8-9.1 12.14-11.9 24.99-11.03 43.76 3.33 60.17 20.74 20.73 21.99 11.81 56.44-14.82 68.19-4.41 1.94-6.79-1.03-9.81-4.51-5.81-6.7-13.46-14.12-15.99-22.8-3.93-13.43 4.32-27.54-9.64-37.62q-8.22-5.93-17.99-9.08-1.84-.59-3.36-1.44z",
        ]),

        // Biceps (left + right)
        MuscleBodyPart(id: "front-biceps", muscle: .biceps, pathData: [
            "M189.52 492.51c-2.43.62-7.38.57-7.51-3.08-.56-16.01-.42-35.49 5.11-50.26 3.19-8.54 13.89-30.22 23.27-32.72 10.08-2.68 12.68 16.59 12.6 22.8-.22 15.98-7.51 34.79-15.05 48.71-4.29 7.94-9.95 12.38-18.42 14.55z",
            "M526.69 486.31c-9.9-8.61-17.75-33.21-20.65-47.73-1.41-7.06-1.34-29.61 8.58-32.16 10.33-2.66 23.81 25.34 26.6 32.91q2.6 7.04 3.6 16.13 1.62 14.66 1.66 32.28c.03 11.04-16.45 1.48-19.79-1.43z",
        ]),

        // Triceps (left + right)
        MuscleBodyPart(id: "front-triceps", muscle: .triceps, pathData: [
            "M206.2 514.2c-5.41-.67-6.55-7.29-4.69-11.42 11.08-24.55 22.84-50.62 30.54-75.51 1.37-4.41 3.08-8.59 3.95-12.45q2.94-13.12 5.79-26.26.42-1.98 1.82-3.39a.52.52 0 01.81.1q1.04 1.69 1.94 4.56 4.63 14.65 5.15 24.92c.57 11.36-5.11 24.55-8.65 35.5q-7.69 23.78-20.25 45.39c-2.45 4.23-11.51 19.18-16.41 18.56z",
            "M517.69 512.06c-20.07-22.12-28.95-51.73-38.01-79.03-3.27-9.87-3.58-19.18-1.34-29.38 1.29-5.88 2.49-13.03 5.61-18.52q.32-.57.72-.06 1.35 1.67 1.79 3.69c2.67 12.33 5.14 24.49 9.07 36.52 8.25 25.28 18.58 49.8 31.1 77.2q1.42 3.1 1.05 5.33c-.81 4.89-5.46 9.25-9.99 4.25z",
        ]),

        // Core / Abs (simplified — main abs blocks only)
        MuscleBodyPart(id: "front-core", muscle: .core, pathData: [
            "M311.02 531.71a.23.23 0 01-.19-.21q-.39-10.47 1.9-20.76c1.26-5.69 7.66-9.9 13.1-12.9 9.09-5.01 18.93-11.15 28.56-14.92a1.24 1.21-42.6 01.94.03c3.28 1.52 4.78 3.87 4.82 7.68q.13 13.16-.15 26.31c-.08 3.85.78 8.39-.87 13.1q-.17.46-.59.72-2.65 1.65-4.29 1.82-21.06 2.22-43.23-.87z",
            "M321 577.76c-5.17-.33-8.71-.44-10-6.26q-3.2-14.44-.59-27.83.11-.53.64-.63c7.58-1.44 13.62-2.45 22.45-4.56q11.5-2.76 23.94-1.88c3.67.26 3.3 3.46 3.4 6.21q.46 12.55-.33 26.94-.25 4.41-1.81 8.08-.21.49-.73.6-1.39.28-3.22.29-16.89.14-33.75-.96z",
            "M382.57 533.27c-4.17-.18-9.56-.3-13.15-2.69q-.17-.11-.24-.31c-1.82-5.55-.86-11.17-.96-15.66-.18-8.4-.78-17.36.06-25.71.29-2.85 1.88-4.42 4.15-5.79q.42-.26.91-.19 1.71.25 3.21 1.03 12.48 6.44 24.75 13.26c4.96 2.75 12.21 7.02 13.72 12.41q2.93 10.56 2.39 21.49a.77.76-1.8 01-.67.71q-16.89 2.18-34.17 1.45z",
            "M373.75 578.69c-2.47 0-4.31.22-5-2.7-1.8-7.7-3.05-34.29-.19-38.81q.27-.43.77-.47 13.14-1.24 25.77 1.83c8.41 2.04 14.51 3.01 21.85 4.36a1.29 1.28.6 011.05 1.07q2.16 14.12-.73 28.07c-1.08 5.24-5.22 5.26-10.36 5.63q-14.26 1.04-33.16 1.02z",
        ]),

        // Forearms (left + right, simplified to main paths)
        MuscleBodyPart(id: "front-forearms", muscle: .forearms, pathData: [
            "M127.23 683.05c-4.07-2.12 1.27-27.07 2.25-31.57 4.98-23.03 9.17-46.17 13.91-69.25q1.53-7.47 2.13-15.13c.93-12.09.81-22.15 6.23-31.59 7.1-12.33 13.54-29.16 26.1-36.73a1.98 1.97 62.7 012.84.91c1.92 4.48 1.93 8.28 2.06 14.15.44 19.77-1.3 41.04-8.72 59.67-11 27.62-22.22 55.21-32.62 82.91-4.04 10.76-7.56 20.66-12.82 26.39q-.59.65-1.36.24z",
            "M600.08 683.04c-5-4.14-8.97-15.46-11.29-21.56-5.82-15.25-11.38-30.55-17.58-45.7q-9.15-22.39-18.02-44.89c-5.58-14.19-7.32-31.42-7.99-46.57-.29-6.44-.68-19.43 2.67-25.02a1.71 1.71 0 012.25-.63c6.72 3.52 11.29 9.96 14.87 16.5q6.25 11.38 12.68 22.66c1.97 3.45 2.93 7.66 3.41 12.06 1.16 10.6 1.55 21.29 3.66 31.65 3.93 19.29 7.38 38.63 11.47 57.92 1.5 7.07 9.3 39.08 5.12 43.5a.91.91 0 01-1.25.08z",
        ]),

        // Traps
        MuscleBodyPart(id: "front-traps", muscle: .traps, pathData: [
            "M285.01 307.01a.89.89 0 01-.11-1.64q19.44-9.61 35.65-24.8 1.68-1.57 3.31-.31.4.32.45.82 1.25 12.61-1.57 25.41c-.74 3.32-2.55 4.23-5.9 4.48q-16.02 1.24-31.83-3.96z",
            "M414 311.19c-5.24-.12-7.81-.64-8.9-6.27q-2.33-12.09-1.17-23.94.06-.61.61-.89 1.66-.85 3.65.99 16.12 14.87 33.97 23.63 3.65 1.79-.27 2.89-13.88 3.91-27.89 3.59z",
        ]),

        // Quadriceps (left + right, main paths)
        MuscleBodyPart(id: "front-quadriceps", muscle: .quadriceps, pathData: [
            "M292.42 935.6q-.95-.52-1.57-1.4-4.1-5.79-7-13.53-7.8-20.79-13.3-42.33c-9.06-35.53-19.33-71.36-25.03-107.59-5.33-33.86 4-74.19 20.7-103.37q.35-.62.53.07c14.44 55.57 39.03 107.94 41.45 165.34 1.11 26.34.66 52.96-3.6 79.03-.63 3.83-4.73 27.81-12.18 23.78z",
            "M437.82 933.52c-8.9 14.18-15.15-26.74-15.46-29.25q-5.26-43.04-1.19-86.08c4.9-51.8 26.91-99.32 40.38-150.92q.18-.66.5-.06c17.25 31.67 25.39 68.28 20.54 104.36q-2.29 17.02-8.71 42.76-7.56 30.25-15.2 60.47-6.13 24.25-15.06 47.61-1.83 4.79-5.8 11.11z",
        ]),

        // Calves (left + right, main paths)
        MuscleBodyPart(id: "front-calves", muscle: .calves, pathData: [
            "M252.09 1032.57c.24-3.71 2.14-22.17 4.63-24.18a1.03 1.02-17.9 011.67.85c-.45 7.89-1.27 16-1.49 23.45q-.57 18.93-.66 37.88-.02 3.63.34 6.85c2.08 18.76 5.56 37.32 9.3 55.8 3.82 18.84 9.13 37.64 13.11 56.63q2.44 11.68 2.08 17.95c-.32 5.7-3.08 20.49-8.51 23.92a.62.62 0 01-.84-.16q-1.2-1.65-.95-3.55c.92-7.26 1.45-14.15-.3-21.52q-8.25-34.74-13.62-59.06c-1.86-8.44-3.17-17.18-3.93-26.3q-3.69-44.24-.83-88.56z",
            "M455.5 1231.67c-7.13-5.81-9.23-24.34-8.2-31.86 1.41-10.32 4.63-23.14 7.98-36.33q9.54-37.46 15.15-75.74c2.86-19.5 1.53-40.15.75-59.8-.22-5.67-.98-12.51-1.23-18.75a.97.97 0 011.87-.4c.35.86.92 1.76 1.12 2.68q2.96 14.31 3.31 20.53 2.37 43.28-.49 84.75-1.21 17.42-5.43 35.77-6.33 27.51-12.84 54.98-2.01 8.49-.11 18.36c.36 1.9.11 3.95-.68 5.55a.79.79 0 01-1.2.26z",
        ]),
    ]

    private static let backXOffset: CGFloat = 724

    static let svgBackParts: [MuscleBodyPart] = _svgBackPartsRaw.map {
        MuscleBodyPart(id: $0.id, muscle: $0.muscle, pathData: $0.pathData, xOffset: backXOffset)
    }

    private static let _svgBackPartsRaw: [MuscleBodyPart] = [
        // Traps (left + right)
        MuscleBodyPart(id: "back-traps", muscle: .traps, pathData: [
            "M1071.06 308.94c5.6 4.92 6.96 17.83 7.43 24.88q1.5 22.3.93 44.68-1.2 46.76-5.66 94a.57.56 3.7 01-.59.51q-.68-.03-.94-1.01-4.29-15.9-9.79-25.19c-10.24-17.31-18.8-31.84-25.59-49.4-10.19-26.38-15.6-54.28-26.46-80.58q-3.07-7.43-7.61-14.07-.3-.43.2-.6 12.47-4.28 25.48-4.85c5.54-.25 12.15.86 18.32 1.41 9.7.87 16.77 3.6 24.28 10.22z",
            "M1163.98 302.12a.43.43 0 01.22.65q-7.08 10.77-11.41 23.37c-10.53 30.61-17.8 62.94-31.3 91.07-5.11 10.64-15.17 25.22-20.12 36.26q-4.08 9.08-6.59 18.83a.77.77 0 01-1.51-.12q-4.27-45.15-5.52-90.99c-.56-20.28-.74-39.92 2.75-60.43 1.04-6.13 2.77-9.98 7.85-13.85 9.8-7.48 18.02-7.73 30.1-9.11 12.02-1.39 23.92.4 35.53 4.32z",
        ]),

        // Shoulders / Deltoids (left + right)
        MuscleBodyPart(id: "back-shoulders", muscle: .shoulders, pathData: [
            "M980.66 319.58c.19.14.55.19.65.32a.8.8 0 01-.16 1.15c-6.78 4.75-15.26 9.77-20.03 15.58-6.41 7.78-8.76 16.96-9.44 27.04-.39 5.92-1.68 9.5-5.59 13.43-10.02 10.08-19.04 16.47-31.14 20.41q-.75.25-.75-.55.19-18.4-.09-36.3-.14-9.4 1.07-14.22c4.04-16.07 22.8-33.85 39.68-35.64 9.99-1.06 17.34 2.46 25.8 8.78z",
            "M1227.3 316.44c14.62 9.44 25.48 21.03 25.46 39.51q-.02 20.56-.01 41.37a.37.37 0 01-.51.35c-5.08-2.06-10.41-3.98-14.9-6.97-7.84-5.24-21.14-14.95-21.77-24.95-.69-10.75-2.81-20.85-9.76-29.25-4.68-5.65-12.96-10.58-19.6-15.26q-1.23-.87.01-1.71c4.6-3.13 9.91-6.78 15.25-7.98q13.58-3.03 25.83 4.89z",
        ]),

        // Lats / Upper-back (left + right, main paths)
        MuscleBodyPart(id: "back-lats", muscle: .lats, pathData: [
            "M987.06 381.44c-8.48-5.06-14.14-13.28-18.82-22.92q-5.3-10.92-6.46-14.04c-1.49-4.01 35.14-19.22 39.61-20.97q2.75-1.08 4.33-.72c4.33.96 6.61 9.96 7.46 13.7q5.43 23.89 14.65 55.74.78 2.7-.88 4.39c-5.37 5.5-34.69-12.08-39.89-15.18z",
            "M1017.71 404.73c-23.86 13.25-54.31 7.11-60.45-22.75-1.2-5.81-2.5-15.84.64-20.55 3.63-5.44 7.17 4.18 8.17 6.14 7.71 15.14 31.62 29.16 48.2 31.13q1.84.21 5.26 2.06.4.21.26.64-.86 2.65-2.08 3.33z",
            "M1141.45 397.63a2.17 2.14-3.6 01-1.88-1.64q-.71-2.97.18-5.95 8.74-29.19 11.75-43.29c1.73-8.11 3.07-16.77 6.94-22.08 1.92-2.62 4.28-2.27 7.19-1.15q20.52 7.9 39.09 18.77a1.37 1.36 25.9 01.58 1.67c-6.05 15.46-12.98 30.84-28.43 39.45-9.45 5.26-25.83 15.17-35.42 14.22z",
            "M1149.69 404.8q-2.04-1.15-2.45-3.5-.09-.53.41-.75c4.64-2.04 9.78-2.51 14.63-3.87 11.01-3.1 22.03-10.83 30.34-18.57q6.33-5.89 7.58-8.93c1.02-2.49 3.79-9.5 7-9.46q.52.01.87.39 2.71 3.01 2.81 7.2c.33 13.77-2.24 26.93-13.26 35.95-13.88 11.36-33.12 9.94-47.93 1.54z",
        ]),

        // Triceps (left + right, main paths)
        MuscleBodyPart(id: "back-triceps", muscle: .triceps, pathData: [
            "M931.03 442.29c-2.01 2.57-6.52 9.71-10.12 9.17q-.52-.08-.8-.52-1.35-2.09-1.84-4.44c-2.25-10.87-3.28-22.88 1.35-33.38 5.45-12.33 18.27-23.68 29.61-31.2a.47.46 68.7 01.71.32l6.42 38.52q.09.54-.26.97c-.47.58-1.12 1.52-1.71 1.94q-9.11 6.58-18.08 13.36-2.9 2.2-5.28 5.26z",
            "M1213.94 424.56q-2.02-1.5-3.08-3.02-.31-.46-.22-1 3.32-19.22 6.42-38.46.09-.56.56-.25 14.9 9.82 24.8 22.71c9.8 12.75 9.72 30.37 5.41 45.13a2.62 2.62 0 01-3.76 1.57c-3.26-1.77-6.22-6.71-8.62-9.67-5.24-6.46-14.75-12-21.51-17.01z",
        ]),

        // Lower back
        MuscleBodyPart(id: "back-lowerback", muscle: .back, pathData: [
            "M986.76 627.1c-3.13-13.13-7.31-49.77 7.27-58.07 2.4-1.37 4.8-.82 6.7 1.29 6.15 6.8 16.22 18.56 18.77 28.15a1.35 1.3 52.6 01-.11.98c-2.51 4.53-9.96 8.09-15.83 11.36q-5.47 3.06-11.33 10.52c-1.23 1.56-2.6 4.3-4.5 6.06a.59.58-28.2 01-.97-.29z",
            "M1023.15 607.96a2.06 2.04-74.3 01-.94-1.69c-.17-10.98 5.04-24.58 8.79-34.9q15.61-42.83 36-83.59a1.11 1.1-62.5 011.51-.48c1.25.66 3.21 12.98 3.46 15.08q6.94 59.25 2.82 116.88-.62 8.66-3.1 19.37-.13.53-.59.24l-47.95-30.91z",
            "M1090.76 581.75q.62-5.16 0-10.27.22-29.79 3.05-59.5 1.1-11.58 3.91-22.88.31-1.27.44-1.43 1.08-1.43 1.88.17 23.38 46.97 40.14 96.18c1.8 5.28 5.84 16.69 4.38 22.96a1.64 1.64 0 01-.71 1.01l-47.63 30.72q-1.12.72-1.34-.6-4.54-28-4.12-56.36z",
            "M1151.19 603.31q-5.39-3.38-2.19-9.05 8.03-14.22 17.88-24.62c3.49-3.69 9.04.89 10.97 3.99q2.92 4.66 3.8 10.14 3.5 21.77-1.21 43.02a.96.96 0 01-1.77.28c-6.92-11.85-16.03-16.56-27.48-23.76z",
        ]),

        // Glutes (left + right)
        MuscleBodyPart(id: "back-glutes", muscle: .glutes, pathData: [
            "M1007.94 762.81c-16.94-16.64-29.37-37.66-31.47-61-2.06-22.84 15.63-34.95 32.18-45.71 8.2-5.33 46.51-27.32 54.37-17.65 5.92 7.29 13.38 15.84 15.44 25.21q3.01 13.63 2.44 27.6-.94 22.59-6.27 44.49c-2.43 9.96-2.9 17.16-2.59 26.75.47 14.83-18.52 17.18-29.12 14.07-6.38-1.87-13.79-4.83-21.35-6.25q-7.39-1.38-13.63-7.51z",
            "M1124.12 776.61c-9.28 2.74-26.75 1.29-28.86-10.88-1.05-6.03.27-14.88-1.3-23.27q-.54-2.94-2.15-9.35c-3.2-12.81-4.02-23.33-5.08-35.27-1.07-12.03-.57-22 1.64-33.17q1.1-5.6 4.19-10.41 8.74-13.58 11.87-16.59c4.96-4.77 15.84.18 21.19 2.11q19.7 7.12 40.17 21.43c9.59 6.7 19.29 14.31 22.93 25.17 4.81 14.37-.65 33.88-7.42 46.87q-7.79 14.97-21.39 28.9-6.74 6.9-15.26 8.36c-7.07 1.21-13.68 4.08-20.53 6.1z",
        ]),

        // Hamstrings (left + right, main paths)
        MuscleBodyPart(id: "back-hamstrings", muscle: .hamstrings, pathData: [
            "M998.81 761.94q14.07 14.17 20.1 33.62c.98 3.15-.78 9.61-.93 12.91q-1.3 27.63-2.3 55.27c-.55 15.31-1.54 30.27-5.12 45.26q-8.62 36.18-22.76 68.73-3.65 8.41-10.15 17.19-.45.61-.41-.14c.11-1.93.82-4.15.99-5.71q2.45-22.72 6.08-45.26c2.83-17.66 4.18-35.95 4.33-52.37.33-36.43-.75-73.34 1.47-109.68.33-5.32 1.07-16.16 4.7-20.25q.33-.36.81-.45 1.95-.37 3.19.88z",
            "M1183.25 947.53c2.57 14.85 4.32 31.11 6.22 46.14q.35 2.74-1.11.39c-14.67-23.67-23.34-52.15-30.55-79.32q-5.08-19.14-5.97-39.05-1.36-30.37-2.44-60.74c-.22-6.09-2.56-15.63-.55-21.57q5.87-17.35 18.96-31.07c10.77-11.28 10.17 46.55 10.16 48.97-.13 41.09-.45 74.18 1.91 110.07.57 8.75 1.88 17.53 3.37 26.18z",
        ]),

        // Forearms (left + right, main paths)
        MuscleBodyPart(id: "back-forearms", muscle: .forearms, pathData: [
            "M878.44 534.38a.15.15 0 01.18-.13c.47.12 6.68 15.77 7.07 17.22q6.66 24.73 5.52 50.29c-.4 8.9-3.45 17.35-6.64 25.55-7.94 20.38-17.41 41.88-29.59 60.09a1.04 1.02-54.2 01-1.49.25c-.34-.26.37-1.45.47-1.83q5.58-20.8 8.97-42.08 8.65-54.15 15.51-109.36z",
            "M1312.82 688.04c-4.78-6.01-7.2-10.8-11.76-19.56q-12.39-23.79-21.03-47.53c-4.86-13.36-5.22-26.17-3.83-40.19q1.13-11.5 2.69-19.53 2.72-13.98 9.59-26.79a.17.17 0 01.32.06q7.26 63.12 17.22 120.49 2.43 14.04 7.03 30.55c.22.79.74 1.33.36 2.4a.34.34 0 01-.59.1z",
        ]),

        // Calves (left + right, main paths)
        MuscleBodyPart(id: "back-calves", muscle: .calves, pathData: [
            "M982.69 1149.31c-3.07-2.23-3.98-6.24-5.24-11.03-7.19-27.14-7.88-53.18-6.67-82.78q1.03-25.29 9.23-47.45c4.77-12.89 15.33-24.77 23.79-36q.82-1.09.74.27c-1.37 22.86-2.72 45.67-3.11 68.49-.52 30.56-1.51 61.11-.42 91.68.24 6.83-2.77 16.29-10.08 18.37q-4.39 1.25-8.24-1.55z",
            "M1172.94 1149.31c-6.06-4.56-6.94-11.4-6.8-19.4.96-52.67-.49-105.31-3.54-157.9q-.04-.72.41-.16 7.96 10.07 15.43 20.44c9.11 12.64 13.61 28.98 15.78 44.21 4.96 34.71 3.75 72.94-5.97 106.5-1.97 6.82-9.18 10.93-15.31 6.31z",
        ]),
    ]

    // MARK: - SVG ViewBox dimensions

    /// The front body SVG viewBox is "0 0 724 1448"
    static let svgFrontViewBox = CGSize(width: 724, height: 1448)
}
