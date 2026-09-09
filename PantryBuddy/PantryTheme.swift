import SwiftUI
import UIKit

enum PantryTheme {

    static let forest = Color(
        red: 0.08,
        green: 0.39,
        blue: 0.18
    )

    static let leaf = Color(
        red: 0.35,
        green: 0.67,
        blue: 0.14
    )

    static let lime = Color(
        red: 0.67,
        green: 0.84,
        blue: 0.20
    )

    static let cream = Color(
        red: 1.00,
        green: 0.97,
        blue: 0.86
    )

    static let gold = Color(
        red: 0.96,
        green: 0.67,
        blue: 0.14
    )

    static let ink = Color(
        uiColor: UIColor { traits in

            if traits.userInterfaceStyle
                == .dark {

                return UIColor(
                    red: 0.93,
                    green: 0.95,
                    blue: 0.92,
                    alpha: 1
                )

            } else {

                return UIColor(
                    red: 0.07,
                    green: 0.13,
                    blue: 0.08,
                    alpha: 1
                )
            }
        }
    )

    static let background = Color(
        uiColor: UIColor { traits in

            if traits.userInterfaceStyle
                == .dark {

                return UIColor(
                    red: 0.055,
                    green: 0.070,
                    blue: 0.058,
                    alpha: 1
                )

            } else {

                return UIColor(
                    red: 0.975,
                    green: 0.975,
                    blue: 0.955,
                    alpha: 1
                )
            }
        }
    )

    static let card = Color(
        uiColor: UIColor { traits in

            if traits.userInterfaceStyle
                == .dark {

                return UIColor(
                    red: 0.105,
                    green: 0.125,
                    blue: 0.108,
                    alpha: 1
                )

            } else {

                return UIColor(
                    red: 1,
                    green: 1,
                    blue: 0.99,
                    alpha: 1
                )
            }
        }
    )

    static let primaryGradient =
        LinearGradient(
            colors: [
                leaf,
                forest
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

    static let softGradient =
        LinearGradient(
            colors: [
                cream,
                cream.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
}
