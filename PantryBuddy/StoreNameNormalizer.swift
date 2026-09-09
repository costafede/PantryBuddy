import Foundation

enum StoreNameNormalizer {

    nonisolated static let commonStores = [
        "REMA 1000",
        "KIWI",
        "Coop Extra",
        "Coop Prix",
        "Coop Obs",
        "Coop Mega",
        "Coop Marked",
        "MENY",
        "Bunnpris",
        "SPAR",
        "Joker",
        "Oda",
        "Europris",
        "Holdbart",
        "Normal",
        "Matkroken"
    ]

    nonisolated static func canonicalName(
        _ rawName: String
    ) -> String {
        let cleaned = collapseWhitespace(
            rawName
        )

        guard !cleaned.isEmpty else {
            return "Negozio sconosciuto"
        }

        let key = normalizedKey(cleaned)

        if key.contains("REMA 1000")
            || key == "REMA" {
            return "REMA 1000"
        }

        if key.contains("KIWI") {
            return "KIWI"
        }

        if (
            key.contains("COOP")
            && key.contains("EXTRA")
        ) || key == "EXTRA" {
            return "Coop Extra"
        }

        if key.contains("COOP")
            && key.contains("PRIX") {
            return "Coop Prix"
        }

        if key.contains("COOP")
            && key.contains("MEGA") {
            return "Coop Mega"
        }

        if key.contains("COOP")
            && key.contains("MARKED") {
            return "Coop Marked"
        }

        if key == "OBS"
            || key.contains("COOP OBS") {
            return "Coop Obs"
        }

        if key == "COOP" {
            return "Coop"
        }

        if key.contains("MENY") {
            return "MENY"
        }

        if key.contains("BUNNPRIS") {
            return "Bunnpris"
        }

        if key == "SPAR"
            || key.contains("EUROSPAR") {
            return "SPAR"
        }

        if key.contains("JOKER") {
            return "Joker"
        }

        if key == "ODA"
            || key.hasPrefix("ODA ") {
            return "Oda"
        }

        if key.contains("EUROPRIS") {
            return "Europris"
        }

        if key.contains("HOLDBART") {
            return "Holdbart"
        }

        if key == "NORMAL"
            || key.hasPrefix("NORMAL ") {
            return "Normal"
        }

        if key.contains("MATKROKEN") {
            return "Matkroken"
        }

        return cleaned.localizedCapitalized
    }

    nonisolated static func groupingKey(
        _ rawName: String
    ) -> String {
        normalizedKey(
            canonicalName(rawName)
        )
    }

    nonisolated static func suggestions(
        existingNames: [String]
    ) -> [String] {
        var names = commonStores

        names.append(
            contentsOf:
                existingNames.map(
                    canonicalName
                )
        )

        var seen = Set<String>()

        return names.filter { name in
            seen.insert(
                groupingKey(name)
            ).inserted
        }
    }

    nonisolated private static func collapseWhitespace(
        _ text: String
    ) -> String {
        text
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .split(
                whereSeparator: {
                    $0.isWhitespace
                }
            )
            .joined(separator: " ")
    }

    nonisolated private static func normalizedKey(
        _ text: String
    ) -> String {
        collapseWhitespace(text)
            .folding(
                options:
                    .diacriticInsensitive,
                locale: .current
            )
            .uppercased()
            .replacingOccurrences(
                of:
                    #"[^A-Z0-9ÆØÅ]+"#,
                with: " ",
                options:
                    .regularExpression
            )
            .split(separator: " ")
            .joined(separator: " ")
    }
}
