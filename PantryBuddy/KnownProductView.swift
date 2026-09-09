import SwiftData
import SwiftUI
import UIKit

struct KnownProductView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.openURL)
    private var openURL

    let product: Product

    @State private var quantity: Int
    @State private var storageLocation: String

    @State
    private var trackingMode: InventoryTrackingMode

    @State private var unitsPerPackage: Int
    @State private var inventoryUnitName: String

    @State private var convertedPackageCount: Int?
    @State private var errorMessage: String?
    @State private var showProductCamera = false
    @State private var hasExpirationDate: Bool
    @State private var expirationDate: Date
    @State private var isSaving = false

    @State
    private var showNotificationSettingsAlert = false

    init(product: Product) {
        self.product = product

        _quantity = State(
            initialValue: product.inventoryQuantity
        )

        _storageLocation = State(
            initialValue: product.storageLocation
        )

        _trackingMode = State(
            initialValue:
                product.inventoryTrackingMode
        )

        _unitsPerPackage = State(
            initialValue:
                product.inventoryTrackingMode
                    == .containedUnits
                    ? max(
                        2,
                        product.normalizedUnitsPerPackage
                    )
                    : 6
        )

        _inventoryUnitName = State(
            initialValue:
                product.inventoryTrackingMode
                    == .containedUnits
                    ? product.normalizedInventoryUnitName
                    : ""
        )

        _hasExpirationDate = State(
            initialValue:
                product.expirationDate != nil
        )

        let suggestedExpirationDate =
            Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: Date()
            ) ?? Date()

        _expirationDate = State(
            initialValue:
                product.expirationDate
                    ?? suggestedExpirationDate
        )
    }

    private var editableQuantity: Binding<Int> {
        Binding(
            get: {
                quantity
            },
            set: { newValue in
                quantity = newValue
                convertedPackageCount = nil
            }
        )
    }

    private var packageAdditionAmount: Int {
        Product.inventoryAmount(
            forPackageCount: 1,
            trackingMode: trackingMode,
            unitsPerPackage: unitsPerPackage
        )
    }

    private var addPackageTitle: String {
        switch trackingMode {
        case .packages:
            return "Aggiungi una confezione"

        case .containedUnits:
            let unitName = Product.italianPlural(
                of: inventoryUnitName
            )

            return "Aggiungi \(packageAdditionAmount) \(unitName)"
        }
    }

    private var quantityControlTitle: String {
        switch trackingMode {
        case .packages:
            return "Confezioni nella dispensa"

        case .containedUnits:
            return "Unità rimaste nella dispensa"
        }
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
                        PBProductImage(
                            imageURL: product.imageURL,
                            localImageData:
                                product.localImageData
                        )
                        .padding(.top, 12)

                        photoActions

                        VStack(spacing: 5) {
                            Text(product.name)
                                .font(.title2.bold())
                                .foregroundStyle(
                                    PantryTheme.ink
                                )
                                .multilineTextAlignment(
                                    .center
                                )

                            let details = [
                                product.brand,
                                product.packageQuantity
                            ]
                            .filter {
                                !$0.isEmpty
                            }
                            .joined(separator: " · ")

                            if !details.isEmpty {
                                Text(details)
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        .secondary
                                    )
                            }
                        }

                        PBInventoryTrackingEditor(
                            trackingMode:
                                $trackingMode,
                            unitsPerPackage:
                                $unitsPerPackage,
                            inventoryUnitName:
                                $inventoryUnitName
                        )

                        addPackageButton

                        PBQuantityControl(
                            title: quantityControlTitle,
                            quantity: editableQuantity,
                            minimum: 0,
                            maximum: 9999
                        )

                        PBStoragePicker(
                            selection: $storageLocation
                        )

                        PBExpirationPicker(
                            hasExpirationDate:
                                $hasExpirationDate,
                            expirationDate:
                                $expirationDate
                        )

                        if quantity == 0 {
                            Text(
                                "Il prodotto sparirà dalla dispensa, ma resterà nel Catalogo prezzi."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(
                                .center
                            )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(
                                    .center
                                )
                        }

                        PBPrimaryButton(
                            title: "Salva modifiche",
                            systemImage:
                                "checkmark.circle.fill",
                            disabled: isSaving
                        ) {
                            save()
                        }
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
            .navigationTitle("Prodotto")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .tint(PantryTheme.forest)
        .fullScreenCover(
            isPresented: $showProductCamera
        ) {
            ProductPhotoCameraView(
                onImageCaptured: { image in
                    showProductCamera = false

                    Task { @MainActor in
                        /*
                         Aspetta che la fotocamera sia stata
                         completamente chiusa.
                         */
                        try? await Task.sleep(
                            for: .milliseconds(250)
                        )

                        savePhoto(image)
                    }
                },
                onCancel: {
                    showProductCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: trackingMode) {
            oldMode,
            newMode in

            convertQuantity(
                from: oldMode,
                to: newMode
            )
        }
        .onChange(of: unitsPerPackage) {
            _,
            newValue in

            guard
                trackingMode == .containedUnits,
                let convertedPackageCount
            else {
                return
            }

            quantity = min(
                9999,
                convertedPackageCount
                    * max(
                        2,
                        newValue
                    )
            )
        }
        .alert(
            "Notifiche disattivate",
            isPresented:
                $showNotificationSettingsAlert
        ) {
            Button("Apri Impostazioni") {
                if let settingsURL = URL(
                    string:
                        UIApplication
                            .openSettingsURLString
                ) {
                    openURL(settingsURL)
                }

                dismiss()
            }

            Button(
                "Non ora",
                role: .cancel
            ) {
                dismiss()
            }
        } message: {
            Text(
                "La scadenza è stata salvata, ma PantryBuddy non può inviarti gli avvisi. Puoi attivare le notifiche nelle Impostazioni di iPhone."
            )
        }
    }

    // MARK: - Foto prodotto

    private var photoActions: some View {
        HStack(spacing: 10) {
            Button {
                showProductCamera = true
            } label: {
                Label(
                    product.localImageData == nil
                        ? "Aggiungi foto"
                        : "Sostituisci foto",
                    systemImage: "camera.fill"
                )
                .font(
                    .subheadline.weight(.semibold)
                )
                .foregroundStyle(
                    PantryTheme.forest
                )
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    PantryTheme.forest.opacity(0.09),
                    in: RoundedRectangle(
                        cornerRadius: 16
                    )
                )
            }
            .buttonStyle(.plain)

            if product.localImageData != nil {
                Button {
                    removeLocalPhoto()
                } label: {
                    Image(systemName: "trash")
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.red)
                        .frame(
                            width: 46,
                            height: 46
                        )
                        .background(
                            Color.red.opacity(0.08),
                            in: RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Rimuovi foto"
                )
            }
        }
        .frame(maxWidth: 380)
    }

    // MARK: - Aggiunta confezione

    private var addPackageButton: some View {
        Button {
            convertedPackageCount = nil

            quantity = min(
                9999,
                quantity + packageAdditionAmount
            )
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName: "shippingbox.fill"
                )
                .font(.system(size: 18))

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(addPackageTitle)
                        .font(
                            .subheadline.weight(.bold)
                        )

                    Text(
                        "Usalo quando compri un’altra confezione."
                    )
                    .font(.caption2)
                    .opacity(0.75)
                }

                Spacer()

                Image(
                    systemName: "plus.circle.fill"
                )
                .font(.title3)
            }
            .foregroundStyle(
                PantryTheme.forest
            )
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                PantryTheme.forest.opacity(0.09),
                in: RoundedRectangle(
                    cornerRadius: 20
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversione quantità

    private func convertQuantity(
        from oldMode: InventoryTrackingMode,
        to newMode: InventoryTrackingMode
    ) {
        guard oldMode != newMode else {
            return
        }

        switch (oldMode, newMode) {
        case (.packages, .containedUnits):
            let packageCount = quantity

            let cleanUnitsPerPackage = max(
                2,
                unitsPerPackage
            )

            unitsPerPackage =
                cleanUnitsPerPackage

            convertedPackageCount =
                packageCount

            quantity = min(
                9999,
                packageCount
                    * cleanUnitsPerPackage
            )

        case (.containedUnits, .packages):
            let divisor = max(
                2,
                unitsPerPackage
            )

            if quantity == 0 {
                quantity = 0
            } else {
                quantity = Int(
                    ceil(
                        Double(quantity)
                            / Double(divisor)
                    )
                )
            }

            convertedPackageCount = nil

        default:
            break
        }
    }

    // MARK: - Salvataggio prodotto

    private func save() {
        guard !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        product.inventoryQuantity =
            quantity

        product.storageLocation =
            storageLocation

        product.inventoryTrackingRawValue =
            trackingMode.rawValue

        product.unitsPerPackage =
            trackingMode == .containedUnits
                ? max(
                    2,
                    unitsPerPackage
                )
                : 1

        product.inventoryUnitName =
            Product.cleanedUnitName(
                inventoryUnitName
            )

        product.expirationDate =
            hasExpirationDate
                ? Calendar.current.startOfDay(
                    for: expirationDate
                )
                : nil

        do {
            try modelContext.save()

            Task { @MainActor in
                await updateExpirationNotification()
            }
        } catch {
            isSaving = false

            errorMessage =
                "Non sono riuscito a salvare le modifiche."

            print(
                "Errore aggiornamento prodotto:",
                error
            )
        }
    }

    private func updateExpirationNotification()
        async {
        let result =
            await ProductExpirationService
                .scheduleNotifications(
                    for: product
                )

        isSaving = false

        switch result {
        case .permissionDenied:
            showNotificationSettingsAlert = true

        case .failed:
            errorMessage =
                "Il prodotto è stato salvato, ma non sono riuscito a programmare la notifica."

        case .scheduled,
             .noExpirationDate,
             .noFutureNotifications:
            dismiss()
        }
    }

    // MARK: - Salvataggio foto

    private func savePhoto(
        _ image: UIImage
    ) {
        guard let data =
            ProductPhotoStorage.compressedData(
                from: image
            )
        else {
            errorMessage =
                "Non sono riuscito a preparare la foto. Riprova."

            return
        }

        product.localImageData = data

        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            modelContext.rollback()

            errorMessage =
                "Non sono riuscito a salvare la foto."

            print(
                "Errore salvataggio foto prodotto:",
                error
            )
        }
    }

    private func removeLocalPhoto() {
        product.localImageData = nil

        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            modelContext.rollback()

            errorMessage =
                "Non sono riuscito a rimuovere la foto."
        }
    }
}
