import UIKit

extension UIColor {
    /// Linearly interpolates between `self` and `other` by `ratio` (0 = self, 1 = other).
    func blended(with other: UIColor, ratio: CGFloat) -> UIColor {
        let clamped = max(0, min(1, ratio))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + ((r2 - r1) * clamped),
            green: g1 + ((g2 - g1) * clamped),
            blue: b1 + ((b2 - b1) * clamped),
            alpha: a1 + ((a2 - a1) * clamped)
        )
    }
}
