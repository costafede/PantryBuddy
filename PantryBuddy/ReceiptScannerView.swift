import SwiftUI
import UIKit

struct ReceiptScannerView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var showCamera = true
    @State private var showMatching = false

    @State
    private var capturedImage: UIImage?

    @State
    private var receiptResult: ReceiptOCRResult?

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showRawText = false

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if let capturedImage {
                            receiptImage(capturedImage)
                        }

                        if isProcessing {
                            processingCard
                        }

                        if let errorMessage {
                            errorCard(message: errorMessage)
                        }

                        if let receiptResult {
                            storeCard(receiptResult)

                            detectedProductsCard(receiptResult)

                            PBPrimaryButton(
                                title: "Continua",
                                systemImage: "arrow.right.circle.fill",
                                disabled: processableItems(
                                    in: receiptResult
                                ).isEmpty
                            ) {
                                showMatching = true
                            }

                            Button {
                                takeAnotherPhoto()
                            } label: {
                                Label(
                                    "Scatta un’altra foto",
                                    systemImage: "camera"
                                )
                                .font(.headline)
                                .foregroundStyle(PantryTheme.forest)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    PantryTheme.card,
                                    in: RoundedRectangle(
                                        cornerRadius: 18
                                    )
                                )
                            }
                            .buttonStyle(.plain)

                            rawTextCard(receiptResult)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Scansiona scontrino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                PantryTheme.background,
                for: .navigationBar
            )
            .toolbarBackground(
                .visible,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundStyle(PantryTheme.forest)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ReceiptCameraView(
                    onImageCaptured: { image in
                        capturedImage = image
                        showCamera = false

                        Task { @MainActor in
                            // Aspetta che la fotocamera sia stata
                            // realmente chiusa prima di avviare Vision.
                            try? await Task.sleep(
                                for: .milliseconds(300)
                            )

                            guard !Task.isCancelled else {
                                return
                            }

                            await recognizeReceipt(image: image)
                        }
                    },
                    onCancel: {
                        showCamera = false

                        if capturedImage == nil {
                            dismiss()
                        }
                    }
                )
                .background(
                    Color.black
                        .ignoresSafeArea()
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showMatching) {
                if let receiptResult {
                    ReceiptMatchingView(
                        result: receiptResult,
                        onSaved: {
                            showMatching = false
                            dismiss()
                        }
                    )
                }
            }
        }
        .tint(PantryTheme.forest)
    }

    // MARK: - Foto

    private func receiptImage(
        _ image: UIImage
    ) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 270)
            .padding(8)
            .background(
                PantryTheme.card,
                in: RoundedRectangle(
                    cornerRadius: 22
                )
            )
            .clipShape(
                RoundedRectangle(
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

    // MARK: - Stato

    private var processingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(PantryTheme.forest)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("Leggo lo scontrino…")
                    .font(.headline)
                    .foregroundStyle(PantryTheme.ink)

                Text(
                    "Cerco negozio, data, prodotti e prezzi."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private func errorCard(
        message: String
    ) -> some View {
        VStack(spacing: 14) {
            Image(
                systemName: "exclamationmark.triangle.fill"
            )
            .font(.system(size: 34))
            .foregroundStyle(PantryTheme.gold)

            Text("Non riesco a leggere lo scontrino")
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Riprova") {
                takeAnotherPhoto()
            }
            .font(.headline)
            .foregroundStyle(PantryTheme.forest)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    // MARK: - Risultato

    private func storeCard(
        _ result: ReceiptOCRResult
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "storefront.fill")
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(PantryTheme.forest)
                .frame(
                    width: 44,
                    height: 44
                )
                .background(
                    PantryTheme.forest.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("Negozio")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    result.storeName ?? "Da specificare"
                )
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)
            }

            Spacer()

            if let purchaseDate = result.purchaseDate {
                Text(
                    purchaseDate,
                    format: .dateTime
                        .day()
                        .month(.abbreviated)
                        .year()
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(PantryTheme.forest)
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

    private func detectedProductsCard(
        _ result: ReceiptOCRResult
    ) -> some View {
        let validItems = processableItems(in: result)
        let ignoredItems = automaticallyIgnoredItems(in: result)

        return VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack {
                Label(
                    "Prodotti rilevati",
                    systemImage: "list.bullet"
                )
                .font(.headline)
                .foregroundStyle(PantryTheme.ink)

                Spacer()

                Text("\(validItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(PantryTheme.forest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        PantryTheme.forest.opacity(0.10),
                        in: Capsule()
                    )
            }

            if validItems.isEmpty {
                Text(
                    "Non ho trovato righe prodotto affidabili."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.vertical, 10)
            } else {
                ForEach(
                    Array(validItems.enumerated()),
                    id: \.element.id
                ) { index, item in

                    if index > 0 {
                        Divider()
                    }

                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: 12
                    ) {
                        Text(item.description)
                            .font(
                                .subheadline.weight(.semibold)
                            )
                            .foregroundStyle(PantryTheme.ink)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )

                        Text(
                            item.price,
                            format: .currency(code: "NOK")
                        )
                        .font(
                            .subheadline
                                .bold()
                                .monospacedDigit()
                        )
                        .foregroundStyle(PantryTheme.forest)
                    }
                }
            }

            if !ignoredItems.isEmpty {
                Divider()

                Label(
                    "\(ignoredItems.count) riga non prodotto esclusa",
                    systemImage: "minus.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func rawTextCard(
        _ result: ReceiptOCRResult
    ) -> some View {
        DisclosureGroup(
            isExpanded: $showRawText
        ) {
            Text(result.rawText)
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(.top, 12)
                .textSelection(.enabled)
        } label: {
            Label(
                "Testo rilevato",
                systemImage: "text.viewfinder"
            )
            .font(
                .subheadline.weight(.semibold)
            )
            .foregroundStyle(PantryTheme.forest)
        }
        .padding(18)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: - OCR

    @MainActor
    private func recognizeReceipt(
        image: UIImage
    ) async {
        isProcessing = true
        errorMessage = nil
        receiptResult = nil

        do {
            let result =
                try await ReceiptOCRService.recognizeReceipt(
                    from: image
                )

            let recognizedText =
                result.rawText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if recognizedText.count < 8 {
                errorMessage =
                    """
                    La foto è troppo sfocata, scura o incompleta. \
                    Distendi lo scontrino, usa più luce e inquadralo interamente.
                    """
            } else if processableItems(in: result).isEmpty {
                errorMessage =
                    """
                    Ho riconosciuto del testo, ma nessun prodotto con un prezzo affidabile. \
                    Prova a scattare la foto più vicino e senza ombre.
                    """
            } else {
                receiptResult = result
            }
        } catch ReceiptOCRError.invalidImage {
            errorMessage =
                """
                La foto non può essere elaborata. \
                Scattane una nuova direttamente dalla fotocamera.
                """
        } catch ReceiptOCRError.recognitionFailed {
            errorMessage =
                """
                Il testo non è abbastanza leggibile. \
                Tieni il telefono fermo e fotografa lo scontrino su una superficie piana.
                """
        } catch {
            errorMessage =
                """
                La lettura non è riuscita. \
                Riprova con più luce e assicurati che tutto lo scontrino sia visibile.
                """

            print("OCR error:", error)
        }

        isProcessing = false
    }

    private func takeAnotherPhoto() {
        capturedImage = nil
        receiptResult = nil
        errorMessage = nil
        showRawText = false
        showCamera = true
    }

    // MARK: - Filtraggio

    private func processableItems(
        in result: ReceiptOCRResult
    ) -> [ReceiptProductItem] {
        result.items.filter {
            !shouldIgnoreAutomatically($0.description)
        }
    }

    private func automaticallyIgnoredItems(
        in result: ReceiptOCRResult
    ) -> [ReceiptProductItem] {
        result.items.filter {
            shouldIgnoreAutomatically($0.description)
        }
    }

    private func shouldIgnoreAutomatically(
        _ description: String
    ) -> Bool {
        let normalized =
            description
                .uppercased()
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return normalized == "PANT"
            || normalized.hasPrefix("PANT ")
    }
}
