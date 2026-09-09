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

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(spacing: 18) {
                        Image(
                            systemName:
                                "square.and.pencil"
                        )
                        .font(
                            .system(
                                size: 38,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            PantryTheme.forest
                        )
                        .frame(
                            width: 90,
                            height: 90
                        )
                        .background(
                            PantryTheme.forest
                                .opacity(0.10),
                            in: Circle()
                        )
                        .padding(.top, 10)

                        VStack(spacing: 14) {
                            PBTextField(
                                title: "Nome prodotto",
                                placeholder:
                                    "Es. Pesto genovese",
                                text: $name
                            )

                            PBTextField(
                                title: "Marca",
                                placeholder: "Facoltativa",
                                text: $brand
                            )

                            PBTextField(
                                title:
                                    "Quantità confezione",
                                placeholder: "Es. 500 g",
                                text: $packageQuantity
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text("Barcode")
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )

                                Text(barcode)
                                    .font(
                                        .caption
                                            .monospaced()
                                    )
                                    .foregroundStyle(
                                        PantryTheme.ink
                                    )
                                    .textSelection(
                                        .enabled
                                    )
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
                            title: "Salva prodotto",
                            systemImage:
                                "checkmark.circle.fill",
                            disabled:
                                cleanName.isEmpty
                                || isSaving
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
        guard !cleanName.isEmpty,
              !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        let newProduct = Product(
            barcode: barcode,
            name: cleanName,
            brand:
                brand.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            packageQuantity:
                packageQuantity
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
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
