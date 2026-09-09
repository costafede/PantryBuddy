import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Product.name)
    private var products: [Product]

    @Query(
        sort: \PriceRecord.purchaseDate,
        order: .reverse
    )
    private var priceRecords: [PriceRecord]

    @Query
    private var receiptAliases: [ReceiptAlias]

    @AppStorage("PantryBuddyIgnoredDuplicatePairs")
    private var ignoredDuplicatePairs = ""

    @State private var exportedFile: ExportedFile?
    @State private var pendingImport: PendingBackupImport?
    @State private var pendingRepairReport: ArchiveRepairReport?
    @State private var showBackupImporter = false
    @State private var showProductManager = false
    @State private var showDeleteEverythingConfirmation = false
    @State private var showFinalDeleteEverythingConfirmation = false
    @State private var notice: SettingsNotice?

    private var pantryProducts: [Product] {
        products.filter {
            $0.inventoryQuantity > 0
        }
    }

    private var pantryUnitCount: Int {
        pantryProducts.reduce(0) {
            $0 + $1.inventoryQuantity
        }
    }

    private var storeCount: Int {
        Set(
            priceRecords.map {
                StoreNameNormalizer.groupingKey(
                    $0.storeName
                )
            }
        ).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(spacing: 18) {
                        statisticsCard
                        dataActionsCard
                        dangerCard
                        appInformationCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Impostazioni")
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
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundStyle(
                        PantryTheme.forest
                    )
                }
            }
            .sheet(item: $exportedFile) { file in
                ActivityShareView(
                    items: [file.url]
                )
            }
            .sheet(item: $pendingImport) { pending in
                BackupImportPreviewView(
                    pendingImport: pending,
                    currentProductCount:
                        products.count,
                    currentPriceCount:
                        priceRecords.count,
                    currentAliasCount:
                        receiptAliases.count,
                    onMerge: {
                        pendingImport = nil

                        importBackup(
                            pending.backup,
                            mode: .merge
                        )
                    },
                    onReplace: {
                        pendingImport = nil

                        importBackup(
                            pending.backup,
                            mode: .replace
                        )
                    }
                )
            }
            .sheet(item: $pendingRepairReport) { report in
                ArchiveRepairPreviewView(
                    report: report,
                    onRepair: {
                        pendingRepairReport = nil
                        repairArchive()
                    }
                )
            }
            .sheet(
                isPresented: $showProductManager
            ) {
                ProductDataManagementView()
            }
            .fileImporter(
                isPresented: $showBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleSelectedBackup(result)
            }
            .confirmationDialog(
                "Cancellare tutti i dati?",
                isPresented:
                    $showDeleteEverythingConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "Continua",
                    role: .destructive
                ) {
                    showFinalDeleteEverythingConfirmation =
                        true
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    """
                    Verranno eliminati dispensa, catalogo, storico prezzi e associazioni degli scontrini. \
                    Prima puoi esportare un backup.
                    """
                )
            }
            .alert(
                "Ultima conferma",
                isPresented:
                    $showFinalDeleteEverythingConfirmation
            ) {
                Button(
                    "Elimina tutto",
                    role: .destructive
                ) {
                    deleteEverything()
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    """
                    L’archivio verrà eliminato definitivamente. \
                    Questa operazione non può essere annullata.
                    """
                )
            }
            .alert(item: $notice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(
                        Text("OK")
                    )
                )
            }
        }
        .tint(PantryTheme.forest)
    }

    private var statisticsCard: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Label(
                "I tuoi dati",
                systemImage: "chart.bar.fill"
            )
            .font(.headline)
            .foregroundStyle(PantryTheme.ink)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 10
            ) {
                statistic(
                    value: "\(products.count)",
                    title: "Prodotti",
                    icon: "shippingbox.fill",
                    color: PantryTheme.forest
                )

                statistic(
                    value: "\(pantryUnitCount)",
                    title: "Unità in casa",
                    icon: "cabinet.fill",
                    color: PantryTheme.leaf
                )

                statistic(
                    value: "\(priceRecords.count)",
                    title: "Prezzi",
                    icon: "tag.fill",
                    color: PantryTheme.gold
                )

                statistic(
                    value: "\(storeCount)",
                    title: "Supermercati",
                    icon: "storefront.fill",
                    color: PantryTheme.forest
                )
            }
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22
            )
            .stroke(
                PantryTheme.forest.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private func statistic(
        value: String,
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .foregroundStyle(color)
                .frame(
                    width: 34,
                    height: 34
                )
                .background(
                    color.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 10
                    )
                )

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(value)
                    .font(
                        .headline
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            PantryTheme.background,
            in: RoundedRectangle(
                cornerRadius: 15
            )
        )
    }

    private var dataActionsCard: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text("Gestione dati")
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)
                .padding(.bottom, 8)

            settingsAction(
                title: "Gestisci prodotti",
                subtitle:
                    "Rimuovi dalla dispensa o elimina definitivamente",
                icon:
                    "shippingbox.and.arrow.backward.fill",
                color: PantryTheme.forest
            ) {
                showProductManager = true
            }

            Divider()

            settingsAction(
                title: "Controlla e ripara dati",
                subtitle:
                    "Recupera prezzi e rimuove duplicati non validi",
                icon:
                    "wrench.and.screwdriver.fill",
                color: PantryTheme.forest
            ) {
                inspectArchive()
            }

            Divider()

            settingsAction(
                title: "Esporta backup",
                subtitle:
                    "Salva dati, scadenze e foto in un file JSON",
                icon: "square.and.arrow.up",
                color: PantryTheme.forest
            ) {
                exportBackup()
            }

            Divider()

            settingsAction(
                title: "Importa backup",
                subtitle:
                    "Ripristina o unisci un archivio JSON",
                icon: "square.and.arrow.down",
                color: PantryTheme.forest
            ) {
                showBackupImporter = true
            }

            Divider()

            settingsAction(
                title: "Esporta storico prezzi",
                subtitle:
                    "Crea un file CSV da aprire con Excel o Numbers",
                icon: "tablecells",
                color: PantryTheme.gold
            ) {
                exportPriceHistoryCSV()
            }

            Divider()

            settingsAction(
                title: "Uniforma supermercati",
                subtitle:
                    "Unisce le diverse scritture dello stesso negozio",
                icon: "wand.and.stars",
                color: PantryTheme.gold
            ) {
                normalizeStoreNames()
            }
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private func settingsAction(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(color)
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .background(
                        color.opacity(0.10),
                        in: RoundedRectangle(
                            cornerRadius: 13
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(title)
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )
                        .foregroundStyle(
                            PantryTheme.ink
                        )

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(
                            .leading
                        )
                }

                Spacer()

                Image(
                    systemName: "chevron.right"
                )
                .font(.caption.bold())
                .foregroundStyle(
                    color.opacity(0.65)
                )
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var dangerCard: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Zona pericolosa")
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)

            Button(role: .destructive) {
                showDeleteEverythingConfirmation =
                    true
            } label: {
                Label(
                    "Cancella tutti i dati",
                    systemImage: "trash.fill"
                )
                .font(
                    .subheadline
                        .weight(.semibold)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Color.red.opacity(0.08),
                    in: RoundedRectangle(
                        cornerRadius: 15
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                products.isEmpty
                    && priceRecords.isEmpty
                    && receiptAliases.isEmpty
            )

            Text(
                "Questa operazione elimina definitivamente l’intero archivio locale."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22
            )
            .stroke(
                Color.red.opacity(0.12),
                lineWidth: 1
            )
        }
    }

    private var appInformationCard: some View {
        HStack(spacing: 13) {
            Image("PantryBuddyIcon")
                .resizable()
                .scaledToFit()
                .frame(
                    width: 54,
                    height: 54
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14
                    )
                )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("PantryBuddy")
                    .font(.headline)
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                Text(appVersionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private var appVersionText: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "1.0"

        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String ?? "1"

        return "Versione \(version) (\(build))"
    }

    private func inspectArchive() {
        let report =
            ArchiveRepairService.inspect(
                products: products,
                priceRecords: priceRecords,
                receiptAliases: receiptAliases
            )

        guard report.hasProblems else {
            notice = SettingsNotice(
                title: "Archivio in ordine",
                message:
                    "Non ho trovato prezzi scollegati, duplicati o associazioni non valide."
            )

            return
        }

        pendingRepairReport = report
    }

    private func repairArchive() {
        do {
            let report =
                ArchiveRepairService.repair(
                    products: products,
                    priceRecords: priceRecords,
                    receiptAliases: receiptAliases,
                    in: modelContext
                )

            try modelContext.save()

            if report.mergedProducts > 0 {
                ignoredDuplicatePairs = ""
            }

            notice = SettingsNotice(
                title: "Archivio riparato",
                message:
                    report.completionMessage
            )
        } catch {
            modelContext.rollback()

            notice = SettingsNotice(
                title:
                    "Riparazione non riuscita",
                message:
                    "L’archivio non è stato modificato. Riprova dopo aver riaperto l’app."
            )
        }
    }

    private func normalizeStoreNames() {
        var changedCount = 0

        for record in priceRecords {
            let canonical =
                StoreNameNormalizer.canonicalName(
                    record.storeName
                )

            if record.storeName != canonical {
                record.storeName = canonical
                changedCount += 1
            }
        }

        guard changedCount > 0 else {
            notice = SettingsNotice(
                title: "Già tutto ordinato",
                message:
                    "I nomi dei supermercati sono già uniformi."
            )

            return
        }

        do {
            try modelContext.save()

            notice = SettingsNotice(
                title:
                    "Supermercati uniformati",
                message:
                    changedCount == 1
                    ? "È stato corretto 1 prezzo."
                    : "Sono stati corretti \(changedCount) prezzi."
            )
        } catch {
            modelContext.rollback()

            notice = SettingsNotice(
                title:
                    "Operazione non riuscita",
                message:
                    "Non sono riuscito a uniformare i supermercati."
            )
        }
    }

    private func exportBackup() {
        let backup = PantryBuddyBackup(
            formatVersion: 4,
            exportedAt: Date(),
            ignoredDuplicatePairs:
                ignoredDuplicatePairs,
            products: products.map {
                BackupProduct(
                    barcode: $0.barcode,
                    name: $0.name,
                    brand: $0.brand,
                    packageQuantity:
                        $0.packageQuantity,
                    imageURL: $0.imageURL,
                    localImageData:
                        $0.localImageData,
                    inventoryQuantity:
                        $0.inventoryQuantity,
                    inventoryTrackingRawValue:
                        $0.inventoryTrackingMode.rawValue,
                    unitsPerPackage:
                        $0.normalizedUnitsPerPackage,
                    inventoryUnitName:
                        $0.normalizedInventoryUnitName,
                    storageLocation:
                        $0.storageLocation,
                    expirationDate:
                        $0.expirationDate,
                    addedAt: $0.addedAt
                )
            },
            priceRecords: priceRecords.map {
                BackupPriceRecord(
                    productBarcode:
                        $0.productBarcode,
                    storeName: $0.storeName,
                    receiptDescription:
                        $0.receiptDescription,
                    price: $0.price,
                    purchaseDate:
                        $0.purchaseDate
                )
            },
            receiptAliases:
                receiptAliases.map {
                    BackupReceiptAlias(
                        storeName:
                            $0.storeName,
                        receiptText:
                            $0.receiptText,
                        productBarcode:
                            $0.productBarcode,
                        createdAt:
                            $0.createdAt,
                        lastSeenAt:
                            $0.lastSeenAt
                    )
                }
        )

        do {
            let encoder = JSONEncoder()

            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]

            encoder.dateEncodingStrategy =
                .iso8601

            let data = try encoder.encode(
                backup
            )

            let fileName =
                "PantryBuddy-Backup-\(backupDateText()).json"

            let url =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        fileName
                    )

            try data.write(
                to: url,
                options: .atomic
            )

            exportedFile =
                ExportedFile(url: url)
        } catch {
            notice = SettingsNotice(
                title:
                    "Esportazione non riuscita",
                message:
                    "Non sono riuscito a creare il file di backup."
            )
        }
    }

    private func handleSelectedBackup(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard
                let url =
                    try result.get().first
            else {
                return
            }

            let hasSecurityAccess =
                url.startAccessingSecurityScopedResource()

            defer {
                if hasSecurityAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data =
                try Data(contentsOf: url)

            let decoder = JSONDecoder()

            decoder.dateDecodingStrategy =
                .iso8601

            let backup =
                try decoder.decode(
                    PantryBuddyBackup.self,
                    from: data
                )

            try validateBackup(backup)

            pendingImport =
                PendingBackupImport(
                    backup: backup,
                    fileName:
                        url.lastPathComponent
                )
        } catch let error as BackupImportError {
            notice = SettingsNotice(
                title: "Backup non valido",
                message:
                    error.errorDescription
                    ?? "Il file non è un backup PantryBuddy valido."
            )
        } catch {
            notice = SettingsNotice(
                title:
                    "Impossibile aprire il backup",
                message:
                    "Controlla di aver selezionato un file JSON esportato da PantryBuddy."
            )
        }
    }

    private func validateBackup(
        _ backup: PantryBuddyBackup
    ) throws {
        guard
            (1...4).contains(
                backup.formatVersion
            )
        else {
            throw BackupImportError
                .unsupportedVersion(
                    backup.formatVersion
                )
        }

        let barcodes =
            backup.products.map {
                $0.barcode.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }

        guard
            !barcodes.contains(
                where: {
                    $0.isEmpty
                }
            )
        else {
            throw BackupImportError
                .invalidContent(
                    "Uno dei prodotti non contiene un barcode valido."
                )
        }

        guard
            Set(barcodes).count
                == barcodes.count
        else {
            throw BackupImportError
                .invalidContent(
                    "Il backup contiene prodotti duplicati con lo stesso barcode."
                )
        }

        guard
            backup.products.allSatisfy({
                product in

                !product.name
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                    && product.inventoryQuantity >= 0
            })
        else {
            throw BackupImportError
                .invalidContent(
                    "Il backup contiene un prodotto con nome o quantità non validi."
                )
        }

        guard
            backup.products.allSatisfy({
                product in

                guard
                    let rawValue =
                        product.inventoryTrackingRawValue
                else {
                    return true
                }

                guard
                    let mode =
                        InventoryTrackingMode(
                            rawValue: rawValue
                        )
                else {
                    return false
                }

                if mode == .containedUnits {
                    return
                        (product.unitsPerPackage ?? 0)
                        >= 2
                }

                return true
            })
        else {
            throw BackupImportError
                .invalidContent(
                    "Il backup contiene una modalità di conteggio non valida."
                )
        }

        guard
            backup.priceRecords.allSatisfy({
                record in

                record.price.isFinite
                    && record.price >= 0
                    && !record.productBarcode
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
            })
        else {
            throw BackupImportError
                .invalidContent(
                    "Il backup contiene un prezzo non valido o privo di riferimento al prodotto."
                )
        }

        guard
            backup.receiptAliases.allSatisfy({
                alias in

                !alias.productBarcode
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                    && !alias.receiptText
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
            })
        else {
            throw BackupImportError
                .invalidContent(
                    "Il backup contiene un’associazione scontrino non valida."
                )
        }
    }

    private func importBackup(
        _ backup: PantryBuddyBackup,
        mode: BackupImportMode
    ) {
        let previousBarcodes =
            products.map(\.barcode)

        do {
            let result: BackupImportResult

            switch mode {
            case .merge:
                result =
                    try mergeBackup(backup)

            case .replace:
                result =
                    try replaceWithBackup(
                        backup
                    )
            }

            try modelContext.save()

            let refreshedProducts =
                try modelContext.fetch(
                    FetchDescriptor<Product>()
                )

            refreshExpirationNotifications(
                for: refreshedProducts,
                importedProducts:
                    backup.products,
                previousBarcodes:
                    previousBarcodes,
                mode: mode
            )

            if mode == .replace {
                ignoredDuplicatePairs =
                    backup.ignoredDuplicatePairs
                    ?? ""
            } else if
                ignoredDuplicatePairs.isEmpty,
                let importedIgnoredPairs =
                    backup.ignoredDuplicatePairs
            {
                ignoredDuplicatePairs =
                    importedIgnoredPairs
            }

            notice = SettingsNotice(
                title:
                    mode == .merge
                    ? "Backup unito"
                    : "Backup ripristinato",
                message: result.message
            )
        } catch {
            modelContext.rollback()

            notice = SettingsNotice(
                title:
                    "Importazione non riuscita",
                message:
                    "L’archivio precedente non è stato modificato."
            )
        }
    }

    private func mergeBackup(
        _ backup: PantryBuddyBackup
    ) throws -> BackupImportResult {
        var productsByBarcode:
            [String: Product] = [:]

        for product in products {
            productsByBarcode[
                product.barcode
            ] = product
        }

        var addedProducts = 0

        for importedProduct in backup.products {
            if let existingProduct =
                productsByBarcode[
                    importedProduct.barcode
                ]
            {
                mergeProduct(
                    existingProduct,
                    with: importedProduct
                )
            } else {
                let product =
                    makeProduct(
                        from: importedProduct
                    )

                modelContext.insert(product)

                productsByBarcode[
                    product.barcode
                ] = product

                addedProducts += 1
            }
        }

        var knownPriceKeys =
            Set(
                priceRecords.map {
                    priceImportKey(
                        productBarcode:
                            $0.productBarcode,
                        storeName:
                            $0.storeName,
                        receiptDescription:
                            $0.receiptDescription,
                        price: $0.price,
                        purchaseDate:
                            $0.purchaseDate
                    )
                }
            )

        var addedPrices = 0

        for importedRecord in backup.priceRecords {
            let key = priceImportKey(
                productBarcode:
                    importedRecord.productBarcode,
                storeName:
                    importedRecord.storeName,
                receiptDescription:
                    importedRecord
                        .receiptDescription,
                price:
                    importedRecord.price,
                purchaseDate:
                    importedRecord.purchaseDate
            )

            guard
                knownPriceKeys
                    .insert(key)
                    .inserted
            else {
                continue
            }

            modelContext.insert(
                makePriceRecord(
                    from: importedRecord
                )
            )

            addedPrices += 1
        }

        var aliasesByKey:
            [AliasImportKey: ReceiptAlias] = [:]

        for alias in receiptAliases {
            let key = aliasImportKey(
                storeName: alias.storeName,
                receiptText: alias.receiptText,
                productBarcode:
                    alias.productBarcode
            )

            if let knownAlias =
                aliasesByKey[key]
            {
                knownAlias.createdAt = min(
                    knownAlias.createdAt,
                    alias.createdAt
                )

                knownAlias.lastSeenAt = max(
                    knownAlias.lastSeenAt,
                    alias.lastSeenAt
                )
            } else {
                aliasesByKey[key] = alias
            }
        }

        var addedAliases = 0

        for importedAlias in backup.receiptAliases {
            let key = aliasImportKey(
                storeName:
                    importedAlias.storeName,
                receiptText:
                    importedAlias.receiptText,
                productBarcode:
                    importedAlias.productBarcode
            )

            if let existingAlias =
                aliasesByKey[key]
            {
                existingAlias.createdAt = min(
                    existingAlias.createdAt,
                    importedAlias.createdAt
                )

                existingAlias.lastSeenAt = max(
                    existingAlias.lastSeenAt,
                    importedAlias.lastSeenAt
                )
            } else {
                let alias =
                    makeReceiptAlias(
                        from: importedAlias
                    )

                modelContext.insert(alias)
                aliasesByKey[key] = alias
                addedAliases += 1
            }
        }

        return BackupImportResult(
            productCount: addedProducts,
            priceCount: addedPrices,
            aliasCount: addedAliases,
            isReplacement: false
        )
    }

    private func replaceWithBackup(
        _ backup: PantryBuddyBackup
    ) throws -> BackupImportResult {
        for alias in receiptAliases {
            modelContext.delete(alias)
        }

        for record in priceRecords {
            modelContext.delete(record)
        }

        let importedBarcodes =
            Set(
                backup.products.map(
                    \.barcode
                )
            )

        var productsByBarcode:
            [String: Product] = [:]

        for product in products {
            productsByBarcode[
                product.barcode
            ] = product
        }

        for product in products
        where !importedBarcodes.contains(
            product.barcode
        ) {
            modelContext.delete(product)
        }

        for importedProduct in backup.products {
            if let existingProduct =
                productsByBarcode[
                    importedProduct.barcode
                ]
            {
                replaceProduct(
                    existingProduct,
                    with: importedProduct
                )
            } else {
                let product =
                    makeProduct(
                        from: importedProduct
                    )

                modelContext.insert(product)

                productsByBarcode[
                    product.barcode
                ] = product
            }
        }

        for importedRecord in backup.priceRecords {
            modelContext.insert(
                makePriceRecord(
                    from: importedRecord
                )
            )
        }

        for importedAlias in backup.receiptAliases {
            modelContext.insert(
                makeReceiptAlias(
                    from: importedAlias
                )
            )
        }

        return BackupImportResult(
            productCount:
                backup.products.count,
            priceCount:
                backup.priceRecords.count,
            aliasCount:
                backup.receiptAliases.count,
            isReplacement: true
        )
    }

    private func mergeProduct(
        _ product: Product,
        with importedProduct: BackupProduct
    ) {
        if product.name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        {
            product.name =
                importedProduct.name
        }

        if product.brand
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        {
            product.brand =
                importedProduct.brand
        }

        if product.packageQuantity
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        {
            product.packageQuantity =
                importedProduct.packageQuantity
        }

        if product.imageURL == nil {
            product.imageURL =
                importedProduct.imageURL
        }

        if product.localImageData == nil {
            product.localImageData =
                importedProduct.localImageData
        }

        if product.storageLocation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        {
            product.storageLocation =
                importedProduct.storageLocation
        }

        mergeInventoryTracking(
            product,
            with: importedProduct
        )

        product.expirationDate =
            mergedExpirationDate(
                product.expirationDate,
                importedProduct.expirationDate
            )

        product.addedAt = min(
            product.addedAt,
            importedProduct.addedAt
        )
    }

    private func replaceProduct(
        _ product: Product,
        with importedProduct: BackupProduct
    ) {
        product.name =
            importedProduct.name

        product.brand =
            importedProduct.brand

        product.packageQuantity =
            importedProduct.packageQuantity

        product.imageURL =
            importedProduct.imageURL

        product.localImageData =
            importedProduct.localImageData

        product.inventoryQuantity =
            importedProduct.inventoryQuantity

        product.storageLocation =
            importedProduct.storageLocation

        applyImportedTracking(
            importedProduct,
            to: product
        )

        product.expirationDate =
            importedProduct.expirationDate.map {
                Calendar.current.startOfDay(
                    for: $0
                )
            }

        product.addedAt =
            importedProduct.addedAt
    }

    private func makeProduct(
        from importedProduct: BackupProduct
    ) -> Product {
        let product = Product(
            barcode:
                importedProduct.barcode,
            name:
                importedProduct.name,
            brand:
                importedProduct.brand,
            packageQuantity:
                importedProduct.packageQuantity,
            imageURL:
                importedProduct.imageURL,
            localImageData:
                importedProduct.localImageData,
            inventoryQuantity:
                importedProduct.inventoryQuantity,
            storageLocation:
                importedProduct.storageLocation,
            trackingMode:
                importedTrackingMode(
                    importedProduct
                ),
            unitsPerPackage:
                importedUnitsPerPackage(
                    importedProduct
                ),
            inventoryUnitName:
                importedUnitName(
                    importedProduct
                ),
            expirationDate:
                importedProduct.expirationDate
        )

        product.addedAt =
            importedProduct.addedAt

        return product
    }

    private func mergeInventoryTracking(
        _ product: Product,
        with importedProduct: BackupProduct
    ) {
        let importedMode =
            importedTrackingMode(
                importedProduct
            )

        switch (
            product.inventoryTrackingMode,
            importedMode
        ) {
        case (.packages, .packages):
            product.inventoryQuantity = max(
                product.inventoryQuantity,
                importedProduct.inventoryQuantity
            )

        case (
            .containedUnits,
            .containedUnits
        ):
            product.inventoryQuantity = max(
                product.inventoryQuantity,
                importedProduct.inventoryQuantity
            )

            if
                product.normalizedInventoryUnitName
                    == "unità",
                importedUnitName(
                    importedProduct
                ) != "unità"
            {
                product.inventoryUnitName =
                    importedUnitName(
                        importedProduct
                    )
            }

        case (.packages, .containedUnits):
            let importedUnits =
                importedUnitsPerPackage(
                    importedProduct
                )

            let convertedCurrentQuantity =
                product.inventoryQuantity
                * importedUnits

            product.inventoryQuantity = max(
                convertedCurrentQuantity,
                importedProduct.inventoryQuantity
            )

            applyImportedTracking(
                importedProduct,
                to: product
            )

        case (.containedUnits, .packages):
            let convertedImportedQuantity =
                importedProduct.inventoryQuantity
                * product.normalizedUnitsPerPackage

            product.inventoryQuantity = max(
                product.inventoryQuantity,
                convertedImportedQuantity
            )
        }
    }

    private func applyImportedTracking(
        _ importedProduct: BackupProduct,
        to product: Product
    ) {
        let mode =
            importedTrackingMode(
                importedProduct
            )

        product.inventoryTrackingRawValue =
            mode.rawValue

        switch mode {
        case .packages:
            product.unitsPerPackage = 1
            product.inventoryUnitName =
                "unità"

        case .containedUnits:
            product.unitsPerPackage =
                importedUnitsPerPackage(
                    importedProduct
                )

            product.inventoryUnitName =
                importedUnitName(
                    importedProduct
                )
        }
    }

    private func importedTrackingMode(
        _ importedProduct: BackupProduct
    ) -> InventoryTrackingMode {
        guard
            let rawValue =
                importedProduct
                    .inventoryTrackingRawValue,
            let mode =
                InventoryTrackingMode(
                    rawValue: rawValue
                )
        else {
            return .packages
        }

        return mode
    }

    private func importedUnitsPerPackage(
        _ importedProduct: BackupProduct
    ) -> Int {
        max(
            2,
            importedProduct.unitsPerPackage
                ?? 2
        )
    }

    private func importedUnitName(
        _ importedProduct: BackupProduct
    ) -> String {
        Product.cleanedUnitName(
            importedProduct.inventoryUnitName
                ?? "unità"
        )
    }

    private func mergedExpirationDate(
        _ currentDate: Date?,
        _ importedDate: Date?
    ) -> Date? {
        switch (
            currentDate,
            importedDate
        ) {
        case let (current?, imported?):
            return Calendar.current.startOfDay(
                for: min(
                    current,
                    imported
                )
            )

        case let (current?, nil):
            return Calendar.current.startOfDay(
                for: current
            )

        case let (nil, imported?):
            return Calendar.current.startOfDay(
                for: imported
            )

        case (nil, nil):
            return nil
        }
    }

    private func refreshExpirationNotifications(
        for currentProducts: [Product],
        importedProducts: [BackupProduct],
        previousBarcodes: [String],
        mode: BackupImportMode
    ) {
        let importedBarcodes = Set(
            importedProducts.map(\.barcode)
        )

        let productsToRefresh =
            currentProducts.filter {
                importedBarcodes.contains(
                    $0.barcode
                )
            }

        Task { @MainActor in
            if mode == .replace {
                for barcode in previousBarcodes {
                    ProductExpirationService
                        .cancelNotifications(
                            forBarcode: barcode
                        )
                }
            }

            for product in productsToRefresh {
                _ = await ProductExpirationService
                    .scheduleNotifications(
                        for: product
                    )
            }
        }
    }

    private func makePriceRecord(
        from importedRecord:
            BackupPriceRecord
    ) -> PriceRecord {
        PriceRecord(
            productBarcode:
                importedRecord.productBarcode,
            storeName:
                StoreNameNormalizer.canonicalName(
                    importedRecord.storeName
                ),
            receiptDescription:
                importedRecord.receiptDescription,
            price:
                importedRecord.price,
            purchaseDate:
                importedRecord.purchaseDate
        )
    }

    private func makeReceiptAlias(
        from importedAlias:
            BackupReceiptAlias
    ) -> ReceiptAlias {
        let alias = ReceiptAlias(
            storeName:
                StoreNameNormalizer.canonicalName(
                    importedAlias.storeName
                ),
            receiptText:
                importedAlias.receiptText,
            productBarcode:
                importedAlias.productBarcode
        )

        alias.createdAt =
            importedAlias.createdAt

        alias.lastSeenAt =
            importedAlias.lastSeenAt

        return alias
    }

    private func priceImportKey(
        productBarcode: String,
        storeName: String,
        receiptDescription: String,
        price: Double,
        purchaseDate: Date
    ) -> PriceImportKey {
        PriceImportKey(
            productBarcode:
                productBarcode,
            storeKey:
                StoreNameNormalizer.groupingKey(
                    storeName
                ),
            receiptKey:
                normalizedImportText(
                    receiptDescription
                ),
            priceInCents:
                Int64(
                    (price * 100).rounded()
                ),
            purchaseSecond:
                Int64(
                    purchaseDate
                        .timeIntervalSince1970
                )
        )
    }

    private func aliasImportKey(
        storeName: String,
        receiptText: String,
        productBarcode: String
    ) -> AliasImportKey {
        AliasImportKey(
            storeKey:
                StoreNameNormalizer.groupingKey(
                    storeName
                ),
            receiptKey:
                normalizedImportText(
                    receiptText
                ),
            productBarcode:
                productBarcode
        )
    }

    private func normalizedImportText(
        _ text: String
    ) -> String {
        text.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive
            ],
            locale: Locale(
                identifier: "en_US_POSIX"
            )
        )
        .components(
            separatedBy:
                .whitespacesAndNewlines
        )
        .filter {
            !$0.isEmpty
        }
        .joined(separator: " ")
    }

    private func exportPriceHistoryCSV() {
        guard !priceRecords.isEmpty else {
            notice = SettingsNotice(
                title: "Nessun prezzo",
                message:
                    "Non ci sono ancora prezzi da esportare."
            )

            return
        }

        var productsByBarcode:
            [String: Product] = [:]

        for product in products {
            productsByBarcode[
                product.barcode
            ] = product
        }

        let dateFormatter =
            DateFormatter()

        dateFormatter.locale =
            Locale(
                identifier: "en_US_POSIX"
            )

        dateFormatter.dateFormat =
            "yyyy-MM-dd"

        var rows = [
            [
                "Prodotto",
                "Marca",
                "Confezione",
                "Barcode",
                "Supermercato",
                "Prezzo NOK",
                "Data acquisto",
                "Descrizione"
            ]
        ]

        for record in priceRecords.sorted(
            by: {
                $0.purchaseDate
                    < $1.purchaseDate
            }
        ) {
            let product =
                productsByBarcode[
                    record.productBarcode
                ]

            let price =
                String(
                    format: "%.2f",
                    locale: Locale(
                        identifier:
                            "en_US_POSIX"
                    ),
                    record.price
                )
                .replacingOccurrences(
                    of: ".",
                    with: ","
                )

            rows.append([
                product?.name
                    ?? "Prodotto eliminato",
                product?.brand ?? "",
                product?.packageQuantity ?? "",
                record.productBarcode,
                StoreNameNormalizer.canonicalName(
                    record.storeName
                ),
                price,
                dateFormatter.string(
                    from:
                        record.purchaseDate
                ),
                record.receiptDescription
            ])
        }

        let csv =
            "\u{FEFF}"
            + rows.map { row in
                row.map(csvField)
                    .joined(separator: ";")
            }
            .joined(separator: "\n")

        do {
            let fileName =
                "PantryBuddy-Prezzi-\(backupDateText()).csv"

            let url =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        fileName
                    )

            try Data(csv.utf8).write(
                to: url,
                options: .atomic
            )

            exportedFile =
                ExportedFile(url: url)
        } catch {
            notice = SettingsNotice(
                title:
                    "Esportazione non riuscita",
                message:
                    "Non sono riuscito a creare il file CSV."
            )
        }
    }

    private func csvField(
        _ value: String
    ) -> String {
        let escaped =
            value.replacingOccurrences(
                of: "\"",
                with: "\"\""
            )

        return "\"\(escaped)\""
    }

    private func backupDateText() -> String {
        let formatter = DateFormatter()

        formatter.locale =
            Locale(
                identifier: "en_US_POSIX"
            )

        formatter.dateFormat =
            "yyyy-MM-dd-HHmm"

        return formatter.string(
            from: Date()
        )
    }

    private func deleteEverything() {
        let productBarcodes =
            products.map(\.barcode)

        for alias in receiptAliases {
            modelContext.delete(alias)
        }

        for record in priceRecords {
            modelContext.delete(record)
        }

        for product in products {
            modelContext.delete(product)
        }

        do {
            try modelContext.save()

            for barcode in productBarcodes {
                ProductExpirationService
                    .cancelNotifications(
                        forBarcode: barcode
                    )
            }

            ignoredDuplicatePairs = ""

            notice = SettingsNotice(
                title: "Archivio cancellato",
                message:
                    "Tutti i dati locali di PantryBuddy sono stati eliminati."
            )
        } catch {
            modelContext.rollback()

            notice = SettingsNotice(
                title:
                    "Cancellazione non riuscita",
                message:
                    "Non sono riuscito a cancellare l’archivio."
            )
        }
    }
}

private struct ProductDataManagementView: View {
    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Product.name)
    private var products: [Product]

    @Query
    private var priceRecords: [PriceRecord]

    @Query
    private var receiptAliases: [ReceiptAlias]

    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var notice: SettingsNotice?

    private var visibleProducts: [Product] {
        let query =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return products
        }

        return products.filter {
            $0.name.localizedStandardContains(
                query
            )
                || $0.brand.localizedStandardContains(
                    query
                )
                || $0.barcode.localizedStandardContains(
                    query
                )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    searchField

                    if products.isEmpty {
                        emptyState
                    } else if visibleProducts.isEmpty {
                        noResultsState
                    } else {
                        productList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle(
                "Gestisci prodotti"
            )
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
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                selectedProduct.map {
                    "Gestire \($0.name)?"
                } ?? "Gestire prodotto?",
                isPresented: Binding(
                    get: {
                        selectedProduct != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            selectedProduct = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let selectedProduct,
                   selectedProduct.inventoryQuantity > 0
                {
                    Button(
                        "Rimuovi solo dalla dispensa"
                    ) {
                        removeFromPantry(
                            selectedProduct
                        )
                    }
                }

                Button(
                    "Elimina definitivamente",
                    role: .destructive
                ) {
                    if let selectedProduct {
                        deleteCompletely(
                            selectedProduct
                        )
                    }
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {
                    selectedProduct = nil
                }
            } message: {
                Text(selectedProductMessage)
            }
            .alert(item: $notice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(
                        Text("OK")
                    )
                )
            }
        }
        .tint(PantryTheme.forest)
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(
                systemName: "magnifyingglass"
            )
            .foregroundStyle(
                PantryTheme.forest
            )

            TextField(
                "Cerca prodotto o barcode",
                text: $searchText
            )
            .textInputAutocapitalization(
                .never
            )
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 17
            )
        )
    }

    private var productList: some View {
        ScrollView(
            showsIndicators: false
        ) {
            LazyVStack(spacing: 11) {
                ForEach(visibleProducts) { product in
                    Button {
                        selectedProduct =
                            product
                    } label: {
                        productRow(product)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 28)
        }
    }

    private func productRow(
        _ product: Product
    ) -> some View {
        let records =
            priceRecords.filter {
                $0.productBarcode
                    == product.barcode
            }

        return HStack(spacing: 13) {
            PBProductImage(
                imageURL: product.imageURL,
                localImageData:
                    product.localImageData,
                size: 58
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(product.name)
                    .font(
                        .subheadline
                            .weight(.semibold)
                    )
                    .foregroundStyle(
                        PantryTheme.ink
                    )
                    .lineLimit(2)

                HStack(spacing: 7) {
                    Label(
                        product.inventoryQuantity > 0
                        ? product.inventoryQuantityText
                        : "Solo catalogo",
                        systemImage:
                            product.inventoryQuantity > 0
                            ? "cabinet.fill"
                            : "tag.fill"
                    )

                    Text("·")

                    Text(
                        records.count == 1
                        ? "1 prezzo"
                        : "\(records.count) prezzi"
                    )
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(
                systemName: "ellipsis.circle"
            )
            .font(.system(size: 20))
            .foregroundStyle(
                PantryTheme.forest
            )
        }
        .padding(13)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                PantryTheme.forest.opacity(
                    0.08
                ),
                lineWidth: 1
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nessun prodotto",
            systemImage: "shippingbox",
            description: Text(
                "Il catalogo è già vuoto."
            )
        )
    }

    private var noResultsState: some View {
        ContentUnavailableView.search(
            text: searchText
        )
    }

    private var selectedProductMessage: String {
        guard let selectedProduct else {
            return ""
        }

        let priceCount =
            priceRecords.filter {
                $0.productBarcode
                    == selectedProduct.barcode
            }.count

        let aliasCount =
            receiptAliases.filter {
                $0.productBarcode
                    == selectedProduct.barcode
            }.count

        let deletionText =
            """
            Eliminandolo definitivamente verranno rimossi anche \
            \(priceCount) prezzi e \(aliasCount) associazioni scontrino.
            """

        if selectedProduct.inventoryQuantity > 0 {
            return """
                Puoi toglierlo solo dalla dispensa mantenendo catalogo e storico. \
                \(deletionText)
                """
        }

        return deletionText
    }

    private func removeFromPantry(
        _ product: Product
    ) {
        product.inventoryQuantity = 0

        do {
            try modelContext.save()

            ProductExpirationService
                .cancelNotifications(
                    for: product
                )

            selectedProduct = nil

            notice = SettingsNotice(
                title:
                    "Rimosso dalla dispensa",
                message:
                    "Il prodotto e il suo storico restano nel catalogo."
            )
        } catch {
            modelContext.rollback()

            selectedProduct = nil

            notice = SettingsNotice(
                title:
                    "Operazione non riuscita",
                message:
                    "Non sono riuscito a modificare la dispensa."
            )
        }
    }

    private func deleteCompletely(
        _ product: Product
    ) {
        let productBarcode =
            product.barcode

        for record in priceRecords
        where record.productBarcode
            == product.barcode
        {
            modelContext.delete(record)
        }

        for alias in receiptAliases
        where alias.productBarcode
            == product.barcode
        {
            modelContext.delete(alias)
        }

        modelContext.delete(product)

        do {
            try modelContext.save()

            ProductExpirationService
                .cancelNotifications(
                    forBarcode: productBarcode
                )

            selectedProduct = nil

            notice = SettingsNotice(
                title: "Prodotto eliminato",
                message:
                    "Prodotto, prezzi e associazioni sono stati eliminati."
            )
        } catch {
            modelContext.rollback()

            selectedProduct = nil

            notice = SettingsNotice(
                title:
                    "Eliminazione non riuscita",
                message:
                    "Non sono riuscito a eliminare il prodotto."
            )
        }
    }
}

nonisolated private struct PantryBuddyBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let ignoredDuplicatePairs: String?
    let products: [BackupProduct]
    let priceRecords: [BackupPriceRecord]
    let receiptAliases: [BackupReceiptAlias]
}

nonisolated private struct BackupProduct: Codable {
    let barcode: String
    let name: String
    let brand: String
    let packageQuantity: String
    let imageURL: String?
    let localImageData: Data?
    let inventoryQuantity: Int
    let inventoryTrackingRawValue: String?
    let unitsPerPackage: Int?
    let inventoryUnitName: String?
    let storageLocation: String
    let expirationDate: Date?
    let addedAt: Date
}

nonisolated private struct BackupPriceRecord: Codable {
    let productBarcode: String
    let storeName: String
    let receiptDescription: String
    let price: Double
    let purchaseDate: Date
}

nonisolated private struct BackupReceiptAlias: Codable {
    let storeName: String
    let receiptText: String
    let productBarcode: String
    let createdAt: Date
    let lastSeenAt: Date
}

nonisolated private struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

nonisolated private struct PendingBackupImport: Identifiable {
    let id = UUID()
    let backup: PantryBuddyBackup
    let fileName: String
}

nonisolated private enum BackupImportMode: Equatable {
    case merge
    case replace
}

nonisolated private enum BackupImportError:
    LocalizedError
{
    case unsupportedVersion(Int)
    case invalidContent(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return """
            La versione del backup (\(version)) non è supportata da questa versione di PantryBuddy.
            """

        case .invalidContent(let message):
            return message
        }
    }
}

nonisolated private struct BackupImportResult {
    let productCount: Int
    let priceCount: Int
    let aliasCount: Int
    let isReplacement: Bool

    var message: String {
        if isReplacement {
            return """
            Ripristinati \(productCount) prodotti, \(priceCount) prezzi e \
            \(aliasCount) associazioni scontrino.
            """
        }

        if productCount == 0,
           priceCount == 0,
           aliasCount == 0
        {
            return """
            Il backup non conteneva dati nuovi da aggiungere. \
            L’archivio era già aggiornato.
            """
        }

        return """
        Aggiunti \(productCount) prodotti, \(priceCount) prezzi e \
        \(aliasCount) associazioni scontrino. \
        I dati già presenti sono stati mantenuti.
        """
    }
}

nonisolated private struct PriceImportKey:
    Hashable
{
    let productBarcode: String
    let storeKey: String
    let receiptKey: String
    let priceInCents: Int64
    let purchaseSecond: Int64
}

nonisolated private struct AliasImportKey:
    Hashable
{
    let storeKey: String
    let receiptKey: String
    let productBarcode: String
}

nonisolated private struct SettingsNotice:
    Identifiable
{
    let id = UUID()
    let title: String
    let message: String
}

private struct BackupImportPreviewView: View {
    @Environment(\.dismiss)
    private var dismiss

    let pendingImport: PendingBackupImport
    let currentProductCount: Int
    let currentPriceCount: Int
    let currentAliasCount: Int
    let onMerge: () -> Void
    let onReplace: () -> Void

    @State
    private var showReplaceConfirmation = false

    private var backup: PantryBuddyBackup {
        pendingImport.backup
    }

    private var backupPhotoCount: Int {
        backup.products.filter {
            $0.localImageData != nil
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(spacing: 18) {
                        backupHeader
                        backupContentsCard
                        currentArchiveCard
                        importChoicesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Importa backup")
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
                    .foregroundStyle(
                        PantryTheme.forest
                    )
                }
            }
            .confirmationDialog(
                "Sostituire tutto l’archivio?",
                isPresented:
                    $showReplaceConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "Sostituisci tutto",
                    role: .destructive
                ) {
                    onReplace()
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {}
            } message: {
                Text(
                    """
                    Prima verranno eliminati tutti i dati attuali. \
                    Verranno poi ripristinati i dati contenuti nel backup.
                    """
                )
            }
        }
        .tint(PantryTheme.forest)
    }

    private var backupHeader: some View {
        VStack(spacing: 12) {
            Image(
                systemName:
                    "checkmark.shield.fill"
            )
            .font(.system(size: 36))
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

            Text("Backup verificato")
                .font(.title3.bold())
                .foregroundStyle(
                    PantryTheme.ink
                )

            Text(pendingImport.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(
                    .center
                )

            Text(
                "Creato il \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened))"
            )
            .font(.caption)
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

    private var backupContentsCard: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Text("Contenuto del backup")
                .font(.headline)
                .foregroundStyle(
                    PantryTheme.ink
                )

            importCountRow(
                title: "Prodotti",
                value:
                    backup.products.count,
                icon: "shippingbox.fill",
                color: PantryTheme.forest
            )

            Divider()

            importCountRow(
                title: "Foto locali",
                value: backupPhotoCount,
                icon: "photo.fill",
                color: PantryTheme.leaf
            )

            Divider()

            importCountRow(
                title: "Prezzi",
                value:
                    backup.priceRecords.count,
                icon: "tag.fill",
                color: PantryTheme.gold
            )

            Divider()

            importCountRow(
                title:
                    "Associazioni scontrino",
                value:
                    backup.receiptAliases.count,
                icon: "link",
                color: PantryTheme.leaf
            )
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private var currentArchiveCard: some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            Text("Archivio attuale")
                .font(.headline)
                .foregroundStyle(
                    PantryTheme.ink
                )

            Text(
                "\(currentProductCount) prodotti · \(currentPriceCount) prezzi · \(currentAliasCount) associazioni"
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

    private var importChoicesCard: some View {
        VStack(spacing: 14) {
            Button {
                onMerge()
            } label: {
                VStack(spacing: 3) {
                    Label(
                        "Unisci con i dati attuali",
                        systemImage:
                            "arrow.triangle.merge"
                    )
                    .font(.headline)

                    Text(
                        "Aggiunge solo ciò che manca"
                    )
                    .font(.caption)
                    .opacity(0.82)
                }
                .foregroundStyle(
                    PantryTheme.cream
                )
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    PantryTheme.primaryGradient,
                    in: RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showReplaceConfirmation = true
            } label: {
                VStack(spacing: 3) {
                    Label(
                        "Sostituisci tutto",
                        systemImage:
                            "arrow.clockwise"
                    )
                    .font(.headline)

                    Text(
                        "Elimina prima l’archivio attuale"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    Color.red.opacity(0.08),
                    in: RoundedRectangle(
                        cornerRadius: 18
                    )
                )
            }
            .buttonStyle(.plain)

            Text(
                """
                Consiglio: usa Unisci. I prodotti con lo stesso barcode e i prezzi già presenti \
                non verranno duplicati.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private func importCountRow(
        title: String,
        value: Int,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 16,
                        weight: .bold
                    )
                )
                .foregroundStyle(color)
                .frame(
                    width: 38,
                    height: 38
                )
                .background(
                    color.opacity(0.10),
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
                .foregroundStyle(color)
        }
    }
}

private struct ActivityShareView:
    UIViewControllerRepresentable
{
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController:
            UIActivityViewController,
        context: Context
    ) {}
}
