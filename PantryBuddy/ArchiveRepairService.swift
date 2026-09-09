import Foundation
import SwiftData
import SwiftUI

struct ArchiveRepairReport: Identifiable {
    let id = UUID()
    let recoveredProducts: Int
    let mergedProducts: Int
    let correctedProducts: Int
    let removedInvalidPrices: Int
    let removedDuplicatePrices: Int
    let removedInvalidAliases: Int
    let removedDuplicateAliases: Int
    let normalizedStoreNames: Int

    var totalChanges: Int {
        recoveredProducts
            + mergedProducts
            + correctedProducts
            + removedInvalidPrices
            + removedDuplicatePrices
            + removedInvalidAliases
            + removedDuplicateAliases
            + normalizedStoreNames
    }

    var hasProblems: Bool {
        totalChanges > 0
    }

    var completionMessage: String {
        if !hasProblems {
            return "L’archivio non aveva bisogno di correzioni."
        }

        return """
        Sono state applicate \(totalChanges) correzioni. Prodotti, prezzi e associazioni sono ora coerenti.
        """
    }
}

@MainActor
enum ArchiveRepairService {
    static func inspect(
        products: [Product],
        priceRecords: [PriceRecord],
        receiptAliases: [ReceiptAlias]
    ) -> ArchiveRepairReport {
        let productGroups =
            Dictionary(grouping: products) {
                normalizedBarcode($0.barcode)
            }

        let mergedProducts =
            productGroups.reduce(0) {
                partial,
                entry in

                let key = entry.key
                let group = entry.value

                guard !key.isEmpty else {
                    return partial
                }

                return partial
                    + max(0, group.count - 1)
            }

        let correctedProducts =
            products.filter {
                normalizedBarcode($0.barcode).isEmpty
                    || cleanText($0.name).isEmpty
                    || $0.inventoryQuantity < 0
                    || (
                        $0.inventoryQuantity == 0
                        && $0.expirationDate != nil
                    )
                    || cleanText(
                        $0.storageLocation
                    ).isEmpty
                    || hasInvalidInventoryTracking(
                        $0
                    )
            }.count

        let representativeBarcodes =
            productRepresentativeMap(
                products: products
            )

        let validPrices =
            priceRecords.filter(isValidPrice)

        let invalidPrices =
            priceRecords.count
            - validPrices.count

        let existingProductBarcodes =
            Set(
                products.map {
                    representativeBarcodes[
                        $0.barcode
                    ] ?? $0.barcode
                }
            )

        let orphanBarcodes =
            Set(
                validPrices.compactMap {
                    record -> String? in

                    let mapped =
                        representativeBarcodes[
                            record.productBarcode
                        ]
                        ?? cleanText(
                            record.productBarcode
                        )

                    guard
                        !mapped.isEmpty,
                        !existingProductBarcodes
                            .contains(mapped)
                    else {
                        return nil
                    }

                    return mapped
                }
            )

        var priceKeys =
            Set<RepairPriceKey>()

        var duplicatePrices = 0

        for record in validPrices {
            let barcode =
                representativeBarcodes[
                    record.productBarcode
                ]
                ?? cleanText(
                    record.productBarcode
                )

            let key =
                priceKey(
                    record,
                    productBarcode: barcode
                )

            if !priceKeys.insert(key).inserted {
                duplicatePrices += 1
            }
        }

        let productBarcodesAfterRecovery =
            existingProductBarcodes
            .union(orphanBarcodes)

        var aliasKeys =
            Set<RepairAliasKey>()

        var invalidAliases = 0
        var duplicateAliases = 0

        for alias in receiptAliases {
            let barcode =
                representativeBarcodes[
                    alias.productBarcode
                ]
                ?? cleanText(
                    alias.productBarcode
                )

            guard
                isValidAlias(
                    alias,
                    availableBarcodes:
                        productBarcodesAfterRecovery,
                    mappedBarcode: barcode
                )
            else {
                invalidAliases += 1
                continue
            }

            let key =
                aliasKey(
                    alias,
                    productBarcode: barcode
                )

            if !aliasKeys.insert(key).inserted {
                duplicateAliases += 1
            }
        }

        let normalizedStores =
            priceRecords.filter {
                $0.storeName
                    != StoreNameNormalizer
                    .canonicalName(
                        $0.storeName
                    )
            }.count
            + receiptAliases.filter {
                $0.storeName
                    != StoreNameNormalizer
                    .canonicalName(
                        $0.storeName
                    )
            }.count

        return ArchiveRepairReport(
            recoveredProducts:
                orphanBarcodes.count,
            mergedProducts:
                mergedProducts,
            correctedProducts:
                correctedProducts,
            removedInvalidPrices:
                invalidPrices,
            removedDuplicatePrices:
                duplicatePrices,
            removedInvalidAliases:
                invalidAliases,
            removedDuplicateAliases:
                duplicateAliases,
            normalizedStoreNames:
                normalizedStores
        )
    }

    static func repair(
        products: [Product],
        priceRecords: [PriceRecord],
        receiptAliases: [ReceiptAlias],
        in modelContext: ModelContext
    ) -> ArchiveRepairReport {
        let expectedReport =
            inspect(
                products: products,
                priceRecords: priceRecords,
                receiptAliases:
                    receiptAliases
            )

        var representativeBarcodes:
            [String: String] = [:]

        var survivingProducts:
            [String: Product] = [:]

        var notificationBarcodesToCancel =
            Set<String>()

        let productGroups =
            Dictionary(grouping: products) {
                normalizedBarcode($0.barcode)
            }

        for (normalized, group)
        in productGroups {
            guard !normalized.isEmpty else {
                for product in group {
                    let previousBarcode =
                        product.barcode

                    let recoveredBarcode =
                        "catalog-recovered-\(UUID().uuidString)"

                    representativeBarcodes[
                        product.barcode
                    ] = recoveredBarcode

                    product.barcode =
                        recoveredBarcode

                    if previousBarcode
                        != recoveredBarcode
                    {
                        notificationBarcodesToCancel
                            .insert(
                                previousBarcode
                            )
                    }

                    correctProductFields(
                        product
                    )

                    survivingProducts[
                        recoveredBarcode
                    ] = product
                }

                continue
            }

            let survivor =
                preferredProduct(
                    in: group,
                    normalizedBarcode:
                        normalized
                )

            let destinationBarcode =
                normalized

            for product in group {
                notificationBarcodesToCancel
                    .insert(product.barcode)
            }

            for product in group {
                representativeBarcodes[
                    product.barcode
                ] = destinationBarcode
            }

            for duplicate in group
            where duplicate !== survivor {
                mergeProduct(
                    duplicate,
                    into: survivor
                )
            }

            for record in priceRecords {
                if
                    let destination =
                        representativeBarcodes[
                            record.productBarcode
                        ],
                    destination
                        != record.productBarcode
                {
                    record.productBarcode =
                        destination
                }
            }

            for alias in receiptAliases {
                if
                    let destination =
                        representativeBarcodes[
                            alias.productBarcode
                        ],
                    destination
                        != alias.productBarcode
                {
                    alias.productBarcode =
                        destination
                }
            }

            for duplicate in group
            where duplicate !== survivor {
                modelContext.delete(
                    duplicate
                )
            }

            survivor.barcode =
                destinationBarcode

            correctProductFields(
                survivor
            )

            survivingProducts[
                survivor.barcode
            ] = survivor
        }

        var validPrices:
            [PriceRecord] = []

        for record in priceRecords {
            record.productBarcode =
                representativeBarcodes[
                    record.productBarcode
                ]
                ?? cleanText(
                    record.productBarcode
                )

            guard isValidPrice(record) else {
                modelContext.delete(record)
                continue
            }

            record.storeName =
                StoreNameNormalizer
                .canonicalName(
                    record.storeName
                )

            record.receiptDescription =
                cleanText(
                    record.receiptDescription
                )

            validPrices.append(record)
        }

        var availableProducts =
            survivingProducts

        let orphanGroups =
            Dictionary(
                grouping: validPrices
            ) {
                $0.productBarcode
            }

        for (barcode, records)
        in orphanGroups
        where availableProducts[barcode] == nil {
            let product = Product(
                barcode: barcode,
                name:
                    recoveredProductName(
                        from: records
                    ),
                brand: "",
                packageQuantity: "",
                imageURL: nil,
                inventoryQuantity: 0,
                storageLocation: "Dispensa"
            )

            if
                let oldestDate =
                    records
                    .map(\.purchaseDate)
                    .min()
            {
                product.addedAt =
                    oldestDate
            }

            modelContext.insert(product)

            availableProducts[
                barcode
            ] = product
        }

        var knownPriceKeys =
            Set<RepairPriceKey>()

        for record in validPrices.sorted(
            by: {
                $0.purchaseDate
                    < $1.purchaseDate
            }
        ) {
            let key =
                priceKey(
                    record,
                    productBarcode:
                        record.productBarcode
                )

            if
                !knownPriceKeys
                    .insert(key)
                    .inserted
            {
                modelContext.delete(record)
            }
        }

        let availableBarcodes =
            Set(availableProducts.keys)

        var aliasesByKey:
            [RepairAliasKey: ReceiptAlias] = [:]

        for alias in receiptAliases.sorted(
            by: {
                $0.createdAt < $1.createdAt
            }
        ) {
            alias.productBarcode =
                representativeBarcodes[
                    alias.productBarcode
                ]
                ?? cleanText(
                    alias.productBarcode
                )

            guard
                isValidAlias(
                    alias,
                    availableBarcodes:
                        availableBarcodes,
                    mappedBarcode:
                        alias.productBarcode
                )
            else {
                modelContext.delete(alias)
                continue
            }

            alias.storeName =
                StoreNameNormalizer
                .canonicalName(
                    alias.storeName
                )

            alias.receiptText =
                cleanText(
                    alias.receiptText
                )

            let key =
                aliasKey(
                    alias,
                    productBarcode:
                        alias.productBarcode
                )

            if let survivor =
                aliasesByKey[key]
            {
                survivor.createdAt = min(
                    survivor.createdAt,
                    alias.createdAt
                )

                survivor.lastSeenAt = max(
                    survivor.lastSeenAt,
                    alias.lastSeenAt
                )

                modelContext.delete(alias)
            } else {
                aliasesByKey[key] = alias
            }
        }

        let productsToRefresh =
            Array(availableProducts.values)

        Task { @MainActor in
            for barcode in
                notificationBarcodesToCancel
            {
                ProductExpirationService
                    .cancelNotifications(
                        forBarcode: barcode
                    )
            }

            for product in productsToRefresh {
                _ = await ProductExpirationService
                    .scheduleNotifications(
                        for: product
                    )
            }
        }

        return expectedReport
    }

    private static func productRepresentativeMap(
        products: [Product]
    ) -> [String: String] {
        let groups =
            Dictionary(
                grouping: products
            ) {
                normalizedBarcode($0.barcode)
            }

        var result:
            [String: String] = [:]

        for (normalized, group)
        in groups
        where !normalized.isEmpty {
            for product in group {
                result[
                    product.barcode
                ] = normalized
            }
        }

        return result
    }

    private static func preferredProduct(
        in products: [Product],
        normalizedBarcode: String
    ) -> Product {
        products.sorted {
            first,
            second in

            let firstExact =
                first.barcode
                == normalizedBarcode

            let secondExact =
                second.barcode
                == normalizedBarcode

            if firstExact != secondExact {
                return firstExact
            }

            let firstScore =
                productScore(first)

            let secondScore =
                productScore(second)

            if firstScore != secondScore {
                return firstScore
                    > secondScore
            }

            return first.addedAt
                < second.addedAt
        }.first!
    }

    private static func productScore(
        _ product: Product
    ) -> Int {
        var score =
            product.inventoryQuantity > 0
            ? 10
            : 0

        if !cleanText(product.name).isEmpty {
            score += 4
        }

        if !cleanText(product.brand).isEmpty {
            score += 2
        }

        if
            !cleanText(
                product.packageQuantity
            ).isEmpty
        {
            score += 2
        }

        if product.localImageData != nil {
            score += 3
        } else if product.imageURL != nil {
            score += 1
        }

        if
            product.inventoryTrackingMode
                == .containedUnits
        {
            score += 3
        }

        return score
    }

    private static func mergeProduct(
        _ source: Product,
        into destination: Product
    ) {
        let mergedExpirationDate =
            expirationDateForMerge(
                destination,
                source
            )

        if cleanText(destination.name).isEmpty {
            destination.name = source.name
        }

        if cleanText(destination.brand).isEmpty {
            destination.brand = source.brand
        }

        if
            cleanText(
                destination.packageQuantity
            ).isEmpty
        {
            destination.packageQuantity =
                source.packageQuantity
        }

        if destination.imageURL == nil {
            destination.imageURL =
                source.imageURL
        }

        if destination.localImageData == nil {
            destination.localImageData =
                source.localImageData
        }

        if
            cleanText(
                destination.storageLocation
            ).isEmpty
        {
            destination.storageLocation =
                source.storageLocation
        }

        mergeInventoryTracking(
            from: source,
            into: destination
        )

        destination.expirationDate =
            mergedExpirationDate

        destination.addedAt = min(
            destination.addedAt,
            source.addedAt
        )
    }

    private static func correctProductFields(
        _ product: Product
    ) {
        product.name =
            cleanText(product.name)

        product.brand =
            cleanText(product.brand)

        product.packageQuantity =
            cleanText(
                product.packageQuantity
            )

        product.storageLocation =
            cleanText(
                product.storageLocation
            )

        if product.name.isEmpty {
            product.name =
                "Prodotto recuperato"
        }

        if product.storageLocation.isEmpty {
            product.storageLocation =
                "Dispensa"
        }

        if product.inventoryQuantity < 0 {
            product.inventoryQuantity = 0
        }

        if product.inventoryQuantity == 0 {
            product.expirationDate = nil
        } else if let expirationDate =
                    product.expirationDate
        {
            product.expirationDate =
                Calendar.current.startOfDay(
                    for: expirationDate
                )
        }

        switch
            product.inventoryTrackingMode
        {
        case .packages:
            product.inventoryTrackingRawValue =
                InventoryTrackingMode
                .packages.rawValue

            product.unitsPerPackage = 1
            product.inventoryUnitName =
                "unità"

        case .containedUnits:
            product.inventoryTrackingRawValue =
                InventoryTrackingMode
                .containedUnits.rawValue

            product.unitsPerPackage = max(
                2,
                product.normalizedUnitsPerPackage
            )

            product.inventoryUnitName =
                product
                .normalizedInventoryUnitName
        }
    }

    private static func hasInvalidInventoryTracking(
        _ product: Product
    ) -> Bool {
        if
            let rawValue =
                product.inventoryTrackingRawValue,
            InventoryTrackingMode(
                rawValue: rawValue
            ) == nil
        {
            return true
        }

        return
            product.inventoryTrackingMode
                == .containedUnits
            && product.normalizedUnitsPerPackage
                < 2
    }

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

    private static func mergeInventoryTracking(
        from source: Product,
        into destination: Product
    ) {
        switch (
            destination.inventoryTrackingMode,
            source.inventoryTrackingMode
        ) {
        case (.packages, .packages):
            destination.inventoryQuantity =
                max(
                    destination.inventoryQuantity,
                    source.inventoryQuantity
                )

        case (
            .containedUnits,
            .containedUnits
        ):
            destination.inventoryQuantity =
                max(
                    destination.inventoryQuantity,
                    source.inventoryQuantity
                )

            if
                destination.normalizedUnitsPerPackage
                    < 2,
                source.normalizedUnitsPerPackage
                    >= 2
            {
                destination.unitsPerPackage =
                    source.normalizedUnitsPerPackage
            }

            if
                destination
                    .normalizedInventoryUnitName
                    == "unità",
                source
                    .normalizedInventoryUnitName
                    != "unità"
            {
                destination.inventoryUnitName =
                    source
                    .normalizedInventoryUnitName
            }

        case (
            .packages,
            .containedUnits
        ):
            let sourceUnitsPerPackage =
                max(
                    2,
                    source
                        .normalizedUnitsPerPackage
                )

            let convertedDestinationQuantity =
                destination.inventoryQuantity
                * sourceUnitsPerPackage

            destination.inventoryQuantity =
                max(
                    convertedDestinationQuantity,
                    source.inventoryQuantity
                )

            copyInventoryTracking(
                from: source,
                to: destination
            )

        case (
            .containedUnits,
            .packages
        ):
            let convertedSourceQuantity =
                source.inventoryQuantity
                * max(
                    2,
                    destination
                        .normalizedUnitsPerPackage
                )

            destination.inventoryQuantity =
                max(
                    destination.inventoryQuantity,
                    convertedSourceQuantity
                )
        }
    }

    private static func copyInventoryTracking(
        from source: Product,
        to destination: Product
    ) {
        destination.inventoryTrackingRawValue =
            InventoryTrackingMode
            .containedUnits.rawValue

        destination.unitsPerPackage =
            max(
                2,
                source.normalizedUnitsPerPackage
            )

        destination.inventoryUnitName =
            source.normalizedInventoryUnitName
    }

    private static func recoveredProductName(
        from records: [PriceRecord]
    ) -> String {
        let newestDescriptions =
            records
            .sorted {
                $0.purchaseDate
                    > $1.purchaseDate
            }
            .map {
                cleanText(
                    $0.receiptDescription
                )
            }

        return newestDescriptions.first {
            !$0.isEmpty
        } ?? "Prodotto recuperato"
    }

    private static func isValidPrice(
        _ record: PriceRecord
    ) -> Bool {
        record.price.isFinite
            && record.price >= 0
            && !cleanText(
                record.productBarcode
            ).isEmpty
    }

    private static func isValidAlias(
        _ alias: ReceiptAlias,
        availableBarcodes: Set<String>,
        mappedBarcode: String
    ) -> Bool {
        !mappedBarcode.isEmpty
            && !cleanText(
                alias.receiptText
            ).isEmpty
            && availableBarcodes.contains(
                mappedBarcode
            )
    }

    private static func priceKey(
        _ record: PriceRecord,
        productBarcode: String
    ) -> RepairPriceKey {
        RepairPriceKey(
            productBarcode:
                productBarcode,
            storeKey:
                StoreNameNormalizer.groupingKey(
                    record.storeName
                ),
            receiptKey:
                normalizedText(
                    record.receiptDescription
                ),
            priceInCents:
                Int64(
                    (record.price * 100)
                        .rounded()
                ),
            purchaseSecond:
                Int64(
                    record.purchaseDate
                        .timeIntervalSince1970
                )
        )
    }

    private static func aliasKey(
        _ alias: ReceiptAlias,
        productBarcode: String
    ) -> RepairAliasKey {
        RepairAliasKey(
            storeKey:
                StoreNameNormalizer.groupingKey(
                    alias.storeName
                ),
            receiptKey:
                normalizedText(
                    alias.receiptText
                ),
            productBarcode:
                productBarcode
        )
    }

    private static func normalizedBarcode(
        _ barcode: String
    ) -> String {
        cleanText(barcode)
    }

    private static func cleanText(
        _ text: String
    ) -> String {
        text.components(
            separatedBy:
                .whitespacesAndNewlines
        )
        .filter {
            !$0.isEmpty
        }
        .joined(separator: " ")
    }

    private static func normalizedText(
        _ text: String
    ) -> String {
        cleanText(text).folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive
            ],
            locale: Locale(
                identifier: "en_US_POSIX"
            )
        )
    }
}

private struct RepairPriceKey: Hashable {
    let productBarcode: String
    let storeKey: String
    let receiptKey: String
    let priceInCents: Int64
    let purchaseSecond: Int64
}

private struct RepairAliasKey: Hashable {
    let storeKey: String
    let receiptKey: String
    let productBarcode: String
}

struct ArchiveRepairPreviewView: View {
    @Environment(\.dismiss)
    private var dismiss

    let report: ArchiveRepairReport
    let onRepair: () -> Void

    @State
    private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(spacing: 18) {
                        headerCard
                        changesCard
                        explanationCard
                        repairButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Ripara archivio")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbarBackground(
                PantryTheme.background,
                for: .navigationBar
            )
            .toolbarBackground(
                .visible,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Applicare le correzioni?",
                isPresented:
                    $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Ripara archivio") {
                    onRepair()
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    "I dati validi e tutto lo storico prezzi verranno conservati."
                )
            }
        }
        .tint(PantryTheme.forest)
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(
                systemName:
                    "wrench.and.screwdriver.fill"
            )
            .font(.system(size: 34))
            .foregroundStyle(
                PantryTheme.forest
            )
            .frame(
                width: 68,
                height: 68
            )
            .background(
                PantryTheme.forest.opacity(
                    0.10
                ),
                in: RoundedRectangle(
                    cornerRadius: 21
                )
            )

            Text(
                "Sono state trovate alcune correzioni"
            )
            .font(.title3.bold())
            .foregroundStyle(
                PantryTheme.ink
            )
            .multilineTextAlignment(
                .center
            )

            Text(
                "Controlla il riepilogo prima di procedere."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private var changesCard: some View {
        VStack(spacing: 0) {
            repairRow(
                title: "Prodotti recuperati",
                value:
                    report.recoveredProducts,
                icon: "shippingbox.fill"
            )

            repairRow(
                title:
                    "Prodotti duplicati uniti",
                value:
                    report.mergedProducts,
                icon: "arrow.triangle.merge"
            )

            repairRow(
                title: "Prodotti corretti",
                value:
                    report.correctedProducts,
                icon:
                    "pencil.and.list.clipboard"
            )

            repairRow(
                title:
                    "Prezzi non validi rimossi",
                value:
                    report.removedInvalidPrices,
                icon: "tag.slash"
            )

            repairRow(
                title:
                    "Prezzi duplicati rimossi",
                value:
                    report.removedDuplicatePrices,
                icon: "tag.fill"
            )

            repairRow(
                title:
                    "Associazioni non valide rimosse",
                value:
                    report.removedInvalidAliases,
                icon: "link.badge.plus"
            )

            repairRow(
                title:
                    "Associazioni duplicate unite",
                value:
                    report.removedDuplicateAliases,
                icon: "link"
            )

            repairRow(
                title:
                    "Nomi negozio uniformati",
                value:
                    report.normalizedStoreNames,
                icon: "storefront.fill",
                showDivider: false
            )
        }
        .padding(.horizontal, 18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    @ViewBuilder
    private func repairRow(
        title: String,
        value: Int,
        icon: String,
        showDivider: Bool = true
    ) -> some View {
        if value > 0 {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(
                            .system(
                                size: 16,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            PantryTheme.forest
                        )
                        .frame(
                            width: 38,
                            height: 38
                        )
                        .background(
                            PantryTheme.forest
                                .opacity(0.10),
                            in: RoundedRectangle(
                                cornerRadius: 12
                            )
                        )

                    Text(title)
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )
                        .foregroundStyle(
                            PantryTheme.ink
                        )

                    Spacer()

                    Text("\(value)")
                        .font(
                            .headline
                                .monospacedDigit()
                        )
                        .foregroundStyle(
                            PantryTheme.forest
                        )
                }
                .padding(.vertical, 12)

                if showDivider {
                    Divider()
                }
            }
        }
    }

    private var explanationCard: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                "Cosa succederà",
                systemImage:
                    "checkmark.shield.fill"
            )
            .font(.headline)
            .foregroundStyle(
                PantryTheme.ink
            )

            Text(
                """
                I prezzi senza prodotto verranno recuperati nel Catalogo. \
                Dei duplicati resterà una sola copia. \
                Le associazioni inutilizzabili verranno eliminate.
                """
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private var repairButton: some View {
        Button {
            showConfirmation = true
        } label: {
            Label(
                "Controlla e ripara",
                systemImage:
                    "wrench.and.screwdriver.fill"
            )
            .font(.headline)
            .foregroundStyle(
                PantryTheme.cream
            )
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                PantryTheme.primaryGradient,
                in: RoundedRectangle(
                    cornerRadius: 18
                )
            )
        }
        .buttonStyle(.plain)
    }
}
