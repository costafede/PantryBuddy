import Foundation
import SwiftData

struct ProductDuplicateSuggestion: Identifiable {
    let first: Product
    let second: Product
    let score: Double

    var id: String {
        [first.barcode, second.barcode]
            .sorted()
            .joined(separator: ":::")
    }
}

enum ProductMergeService {

    static func suggestions(
        products: [Product],
        priceRecords: [PriceRecord]
    ) -> [ProductDuplicateSuggestion] {
        guard products.count > 1 else {
            return []
        }

        let recordsByBarcode = Dictionary(
            grouping: priceRecords,
            by: \.productBarcode
        )

        var result: [ProductDuplicateSuggestion] = []

        for firstIndex in products.indices {
            let nextIndex = products.index(
                after: firstIndex
            )

            guard nextIndex < products.endIndex else {
                continue
            }

            for secondIndex in nextIndex..<products.endIndex {
                let first = products[firstIndex]
                let second = products[secondIndex]

                let score = duplicateScore(
                    first: first,
                    second: second,
                    firstRecords:
                        recordsByBarcode[first.barcode] ?? [],
                    secondRecords:
                        recordsByBarcode[second.barcode] ?? []
                )

                if score >= 0.60 {
                    result.append(
                        ProductDuplicateSuggestion(
                            first: first,
                            second: second,
                            score: score
                        )
                    )
                }
            }
        }

        return result.sorted {
            $0.score > $1.score
        }
    }

    @MainActor
    static func merge(
        first: Product,
        second: Product,
        priceRecords: [PriceRecord],
        receiptAliases: [ReceiptAlias],
        modelContext: ModelContext
    ) throws -> Product {
        let choice = chooseKeeper(
            first: first,
            second: second
        )

        let keeper = choice.keeper
        let discarded = choice.discarded

        let discardedBarcode =
            discarded.barcode

        let mergedExpirationDate =
            expirationDateForMerge(
                keeper,
                discarded
            )

        // Conserva tutti i prezzi cambiandone solo il collegamento.
        for record in priceRecords
        where record.productBarcode == discarded.barcode {
            record.productBarcode = keeper.barcode
        }

        // Gli scontrini futuri useranno il prodotto mantenuto.
        for alias in receiptAliases
        where alias.productBarcode == discarded.barcode {
            alias.productBarcode = keeper.barcode
            alias.lastSeenAt = Date()
        }

        mergeInventory(
            from: discarded,
            into: keeper
        )

        keeper.expirationDate =
            mergedExpirationDate

        if keeper.brand.isEmpty {
            keeper.brand = discarded.brand
        }

        if keeper.packageQuantity.isEmpty {
            keeper.packageQuantity =
                discarded.packageQuantity
        }

        if keeper.imageURL == nil {
            keeper.imageURL = discarded.imageURL
        }

        if keeper.localImageData == nil {
            keeper.localImageData =
                discarded.localImageData
        }

        if isCatalogOnly(keeper.storageLocation),
           !isCatalogOnly(discarded.storageLocation) {
            keeper.storageLocation =
                discarded.storageLocation
        }

        keeper.addedAt = min(
            keeper.addedAt,
            discarded.addedAt
        )

        modelContext.delete(discarded)
        try modelContext.save()

        ProductExpirationService
            .cancelNotifications(
                forBarcode: discardedBarcode
            )

        Task { @MainActor in
            _ = await ProductExpirationService
                .scheduleNotifications(
                    for: keeper
                )
        }

        return keeper
    }

    // MARK: - Scadenza

    private static func expirationDateForMerge(
        _ first: Product,
        _ second: Product
    ) -> Date? {
        let dates = [first, second]
            .compactMap { product -> Date? in
                guard product.inventoryQuantity > 0 else {
                    return nil
                }

                return product.expirationDate
            }

        guard let nearestDate = dates.min() else {
            return nil
        }

        return Calendar.current.startOfDay(
            for: nearestDate
        )
    }

    // MARK: - Quantità e modalità di conteggio

    private static func mergeInventory(
        from discarded: Product,
        into keeper: Product
    ) {
        let keeperMode =
            keeper.inventoryTrackingMode

        let discardedMode =
            discarded.inventoryTrackingMode

        switch (keeperMode, discardedMode) {
        case (.packages, .packages):
            keeper.inventoryQuantity +=
                discarded.inventoryQuantity

        case (.containedUnits, .containedUnits):
            keeper.inventoryQuantity +=
                discarded.inventoryQuantity

            if keeper.normalizedInventoryUnitName
                == "unità",
               discarded.normalizedInventoryUnitName
                != "unità" {
                keeper.inventoryUnitName =
                    discarded
                        .normalizedInventoryUnitName
            }

            if keeper.normalizedUnitsPerPackage <= 1 {
                keeper.unitsPerPackage =
                    discarded
                        .normalizedUnitsPerPackage
            }

        case (.packages, .containedUnits):
            let convertedKeeperQuantity =
                keeper.inventoryQuantity
                * discarded
                    .normalizedUnitsPerPackage

            keeper.inventoryQuantity =
                convertedKeeperQuantity
                + discarded.inventoryQuantity

            copyTrackingSettings(
                from: discarded,
                to: keeper
            )

        case (.containedUnits, .packages):
            let convertedDiscardedQuantity =
                discarded.inventoryQuantity
                * keeper.normalizedUnitsPerPackage

            keeper.inventoryQuantity +=
                convertedDiscardedQuantity
        }
    }

    private static func copyTrackingSettings(
        from source: Product,
        to destination: Product
    ) {
        destination.inventoryTrackingRawValue =
            source.inventoryTrackingMode.rawValue

        destination.unitsPerPackage =
            source.normalizedUnitsPerPackage

        destination.inventoryUnitName =
            source.normalizedInventoryUnitName
    }

    // MARK: - Rilevamento duplicati

    private static func duplicateScore(
        first: Product,
        second: Product,
        firstRecords: [PriceRecord],
        secondRecords: [PriceRecord]
    ) -> Double {
        let firstTexts = comparisonTexts(
            first,
            records: firstRecords
        )

        let secondTexts = comparisonTexts(
            second,
            records: secondRecords
        )

        var best = 0.0

        for left in firstTexts {
            for right in secondTexts {
                best = max(
                    best,
                    similarity(left, right)
                )
            }
        }

        return best
    }

    private static func comparisonTexts(
        _ product: Product,
        records: [PriceRecord]
    ) -> [String] {
        var texts = [product.name]

        if !product.brand.isEmpty {
            texts.append(
                "\(product.brand) \(product.name)"
            )
        }

        texts.append(
            contentsOf: records
                .map(\.receiptDescription)
                .filter { !$0.isEmpty }
        )

        return Array(Set(texts))
    }

    private static func similarity(
        _ leftText: String,
        _ rightText: String
    ) -> Double {
        let left = normalize(leftText)
        let right = normalize(rightText)

        guard left.count >= 4,
              right.count >= 4 else {
            return 0
        }

        if left == right {
            return 1
        }

        let leftCompact = left.replacingOccurrences(
            of: " ",
            with: ""
        )

        let rightCompact = right.replacingOccurrences(
            of: " ",
            with: ""
        )

        var score = 0.0

        if min(
            leftCompact.count,
            rightCompact.count
        ) >= 7,
           leftCompact.contains(rightCompact)
            || rightCompact.contains(leftCompact) {

            score = 0.94
        }

        let leftWords = words(left)
        let rightWords = words(right)

        let commonWords =
            leftWords.intersection(rightWords)

        if commonWords.count >= 2 {
            score = max(
                score,
                Double(commonWords.count)
                    / Double(
                        min(
                            leftWords.count,
                            rightWords.count
                        )
                    )
            )
        }

        let prefixCount =
            zip(leftCompact, rightCompact)
                .prefix { $0 == $1 }
                .count

        if prefixCount >= 8 {
            score = max(
                score,
                Double(prefixCount)
                    / Double(
                        min(
                            leftCompact.count,
                            rightCompact.count
                        )
                    )
            )
        }

        return min(score, 1)
    }

    private static func normalize(
        _ text: String
    ) -> String {
        text
            .uppercased()
            .folding(
                options: .diacriticInsensitive,
                locale: .current
            )
            .replacingOccurrences(
                of: #"[^A-Z0-9ÆØÅ]+"#,
                with: " ",
                options: .regularExpression
            )
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func words(
        _ text: String
    ) -> Set<String> {
        let ignored: Set<String> = [
            "AS",
            "ASA",
            "THE",
            "OF",
            "OG",
            "MED"
        ]

        return Set(
            text
                .split(separator: " ")
                .map(String.init)
                .filter {
                    $0.count >= 2
                        && !ignored.contains($0)
                }
        )
    }

    // MARK: - Scelta prodotto da mantenere

    private static func chooseKeeper(
        first: Product,
        second: Product
    ) -> (
        keeper: Product,
        discarded: Product
    ) {
        let firstIsSynthetic =
            first.barcode.hasPrefix("catalog-")

        let secondIsSynthetic =
            second.barcode.hasPrefix("catalog-")

        // Se uno arriva dallo scanner,
        // viene sempre mantenuto il barcode vero.
        if firstIsSynthetic != secondIsSynthetic {
            return firstIsSynthetic
                ? (second, first)
                : (first, second)
        }

        return quality(first) >= quality(second)
            ? (first, second)
            : (second, first)
    }

    private static func quality(
        _ product: Product
    ) -> Int {
        var value =
            product.inventoryQuantity > 0 ? 20 : 0

        if product.localImageData != nil {
            value += 10
        } else if product.imageURL != nil {
            value += 8
        }

        if !product.brand.isEmpty {
            value += 5
        }

        if !product.packageQuantity.isEmpty {
            value += 5
        }

        if product.inventoryTrackingMode
            == .containedUnits {
            value += 3
        }

        value += min(product.name.count, 30)

        return value
    }

    private static func isCatalogOnly(
        _ location: String
    ) -> Bool {
        location
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .localizedCaseInsensitiveCompare(
                "Solo catalogo"
            ) == .orderedSame
    }
}
