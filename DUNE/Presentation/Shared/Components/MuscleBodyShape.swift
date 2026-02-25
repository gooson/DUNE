import SwiftUI

// MARK: - SVG Path → SwiftUI Shape

/// Converts SVG path strings to SwiftUI Shapes, scaled to fit the given rect.
/// Paths use viewBox "0 0 724 1448" from react-native-body-highlighter (MIT license).
/// Attribution: https://github.com/HichamELBSI/react-native-body-highlighter
struct MuscleBodyShape: Shape {
    /// Pre-parsed path (avoids re-parsing SVG on every render)
    let cachedPath: Path
    /// X offset to subtract from absolute SVG coordinates (e.g. 724 for back body paths)
    let xOffset: CGFloat

    /// Create from pre-parsed path (preferred — used by MuscleBodyPart)
    init(cachedPath: Path, xOffset: CGFloat = 0) {
        self.cachedPath = cachedPath
        self.xOffset = xOffset
    }

    /// Create from raw SVG path strings (parses once at init)
    init(_ paths: [String], xOffset: CGFloat = 0) {
        var combined = Path()
        for d in paths {
            combined.addPath(SVGPathParser.parse(d))
        }
        self.cachedPath = combined
        self.xOffset = xOffset
    }

    /// Single path convenience
    init(_ path: String, xOffset: CGFloat = 0) {
        self.init([path], xOffset: xOffset)
    }

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 724.0
        let scaleY = rect.height / 1448.0
        let transform: CGAffineTransform
        if xOffset != 0 {
            transform = CGAffineTransform(translationX: -xOffset, y: 0)
                .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        }
        return cachedPath.applying(transform)
    }
}

// MARK: - SVG Path Parser

/// Minimal SVG path parser supporting M, L, C, Q, A, Z and relative variants
/// plus shorthand S, T, H, V commands.
enum SVGPathParser {

    static func parse(_ d: String) -> Path {
        var path = Path()
        var tokens = tokenize(d)
        var i = 0
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        func nextNumber() -> CGFloat {
            guard i < tokens.count else { return 0 }
            let val = CGFloat(Double(tokens[i]) ?? 0)
            i += 1
            return val
        }

        func nextPoint() -> CGPoint {
            CGPoint(x: nextNumber(), y: nextNumber())
        }

        /// Read a single arc flag (0 or 1) that may be packed with subsequent data.
        /// In compact SVG, "01.81" means flag=0, then "1.81" continues.
        /// "01" means flag=0, then "1" continues.
        func nextFlag() -> CGFloat {
            guard i < tokens.count else { return 0 }
            let token = tokens[i]
            guard let first = token.first, (first == "0" || first == "1") else {
                return nextNumber()
            }
            let flagVal: CGFloat = first == "1" ? 1 : 0
            let rest = String(token.dropFirst())
            if rest.isEmpty {
                // Token is just "0" or "1"
                i += 1
            } else {
                // Token is like "01.81" or "1.5" — consume flag, put rest back
                i += 1
                tokens.insert(rest, at: i)
            }
            return flagVal
        }

        /// Arc flags (0 or 1) can be compressed in SVG: "01" = largeArc=0, sweep=1.
        /// Handles compressed ("01.81.1"), separate ("0", "1"), and mixed formats.
        func nextArcFlags() -> (CGFloat, CGFloat) {
            let flag1 = nextFlag()
            let flag2 = nextFlag()
            return (flag1, flag2)
        }

        while i < tokens.count {
            let token = tokens[i]
            guard let cmd = token.first, token.count == 1 && cmd.isLetter else {
                // Implicit repeat of last command
                let cmd = lastCommand
                processCommand(cmd, path: &path, currentPoint: &currentPoint, startPoint: &startPoint,
                               lastControl: &lastControl, nextNumber: nextNumber, nextPoint: nextPoint,
                               nextArcFlags: nextArcFlags)
                lastCommand = cmd
                continue
            }
            i += 1
            lastCommand = cmd

            processCommand(cmd, path: &path, currentPoint: &currentPoint, startPoint: &startPoint,
                           lastControl: &lastControl, nextNumber: nextNumber, nextPoint: nextPoint,
                           nextArcFlags: nextArcFlags)
        }
        return path
    }

    private static func processCommand(
        _ cmd: Character,
        path: inout Path,
        currentPoint: inout CGPoint,
        startPoint: inout CGPoint,
        lastControl: inout CGPoint?,
        nextNumber: () -> CGFloat,
        nextPoint: () -> CGPoint,
        nextArcFlags: () -> (CGFloat, CGFloat)
    ) {
        switch cmd {
        case "M":
            let p = nextPoint()
            path.move(to: p)
            currentPoint = p
            startPoint = p
            lastControl = nil

        case "m":
            let dp = nextPoint()
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            path.move(to: p)
            currentPoint = p
            startPoint = p
            lastControl = nil

        case "L":
            let p = nextPoint()
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "l":
            let dp = nextPoint()
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "H":
            let x = nextNumber()
            let p = CGPoint(x: x, y: currentPoint.y)
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "h":
            let dx = nextNumber()
            let p = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "V":
            let y = nextNumber()
            let p = CGPoint(x: currentPoint.x, y: y)
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "v":
            let dy = nextNumber()
            let p = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
            path.addLine(to: p)
            currentPoint = p
            lastControl = nil

        case "C":
            let c1 = nextPoint()
            let c2 = nextPoint()
            let p = nextPoint()
            path.addCurve(to: p, control1: c1, control2: c2)
            lastControl = c2
            currentPoint = p

        case "c":
            let dc1 = nextPoint()
            let dc2 = nextPoint()
            let dp = nextPoint()
            let c1 = CGPoint(x: currentPoint.x + dc1.x, y: currentPoint.y + dc1.y)
            let c2 = CGPoint(x: currentPoint.x + dc2.x, y: currentPoint.y + dc2.y)
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            path.addCurve(to: p, control1: c1, control2: c2)
            lastControl = c2
            currentPoint = p

        case "S":
            let c2 = nextPoint()
            let p = nextPoint()
            let c1 = reflectedControl(current: currentPoint, last: lastControl)
            path.addCurve(to: p, control1: c1, control2: c2)
            lastControl = c2
            currentPoint = p

        case "s":
            let dc2 = nextPoint()
            let dp = nextPoint()
            let c1 = reflectedControl(current: currentPoint, last: lastControl)
            let c2 = CGPoint(x: currentPoint.x + dc2.x, y: currentPoint.y + dc2.y)
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            path.addCurve(to: p, control1: c1, control2: c2)
            lastControl = c2
            currentPoint = p

        case "Q":
            let c = nextPoint()
            let p = nextPoint()
            path.addQuadCurve(to: p, control: c)
            lastControl = c
            currentPoint = p

        case "q":
            let dc = nextPoint()
            let dp = nextPoint()
            let c = CGPoint(x: currentPoint.x + dc.x, y: currentPoint.y + dc.y)
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            path.addQuadCurve(to: p, control: c)
            lastControl = c
            currentPoint = p

        case "T":
            let p = nextPoint()
            let c = reflectedControl(current: currentPoint, last: lastControl)
            path.addQuadCurve(to: p, control: c)
            lastControl = c
            currentPoint = p

        case "t":
            let dp = nextPoint()
            let p = CGPoint(x: currentPoint.x + dp.x, y: currentPoint.y + dp.y)
            let c = reflectedControl(current: currentPoint, last: lastControl)
            path.addQuadCurve(to: p, control: c)
            lastControl = c
            currentPoint = p

        case "A", "a":
            let rx = nextNumber()
            let ry = nextNumber()
            let rotation = nextNumber()
            let (largeArc, sweep) = nextArcFlags()
            let rawEnd = nextPoint()
            let endPoint = cmd == "a"
                ? CGPoint(x: currentPoint.x + rawEnd.x, y: currentPoint.y + rawEnd.y)
                : rawEnd
            addArc(to: &path, from: currentPoint, to: endPoint,
                   rx: rx, ry: ry, rotation: rotation,
                   largeArc: largeArc != 0, sweep: sweep != 0)
            currentPoint = endPoint
            lastControl = nil

        case "Z", "z":
            path.closeSubpath()
            currentPoint = startPoint
            lastControl = nil

        default:
            break
        }
    }

    private static func reflectedControl(current: CGPoint, last: CGPoint?) -> CGPoint {
        guard let last else { return current }
        return CGPoint(x: 2 * current.x - last.x, y: 2 * current.y - last.y)
    }

    // MARK: - Arc approximation using cubic Bézier curves

    private static func addArc(
        to path: inout Path,
        from p1: CGPoint, to p2: CGPoint,
        rx: CGFloat, ry: CGFloat,
        rotation: CGFloat,
        largeArc: Bool, sweep: Bool
    ) {
        guard rx > 0, ry > 0 else {
            path.addLine(to: p2)
            return
        }

        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2

        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        var rxSq = rx * rx
        var rySq = ry * ry
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p

        // Correct radii if too small
        let lambda = x1pSq / rxSq + y1pSq / rySq
        var correctedRx = rx
        var correctedRy = ry
        if lambda > 1 {
            let sqrtLambda = sqrt(lambda)
            correctedRx = sqrtLambda * rx
            correctedRy = sqrtLambda * ry
            rxSq = correctedRx * correctedRx
            rySq = correctedRy * correctedRy
        }

        let num = Swift.max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = rxSq * y1pSq + rySq * x1pSq
        guard den > 0 else {
            path.addLine(to: p2)
            return
        }

        var sq = sqrt(num / den)
        if largeArc == sweep { sq = -sq }

        let cxp = sq * correctedRx * y1p / correctedRy
        let cyp = -sq * correctedRy * x1p / correctedRx

        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        let theta1 = angle(ux: 1, uy: 0,
                           vx: (x1p - cxp) / correctedRx,
                           vy: (y1p - cyp) / correctedRy)
        var dtheta = angle(ux: (x1p - cxp) / correctedRx,
                           uy: (y1p - cyp) / correctedRy,
                           vx: (-x1p - cxp) / correctedRx,
                           vy: (-y1p - cyp) / correctedRy)
        if !sweep && dtheta > 0 { dtheta -= 2 * .pi }
        if sweep && dtheta < 0 { dtheta += 2 * .pi }

        // Approximate with cubic Bézier segments (max π/2 per segment)
        let segments = Int(ceil(abs(dtheta) / (.pi / 2)))
        let segmentAngle = dtheta / CGFloat(segments)

        var currentAngle = theta1
        for _ in 0..<segments {
            let endAngle = currentAngle + segmentAngle
            let alpha = 4.0 / 3.0 * tan(segmentAngle / 4)

            let cos1 = cos(currentAngle)
            let sin1 = sin(currentAngle)
            let cos2 = cos(endAngle)
            let sin2 = sin(endAngle)

            let ep1x = correctedRx * cos1
            let ep1y = correctedRy * sin1
            let ep2x = correctedRx * cos2
            let ep2y = correctedRy * sin2

            let c1x = ep1x - alpha * correctedRx * sin1
            let c1y = ep1y + alpha * correctedRy * cos1
            let c2x = ep2x + alpha * correctedRx * sin2
            let c2y = ep2y - alpha * correctedRy * cos2

            let pt1 = CGPoint(x: cosPhi * c1x - sinPhi * c1y + cx,
                              y: sinPhi * c1x + cosPhi * c1y + cy)
            let pt2 = CGPoint(x: cosPhi * c2x - sinPhi * c2y + cx,
                              y: sinPhi * c2x + cosPhi * c2y + cy)
            let pt3 = CGPoint(x: cosPhi * ep2x - sinPhi * ep2y + cx,
                              y: sinPhi * ep2x + cosPhi * ep2y + cy)

            path.addCurve(to: pt3, control1: pt1, control2: pt2)
            currentAngle = endAngle
        }
    }

    private static func angle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        guard len > 0 else { return 0 }
        var a = acos(min(max(dot / len, -1), 1))
        if ux * vy - uy * vx < 0 { a = -a }
        return a
    }

    // MARK: - Tokenizer

    /// Split SVG path data into command letters and numbers.
    /// Handles compact SVG notation where:
    /// - A second decimal point starts a new number (e.g. ".52.52" → ".52", ".52")
    /// - A minus sign starts a new number (e.g. "3-2" → "3", "-2")
    private static func tokenize(_ d: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in d {
            if char.isLetter && char != "e" && char != "E" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else if char == "," || char == " " || char == "\t" || char == "\n" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if char == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                tokens.append(current)
                current = String(char)
            } else if char == "." && current.contains(".") {
                // Second decimal point starts a new number (compact SVG notation)
                tokens.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
