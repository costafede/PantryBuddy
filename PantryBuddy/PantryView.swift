import SwiftData
import SwiftUI
import UIKit

private enum PantrySection:
    String,
    CaseIterable,
    Identifiable {

    case pantry = "Dispensa"
    case fridge = "Frigo"
    case freezer = "Freezer"
    case all = "Tutti"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .pantry:
            return "cabinet.fill"

        case .fridge:
            return "refrigerator.fill"

        case .freezer:
            return "snowflake"

        case .all:
            return "square.grid.2x2.fill"
        }
    }

    func contains(
        _ product: Product
    ) -> Bool {
        guard self != .all else {
            return true
        }

        return product.storageLocation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .localizedCaseInsensitiveCompare(
                rawValue
            )
            == .orderedSame
    }
}

struct PantryView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Product.name)
    private var products: [Product]

    @State private var selectedProduct: Product?
    @State private var saveErrorMessage: String?

    @State
    private var selectedSection: PantrySection = .pantry

    private var pantryProducts: [Product] {
        products.filter {
            $0.inventoryQuantity > 0
        }
    }

    private var visibleProducts: [Product] {
        pantryProducts.filter {
            selectedSection.contains($0)
        }
    }

    var body: some View {
        ZStack {
            PantryTheme.background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if pantryProducts.isEmpty {
                    emptyState
                } else {
                    sectionPicker
                        .padding(.horizontal, 20)

                    if visibleProducts.isEmpty {
                        sectionEmptyState
                    } else {
                        productList
                    }
                }
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(
            .hidden,
            for: .navigationBar
        )
        .sheet(
            isPresented: Binding(
                get: {
                    selectedProduct != nil
                },
                set: { isPresented in
                    if !isPresented {
                        selectedProduct = nil
                    }
                }
            )
        ) {
            if let selectedProduct {
                KnownProductView(
                    product: selectedProduct
                )
            }
        }
        .alert(
            "Modifica non riuscita",
            isPresented: Binding(
                get: {
                    saveErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        saveErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                "OK",
                role: .cancel
            ) {}
        } message: {
            Text(
                saveErrorMessage
                    ?? "Errore sconosciuto"
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: 1) {
                Text("La mia dispensa")
                    .font(
                        .system(
                            size: 22,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                if !pantryProducts.isEmpty {
                    Text(productCountText)
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(
                        systemName: "chevron.left"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        PantryTheme.ink
                    )
                    .frame(
                        width: 46,
                        height: 46
                    )
                    .background(
                        PantryTheme.card,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                PantryTheme.forest
                                    .opacity(0.10),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Indietro")

                Spacer()
            }
        }
        .frame(height: 52)
    }

    private var productCountText: String {
        visibleProducts.count == 1
            ? "1 prodotto"
            : "\(visibleProducts.count) prodotti"
    }

    // MARK: - Sezioni

    private var sectionPicker: some View {
        HStack(spacing: 10) {
            ForEach(
                PantrySection.allCases
            ) { section in
                Button {
                    withAnimation(
                        .easeInOut(
                            duration: 0.18
                        )
                    ) {
                        selectedSection = section
                    }
                } label: {
                    Image(
                        systemName:
                            section.systemImage
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        selectedSection == section
                            ? PantryTheme.cream
                            : PantryTheme.forest
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        selectedSection == section
                            ? PantryTheme.forest
                            : PantryTheme.card,
                        in: RoundedRectangle(
                            cornerRadius: 17,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 17,
                            style: .continuous
                        )
                        .stroke(
                            PantryTheme.forest
                                .opacity(0.12),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(section.rawValue), \(productCount(in: section)) prodotti"
                )
                .accessibilityAddTraits(
                    selectedSection == section
                        ? .isSelected
                        : []
                )
            }
        }
    }

    private func productCount(
        in section: PantrySection
    ) -> Int {
        pantryProducts.filter {
            section.contains($0)
        }
        .count
    }

    // MARK: - Lista prodotti

    private var productList: some View {
        List {
            ForEach(
                visibleProducts
            ) { product in
                Button {
                    selectedProduct = product
                } label: {
                    PantryProductCard(
                        product: product,
                        showsStorageLocation:
                            selectedSection == .all
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(
                        top: 7,
                        leading: 20,
                        bottom: 7,
                        trailing: 20
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(
                    edge: .leading,
                    allowsFullSwipe: false
                ) {
                    Button {
                        useOne(product)
                    } label: {
                        Label(
                            "Usa 1",
                            systemImage: "minus.circle"
                        )
                    }
                    .tint(PantryTheme.forest)
                }
                .swipeActions(
                    edge: .trailing,
                    allowsFullSwipe: true
                ) {
                    Button(
                        role: .destructive
                    ) {
                        removeFromPantry(product)
                    } label: {
                        Label(
                            "Rimuovi",
                            systemImage: "archivebox"
                        )
                    }
                }
                .contextMenu {
                    Button {
                        useOne(product)
                    } label: {
                        Label(
                            "Usa una unità",
                            systemImage: "minus.circle"
                        )
                    }

                    Button {
                        selectedProduct = product
                    } label: {
                        Label(
                            "Apri prodotto",
                            systemImage:
                                "square.and.pencil"
                        )
                    }

                    Button(
                        role: .destructive
                    ) {
                        removeFromPantry(product)
                    } label: {
                        Label(
                            "Rimuovi dalla dispensa",
                            systemImage: "archivebox"
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(
            .top,
            2,
            for: .scrollContent
        )
    }

    // MARK: - Dispensa completamente vuota

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        PantryTheme.forest
                            .opacity(0.10)
                    )
                    .frame(
                        width: 92,
                        height: 92
                    )

                Image(
                    systemName: "cabinet.fill"
                )
                .font(
                    .system(
                        size: 40,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    PantryTheme.forest
                )
            }

            Text("Dispensa vuota")
                .font(.title2.bold())
                .foregroundStyle(
                    PantryTheme.ink
                )

            Text(
                "Scansiona un prodotto dalla home per aggiungerlo. Gli articoli con solo uno storico prezzi restano nel catalogo."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 310)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 100)
    }

    // MARK: - Sezione vuota

    private var sectionEmptyState: some View {
        VStack(spacing: 14) {
            Image(
                systemName:
                    selectedSection.systemImage
            )
            .font(
                .system(
                    size: 34,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                PantryTheme.forest
            )
            .frame(
                width: 82,
                height: 82
            )
            .background(
                PantryTheme.forest.opacity(0.10),
                in: Circle()
            )

            Text("Nessun prodotto")
                .font(.title3.bold())
                .foregroundStyle(
                    PantryTheme.ink
                )

            Text(
                "Non ci sono ancora prodotti in \(selectedSection.rawValue.lowercased())."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 80)
    }

    // MARK: - Modifica rapida

    private func useOne(
        _ product: Product
    ) {
        guard product.inventoryQuantity > 0 else {
            return
        }

        product.inventoryQuantity -= 1

        saveInventoryChange(
            for: product,
            errorMessage:
                "Non sono riuscito ad aggiornare la quantità."
        )
    }

    // MARK: - Rimozione dalla dispensa

    private func removeFromPantry(
        _ product: Product
    ) {
        product.inventoryQuantity = 0

        saveInventoryChange(
            for: product,
            errorMessage:
                "Non sono riuscito a rimuovere il prodotto dalla dispensa."
        )
    }

    private func saveInventoryChange(
        for product: Product,
        errorMessage: String
    ) {
        do {
            try modelContext.save()

            if product.inventoryQuantity == 0 {
                ProductExpirationService.cancelNotifications(
                    for: product
                )
            }
        } catch {
            saveErrorMessage = errorMessage

            print(
                "Errore modifica dispensa:",
                error
            )
        }
    }
}

// MARK: - Card prodotto

private struct PantryProductCard: View {

    let product: Product
    let showsStorageLocation: Bool

    private var subtitle: String {
        [
            product.brand,
            product.packageQuantity
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(
            separator: " · "
        )
    }

    private var storageSystemImage: String {
        switch product.storageLocation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased() {
        case "frigo", "frigorifero":
            return "refrigerator.fill"

        case "freezer", "congelatore":
            return "snowflake"

        default:
            return "cabinet.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            productImage

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(
                        PantryTheme.ink
                    )
                    .lineLimit(2)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if showsStorageLocation {
                        Image(
                            systemName:
                                storageSystemImage
                        )
                        .accessibilityLabel(
                            product.storageLocation
                        )

                        Text("·")
                    }

                    Text(
                        "Disponibilità: \(product.inventoryQuantityText)"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }
                .font(
                    .caption2.weight(.semibold)
                )
                .foregroundStyle(
                    PantryTheme.forest
                )

                if let expirationDate =
                    product.expirationDate
                {
                    PBExpirationBadge(
                        expirationDate:
                            expirationDate
                    )
                }
            }

            Spacer(minLength: 8)

            Image(
                systemName: "chevron.right"
            )
            .font(
                .caption.weight(.bold)
            )
            .foregroundStyle(
                PantryTheme.forest.opacity(0.55)
            )
        }
        .padding(14)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                PantryTheme.forest.opacity(0.10),
                lineWidth: 1
            )
        }
    }

    // MARK: Immagine prodotto

    @ViewBuilder
    private var productImage: some View {
        /*
         La foto scattata dall’utente ha la precedenza.
         */
        if let localImageData =
            product.localImageData,
           let localImage = UIImage(
               data: localImageData
           ) {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: 66,
                    height: 66
                )
                .clipped()
                .background(
                    PantryTheme.background,
                    in: RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )

        } else if let imageURL =
                    product.imageURL,
                  let url = URL(
                      string: imageURL
                  ) {
            PBCachedRemoteImage(
                url: url
            ) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            } failure: {
                imagePlaceholder
            }
            .frame(
                width: 66,
                height: 66
            )
            .background(
                PantryTheme.background,
                in: RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )

        } else {
            imagePlaceholder
                .frame(
                    width: 66,
                    height: 66
                )
                .background(
                    PantryTheme.forest.opacity(0.09),
                    in: RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )
        }
    }

    private var imagePlaceholder: some View {
        Image(
            systemName: "shippingbox.fill"
        )
        .font(.system(size: 25))
        .foregroundStyle(
            PantryTheme.forest.opacity(0.70)
        )
    }
}
