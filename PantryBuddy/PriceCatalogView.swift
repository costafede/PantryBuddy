import SwiftUI
import SwiftData

struct PriceCatalogView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Query(sort: \Product.name)
    private var products: [Product]

    @Query(
        sort: \PriceRecord.purchaseDate,
        order: .reverse
    )
    private var priceRecords: [PriceRecord]

    @AppStorage(
        "PantryBuddyIgnoredDuplicatePairs"
    )
    private var ignoredPairs = ""

    @State private var searchText = ""
    @State private var showMerge = false

    private var visibleProducts: [Product] {
        let withPrices = products.filter { product in
            priceRecords.contains {
                $0.productBarcode == product.barcode
            }
        }

        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return withPrices
        }

        return withPrices.filter {
            $0.name.localizedStandardContains(query)
                || $0.brand.localizedStandardContains(query)
                || $0.packageQuantity
                    .localizedStandardContains(query)
                || $0.barcode
                    .localizedStandardContains(query)
        }
    }

    private var suggestions:
        [ProductDuplicateSuggestion] {

        let ignored = Set(
            ignoredPairs
                .split(separator: "\n")
                .map(String.init)
        )

        return ProductMergeService
            .suggestions(
                products: products,
                priceRecords: priceRecords
            )
            .filter {
                !ignored.contains($0.id)
            }
    }

    var body: some View {
        ZStack {
            PantryTheme.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                searchBar

                if !suggestions.isEmpty {
                    duplicateBanner
                }

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(
            .hidden,
            for: .navigationBar
        )
        .sheet(
            isPresented: $showMerge
        ) {
            MergeProductsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Catalogo prezzi")
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(PantryTheme.ink)

            HStack {
                roundButton(
                    "chevron.left",
                    label: "Indietro"
                ) {
                    dismiss()
                }

                Spacer()

                roundButton(
                    "link",
                    label: "Unisci prodotti"
                ) {
                    showMerge = true
                }
            }
        }
        .frame(height: 52)
    }

    // MARK: - Ricerca

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PantryTheme.forest)

            TextField(
                "Cerca prodotto, marca o barcode",
                text: $searchText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName: "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: - Duplicati

    private var duplicateBanner: some View {
        Button {
            showMerge = true
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName: "link.circle.fill"
                )
                .font(.system(size: 30))
                .foregroundStyle(PantryTheme.gold)

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("Possibili duplicati")
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            PantryTheme.ink
                        )

                    Text(
                        "\(suggestions.count) da controllare"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Controlla")
                    .font(.caption.bold())
                    .foregroundStyle(
                        PantryTheme.forest
                    )
            }
            .padding(13)
            .background(
                PantryTheme.card,
                in: RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    PantryTheme.gold.opacity(0.22),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contenuto

    @ViewBuilder
    private var content: some View {
        if priceRecords.isEmpty {
            emptyState(
                title: "Nessun prezzo salvato",
                message:
                    "Scansiona uno scontrino e i prezzi compariranno qui.",
                icon: "tag.fill"
            )
        } else if visibleProducts.isEmpty {
            emptyState(
                title: "Nessun prodotto trovato",
                message:
                    "Prova a usare un altro nome, marca o barcode.",
                icon: "magnifyingglass"
            )
        } else {
            ScrollView(
                showsIndicators: false
            ) {
                LazyVStack(spacing: 14) {
                    ForEach(
                        visibleProducts
                    ) { product in
                        NavigationLink {
                            ProductPriceDetailView(
                                product: product
                            )
                        } label: {
                            CatalogProductCard(
                                product: product,
                                records:
                                    records(for: product)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 3)
                .padding(.bottom, 28)
            }
        }
    }

    private func records(
        for product: Product
    ) -> [PriceRecord] {
        priceRecords.filter {
            $0.productBarcode == product.barcode
        }
    }

    private func roundButton(
        _ icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 17,
                        weight: .bold
                    )
                )
                .foregroundStyle(PantryTheme.ink)
                .frame(
                    width: 46,
                    height: 46
                )
                .background(
                    PantryTheme.card,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func emptyState(
        title: String,
        message: String,
        icon: String
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34))
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

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(PantryTheme.ink)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.bottom, 80)
    }
}

// MARK: - Card prodotto

private struct CatalogProductCard: View {

    let product: Product
    let records: [PriceRecord]

    private var stores: [CatalogStoreSummary] {
        Dictionary(
            grouping: records
        ) {
            normalizedStore($0.storeName)
        }
        .compactMap { key, values in
            guard
                let latest = values.max(
                    by: {
                        $0.purchaseDate
                            < $1.purchaseDate
                    }
                ),
                let minimum =
                    values.map(\.price).min(),
                let maximum =
                    values.map(\.price).max()
            else {
                return nil
            }

            return CatalogStoreSummary(
                id: key,
                name: latest.storeName,
                latest: latest.price,
                minimum: minimum,
                maximum: maximum
            )
        }
        .sorted {
            $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 13
        ) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(
                        PantryTheme.gold
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )
                    .background(
                        PantryTheme.gold.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: 13,
                            style: .continuous
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundStyle(
                            PantryTheme.ink
                        )
                        .lineLimit(2)

                    let subtitle = [
                        product.brand,
                        product.packageQuantity
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(
                    systemName: "chevron.right"
                )
                .font(.caption.bold())
                .foregroundStyle(
                    PantryTheme.forest
                        .opacity(0.60)
                )
            }

            ForEach(stores) { store in
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Label(
                        store.name,
                        systemImage: "cart.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                    HStack(spacing: 8) {
                        price(
                            "Ultimo",
                            store.latest,
                            color:
                                PantryTheme.forest
                        )

                        price(
                            "Min",
                            store.minimum,
                            color: PantryTheme.ink
                        )

                        price(
                            "Max",
                            store.maximum,
                            color: PantryTheme.ink
                        )
                    }
                }
                .padding(12)
                .background(
                    PantryTheme.forest.opacity(0.07),
                    in: RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                )
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .stroke(
                PantryTheme.forest.opacity(0.10),
                lineWidth: 1
            )
        }
    }

    private func price(
        _ title: String,
        _ value: Double,
        color: Color
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(
                value,
                format: .currency(code: "NOK")
            )
            .font(.caption.bold())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

private struct CatalogStoreSummary:
    Identifiable {

    let id: String
    let name: String
    let latest: Double
    let minimum: Double
    let maximum: Double
}

// MARK: - Schermata unione

private struct MergeProductsView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Product.name)
    private var products: [Product]

    @Query
    private var priceRecords: [PriceRecord]

    @Query
    private var aliases: [ReceiptAlias]

    @AppStorage(
        "PantryBuddyIgnoredDuplicatePairs"
    )
    private var ignoredPairs = ""

    @State private var firstBarcode = ""
    @State private var secondBarcode = ""
    @State private var pendingPair: MergePair?
    @State private var message: String?

    private var suggestions:
        [ProductDuplicateSuggestion] {

        let ignored = Set(
            ignoredPairs
                .split(separator: "\n")
                .map(String.init)
        )

        return ProductMergeService
            .suggestions(
                products: products,
                priceRecords: priceRecords
            )
            .filter {
                !ignored.contains($0.id)
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
                    VStack(
                        alignment: .leading,
                        spacing: 18
                    ) {
                        Text(
                            "L’app mantiene il barcode reale, tutti i prezzi e le associazioni degli scontrini."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let message {
                            Label(
                                message,
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                            .font(.subheadline.bold())
                            .foregroundStyle(
                                PantryTheme.forest
                            )
                            .padding(14)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .background(
                                PantryTheme.forest
                                    .opacity(0.09),
                                in: RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                            )
                        }

                        Text("Possibili duplicati")
                            .font(.title3.bold())

                        if suggestions.isEmpty {
                            Text(
                                "Nessun duplicato evidente trovato"
                            )
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .background(
                                PantryTheme.card,
                                in: RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                        } else {
                            ForEach(
                                suggestions
                            ) { suggestion in
                                suggestionCard(
                                    suggestion
                                )
                            }
                        }

                        manualSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Unisci prodotti")
            .navigationBarTitleDisplayMode(
                .inline
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
                "Unire questi prodotti?",
                isPresented: Binding(
                    get: {
                        pendingPair != nil
                    },
                    set: {
                        if !$0 {
                            pendingPair = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Unisci") {
                    if let pair = pendingPair {
                        merge(pair)
                    }

                    pendingPair = nil
                }

                Button(
                    "Annulla",
                    role: .cancel
                ) {
                    pendingPair = nil
                }
            } message: {
                Text(
                    "Lo storico completo verrà conservato."
                )
            }
        }
        .tint(PantryTheme.forest)
    }

    private func suggestionCard(
        _ suggestion:
            ProductDuplicateSuggestion
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            productName(suggestion.first)

            Divider()

            productName(suggestion.second)

            HStack(spacing: 10) {
                Button {
                    ignore(suggestion.id)
                } label: {
                    Label(
                        "Non sono uguali",
                        systemImage: "xmark"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(
                        PantryTheme.ink
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.horizontal, 8)
                    .background(
                        PantryTheme.background,
                        in: RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                        .stroke(
                            PantryTheme.ink.opacity(0.14),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)

                Button {
                    pendingPair = MergePair(
                        first:
                            suggestion.first.barcode,
                        second:
                            suggestion.second.barcode
                    )
                } label: {
                    Label(
                        "Unisci",
                        systemImage: "link"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(
                        PantryTheme.cream
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.horizontal, 8)
                    .background(
                        PantryTheme.primaryGradient,
                        in: RoundedRectangle(
                            cornerRadius: 15,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 3)
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 19,
                style: .continuous
            )
        )
    }

    private func productName(
        _ product: Product
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(product.name)
                .font(.subheadline.bold())
                .foregroundStyle(PantryTheme.ink)

            Text(
                product.barcode.hasPrefix("catalog-")
                    ? "Creato dallo scontrino"
                    : "Barcode: \(product.barcode)"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var manualSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Unione manuale")
                .font(.title3.bold())

            Picker(
                "Primo prodotto",
                selection: $firstBarcode
            ) {
                Text("Seleziona")
                    .tag("")

                ForEach(products) {
                    Text($0.name)
                        .tag($0.barcode)
                }
            }

            Picker(
                "Secondo prodotto",
                selection: $secondBarcode
            ) {
                Text("Seleziona")
                    .tag("")

                ForEach(
                    products.filter {
                        $0.barcode != firstBarcode
                    }
                ) {
                    Text($0.name)
                        .tag($0.barcode)
                }
            }

            Button {
                pendingPair = MergePair(
                    first: firstBarcode,
                    second: secondBarcode
                )
            } label: {
                Label(
                    "Unisci i prodotti selezionati",
                    systemImage: "link"
                )
                .font(.subheadline.bold())
                .foregroundStyle(
                    PantryTheme.cream
                )
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    PantryTheme.primaryGradient,
                    in: RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                firstBarcode.isEmpty
                    || secondBarcode.isEmpty
            )
            .opacity(
                firstBarcode.isEmpty
                    || secondBarcode.isEmpty
                    ? 0.45
                    : 1
            )
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func ignore(
        _ id: String
    ) {
        var values = Set(
            ignoredPairs
                .split(separator: "\n")
                .map(String.init)
        )

        values.insert(id)

        ignoredPairs =
            values.sorted().joined(separator: "\n")
    }

    private func merge(
        _ pair: MergePair
    ) {
        guard
            let first = products.first(
                where: {
                    $0.barcode == pair.first
                }
            ),
            let second = products.first(
                where: {
                    $0.barcode == pair.second
                }
            )
        else {
            return
        }

        do {
            let keeper =
                try ProductMergeService.merge(
                    first: first,
                    second: second,
                    priceRecords: priceRecords,
                    receiptAliases: aliases,
                    modelContext: modelContext
                )

            message =
                "Prodotti uniti in “\(keeper.name)”."

            firstBarcode = ""
            secondBarcode = ""

        } catch {
            message =
                "Unione non riuscita. Riprova."

            print(
                "Errore unione prodotti:",
                error
            )
        }
    }
}

private struct MergePair {
    let first: String
    let second: String
}

private func normalizedStore(
    _ name: String
) -> String {
    name
        .folding(
            options: .diacriticInsensitive,
            locale: .current
        )
        .lowercased()
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
}
