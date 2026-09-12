import SwiftData
import SwiftUI
import UIKit

struct ManualProductEntryView: View {
    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.openURL)
    private var openURL

    let barcode: String

    @State private var name = ""
    @State private var brand = ""
    @State private var packageQuantity = ""

    @State private var packageCount = 1
    @State private var storageLocation = "Dispensa"

    @State private var trackingMode:
        InventoryTrackingMode = .packages

    @State private var unitsPerPackage = 6
    @State private var inventoryUnitName = ""

    @State private var hasExpirationDate = false

    @State private var expirationDate =
        Calendar.current.date(
            byAdding: .day,
            value: 7,
            to: Date()
        ) ?? Date()

    @State private var isSaving = false
    @State private var hasSavedProduct = false

    @State private var showProductCamera = false
    @State private var capturedPhoto: UIImage?
    @State private var localImageData: Data?
    @State private var photoErrorMessage: String?

    @State private var showNotificationSettingsAlert = false
    @State private var showNotificationFailureAlert = false

    @State private var errorMessage: String?

    private var cleanName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var amountToAdd: Int {
        Product.inventoryAmount(
            forPackageCount: packageCount,
            trackingMode: trackingMode,
            unitsPerPackage: unitsPerPackage
        )
    }

    private var amountPreviewText: String {
        guard trackingMode == .containedUnits else {
            return packageCount == 1
                ? "Salverai 1 confezione"
                : "Salverai \(packageCount) confezioni"
        }

        let singularName = Product.cleanedUnitName(
            inventoryUnitName
        )

        let unitName = amountToAdd == 1
            ? singularName
            : Product.italianPlural(
                of: singularName
            )

        return "Salverai \(amountToAdd) \(unitName)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        optionalPhotoCard

                        VStack(spacing: 14) {
                            PBTextField(
                                title: "Nome prodotto",
                                placeholder: "Es. Pesto genovese",
                                text: $name
                            )

                            PBTextField(
                                title: "Marca",
                                placeholder: "Facoltativa",
                                text: $brand
                            )

                            PBTextField(
                                title: "Quantità confezione",
                                placeholder: "Es. 500 g",
                                text: $packageQuantity
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text("Barcode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(barcode)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(PantryTheme.ink)
                                    .textSelection(.enabled)
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                        .padding(16)
                        .background(
                            PantryTheme.card,
                            in: RoundedRectangle(
                                cornerRadius: 22,
                                style: .continuous
                            )
                        )

                        PBInventoryTrackingEditor(
                            trackingMode: $trackingMode,
                            unitsPerPackage: $unitsPerPackage,
                            inventoryUnitName: $inventoryUnitName
                        )

                        PBQuantityControl(
                            title: "Confezioni da aggiungere",
                            quantity: $packageCount,
                            minimum: 1
                        )

                        Text(amountPreviewText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PantryTheme.forest)
                            .multilineTextAlignment(.center)

                        PBStoragePicker(
                            selection: $storageLocation
                        )

                        PBExpirationPicker(
                            hasExpirationDate: $hasExpirationDate,
                            expirationDate: $expirationDate
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        PBPrimaryButton(
                            title: "Salva prodotto",
                            systemImage: "checkmark.circle.fill",
                            disabled:
                                cleanName.isEmpty
                                || isSaving
                                || hasSavedProduct
                        ) {
                            saveProduct()
                        }
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
            .navigationTitle("Nuovo prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(PantryTheme.forest)
        .fullScreenCover(
            isPresented: $showProductCamera,
            onDismiss: prepareCapturedPhoto
        ) {
            ProductPhotoCameraView(
                onImageCaptured: { image in
                    capturedPhoto = image
                    showProductCamera = false
                },
                onCancel: {
                    capturedPhoto = nil
                    showProductCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "Notifiche disattivate",
            isPresented: $showNotificationSettingsAlert
        ) {
            Button("Apri Impostazioni") {
                if let settingsURL = URL(
                    string: UIApplication.openSettingsURLString
                ) {
                    openURL(settingsURL)
                }

                dismiss()
            }

            Button("Non ora", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(
                "Il prodotto e la sua scadenza sono stati salvati, ma PantryBuddy non può inviarti gli avvisi. Puoi attivare le notifiche nelle Impostazioni di iPhone."
            )
        }
        .alert(
            "Prodotto salvato",
            isPresented: $showNotificationFailureAlert
        ) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(
                "Il prodotto è stato aggiunto alla dispensa, ma non sono riuscito a programmare la notifica di scadenza. Potrai riprovare aprendo il prodotto dalla dispensa e salvandolo di nuovo."
            )
        }
    }

    private var optionalPhotoCard: some View {
        VStack(spacing: 12) {
            Text("Foto (facoltativa)")
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)

            if let localImageData {
                PBProductImage(
                    imageURL: nil,
                    localImageData: localImageData,
                    size: 130
                )
            }

            Button {
                photoErrorMessage = nil
                capturedPhoto = nil
                showProductCamera = true
            } label: {
                Label(
                    localImageData == nil
                        ? "Aggiungi foto"
                        : "Rifai foto",
                    systemImage: "camera.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(PantryTheme.forest)

            if localImageData != nil {
                Button(role: .destructive) {
                    localImageData = nil
                    photoErrorMessage = nil
                } label: {
                    Label(
                        "Rimuovi foto",
                        systemImage: "trash"
                    )
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
            }

            Text("Puoi salvare il prodotto anche senza foto.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let photoErrorMessage {
                Text(photoErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .disabled(isSaving || hasSavedProduct)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private func prepareCapturedPhoto() {
        guard let image = capturedPhoto else {
            return
        }

        capturedPhoto = nil

        guard let data = ProductPhotoStorage.compressedData(
            from: image
        ) else {
            photoErrorMessage =
                "Non sono riuscito a preparare la foto. Puoi riprovare o salvare senza."
            return
        }

        localImageData = data
        photoErrorMessage = nil
    }

    private func saveProduct() {
        guard !cleanName.isEmpty,
              !isSaving,
              !hasSavedProduct
        else {
            return
        }

        isSaving = true
        errorMessage = nil

        let newProduct = Product(
            barcode: barcode,
            name: cleanName,
            brand: brand.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            packageQuantity: packageQuantity.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            localImageData: localImageData,
            inventoryQuantity: amountToAdd,
            storageLocation: storageLocation,
            trackingMode: trackingMode,
            unitsPerPackage:
                trackingMode == .containedUnits
                    ? unitsPerPackage
                    : 1,
            inventoryUnitName: inventoryUnitName,
            expirationDate:
                hasExpirationDate
                    ? Calendar.current.startOfDay(
                        for: expirationDate
                    )
                    : nil
        )

        modelContext.insert(newProduct)

        do {
            try modelContext.save()
            hasSavedProduct = true

            Task { @MainActor in
                await finishSaving(newProduct)
            }
        } catch {
            modelContext.rollback()
            isSaving = false

            errorMessage =
                "Non sono riuscito a salvare il prodotto."

            print(
                "Errore salvataggio manuale:",
                error
            )
        }
    }

    private func finishSaving(
        _ product: Product
    ) async {
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
            isSaving = true
            showNotificationFailureAlert = true

        case .scheduled,
             .noExpirationDate,
             .noFutureNotifications:
            dismiss()
        }
    }
}
