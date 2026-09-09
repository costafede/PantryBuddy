import SwiftData
import SwiftUI
import UIKit

struct ProductDetailView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.openURL)
    private var openURL

    let barcode: String
    let product: OpenFoodFactsProduct

    @State private var packageCount = 1
    @State private var storageLocation =
        "Dispensa"

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

    @State
    private var showNotificationSettingsAlert = false

    @State
    private var showNotificationFailureAlert = false

    @State private var errorMessage: String?

    private var productName: String {
        let value = product.productName?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        return value.isEmpty
            ? "Prodotto senza nome"
            : value
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
                ? "Aggiungerai 1 confezione"
                : "Aggiungerai \(packageCount) confezioni"
        }

        let singularName = Product.cleanedUnitName(
            inventoryUnitName
        )

        let unitName = amountToAdd == 1
            ? singularName
            : Product.italianPlural(
                of: singularName
            )

        return "Aggiungerai \(amountToAdd) \(unitName)"
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
                            imageURL:
                                product.imageFrontUrl
                        )
                        .padding(.top, 12)

                        VStack(spacing: 5) {
                            Text(productName)
                                .font(.title2.bold())
                                .foregroundStyle(
                                    PantryTheme.ink
                                )
                                .multilineTextAlignment(
                                    .center
                                )

                            let details = [
                                product.brands,
                                product.quantity
                            ]
                            .compactMap { $0 }
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")

                            if !details.isEmpty {
                                Text(details)
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .multilineTextAlignment(
                                        .center
                                    )
                            }

                            Text(
                                "Barcode: \(barcode)"
                            )
                            .font(
                                .caption2.monospaced()
                            )
                            .foregroundStyle(.tertiary)
                        }

                        PBInventoryTrackingEditor(
                            trackingMode:
                                $trackingMode,
                            unitsPerPackage:
                                $unitsPerPackage,
                            inventoryUnitName:
                                $inventoryUnitName
                        )

                        PBQuantityControl(
                            title:
                                "Confezioni da aggiungere",
                            quantity:
                                $packageCount,
                            minimum: 1
                        )

                        Text(amountPreviewText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                PantryTheme.forest
                            )
                            .multilineTextAlignment(.center)

                        PBStoragePicker(
                            selection: $storageLocation
                        )

                        PBExpirationPicker(
                            hasExpirationDate:
                                $hasExpirationDate,
                            expirationDate:
                                $expirationDate
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        PBPrimaryButton(
                            title:
                                "Aggiungi alla dispensa",
                            systemImage:
                                "plus.circle.fill",
                            disabled: isSaving
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
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
        .tint(PantryTheme.forest)
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
                "Il prodotto e la sua scadenza sono stati salvati, ma PantryBuddy non può inviarti gli avvisi. Puoi attivare le notifiche nelle Impostazioni di iPhone."
            )
        }
        .alert(
            "Prodotto salvato",
            isPresented:
                $showNotificationFailureAlert
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

    private func saveProduct() {
        guard !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        let newProduct = Product(
            barcode: barcode,
            name: productName,
            brand: product.brands ?? "",
            packageQuantity:
                product.quantity ?? "",
            imageURL:
                product.imageFrontUrl,
            inventoryQuantity:
                amountToAdd,
            storageLocation:
                storageLocation,
            trackingMode:
                trackingMode,
            unitsPerPackage:
                trackingMode == .containedUnits
                    ? unitsPerPackage
                    : 1,
            inventoryUnitName:
                inventoryUnitName,
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

            Task { @MainActor in
                await finishSaving(
                    newProduct
                )
            }

        } catch {
            modelContext.rollback()
            isSaving = false

            errorMessage =
                "Non sono riuscito ad aggiungere il prodotto."

            print(
                "Errore salvataggio prodotto:",
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
