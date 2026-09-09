import SwiftUI
import SwiftData

struct ProductPriceDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    let product: Product

    @Query(
        sort: \PriceRecord.purchaseDate,
        order: .reverse
    )
    private var allPriceRecords:
        [PriceRecord]

    @State private var showProductEditor =
        false

    @State private var showAddPrice =
        false

    @State private var editingRecord:
        PriceRecord?

    @State private var recordToDelete:
        PriceRecord?

    @State private var errorMessage:
        String?

    @State private var
        didNormalizeStores = false

    private var productRecords:
        [PriceRecord] {

        allPriceRecords.filter {
            $0.productBarcode
                == product.barcode
        }
    }

    private var storeGroups:
        [PriceStoreGroup] {

        Dictionary(
            grouping: productRecords
        ) {
            StoreNameNormalizer
                .groupingKey(
                    $0.storeName
                )
        }
        .compactMap {
            key,
            records in

            let sorted =
                records.sorted {
                    $0.purchaseDate
                        > $1.purchaseDate
                }

            guard
                let latest = sorted.first,
                let minimum =
                    records
                    .map(\.price)
                    .min(),
                let maximum =
                    records
                    .map(\.price)
                    .max()
            else {
                return nil
            }

            return PriceStoreGroup(
                id: key,
                storeName:
                    StoreNameNormalizer
                    .canonicalName(
                        latest.storeName
                    ),
                latest: latest.price,
                minimum: minimum,
                maximum: maximum,
                records: sorted
            )
        }
        .sorted {
            $0.storeName
                .localizedStandardCompare(
                    $1.storeName
                )
                == .orderedAscending
        }
    }

    private var cheapestStore:
        PriceStoreGroup? {

        storeGroups.min {
            $0.latest < $1.latest
        }
    }

    var body: some View {
        ZStack {
            PantryTheme.background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                    .padding(
                        .horizontal,
                        20
                    )
                    .padding(.top, 8)

                ScrollView(
                    showsIndicators: false
                ) {
                    VStack(spacing: 16) {
                        productCard

                        addPriceButton

                        if storeGroups.count > 1,
                           let cheapestStore {

                            cheapestStoreCard(
                                cheapestStore
                            )
                        }

                        ForEach(storeGroups) {
                            group in

                            storeCard(group)
                        }
                    }
                    .padding(
                        .horizontal,
                        20
                    )
                    .padding(
                        .bottom,
                        30
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(
            true
        )
        .toolbar(
            .hidden,
            for: .navigationBar
        )
        .task {
            normalizeExistingStoreNames()
        }
        .sheet(
            isPresented:
                $showProductEditor
        ) {
            EditCatalogProductView(
                product: product
            )
        }
        .sheet(
            isPresented:
                $showAddPrice
        ) {
            AddManualPriceView(
                product: product
            )
        }
        .sheet(
            isPresented: Binding(
                get: {
                    editingRecord != nil
                },
                set: { isPresented in
                    if !isPresented {
                        editingRecord = nil
                    }
                }
            )
        ) {
            if let editingRecord {
                EditPriceRecordView(
                    record:
                        editingRecord
                )
            }
        }
        .confirmationDialog(
            "Eliminare questo prezzo?",
            isPresented: Binding(
                get: {
                    recordToDelete != nil
                },
                set: { isPresented in
                    if !isPresented {
                        recordToDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                "Elimina prezzo",
                role: .destructive
            ) {
                if let recordToDelete {
                    delete(
                        recordToDelete
                    )
                }

                recordToDelete = nil
            }

            Button(
                "Annulla",
                role: .cancel
            ) {
                recordToDelete = nil
            }
        } message: {
            Text(
                "Verrà eliminata soltanto questa rilevazione."
            )
        }
        .alert(
            "Operazione non riuscita",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
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
                errorMessage
                ?? "Errore sconosciuto"
            )
        }
    }

    // MARK: - Aggiungi prezzo

    private var addPriceButton:
        some View {

        PBPrimaryButton(
            title: "Aggiungi prezzo",
            systemImage:
                "plus.circle.fill"
        ) {
            showAddPrice = true
        }
    }

    // MARK: - Normalizzazione

    @MainActor
    private func
        normalizeExistingStoreNames() {

        guard !didNormalizeStores else {
            return
        }

        didNormalizeStores = true

        var changed = false

        for record in allPriceRecords {
            let canonical =
                StoreNameNormalizer
                    .canonicalName(
                        record.storeName
                    )

            if record.storeName
                != canonical {

                record.storeName =
                    canonical

                changed = true
            }
        }

        guard changed else {
            return
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage =
                "Non sono riuscito a uniformare i supermercati."
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Storico prezzi")
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    PantryTheme.ink
                )

            HStack {
                circleButton(
                    "chevron.left",
                    label: "Indietro"
                ) {
                    dismiss()
                }

                Spacer()

                circleButton(
                    "pencil",
                    label:
                        "Modifica prodotto"
                ) {
                    showProductEditor =
                        true
                }
            }
        }
        .frame(height: 52)
    }

    private func circleButton(
        _ image: String,
        label: String,
        action:
            @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(
                    .system(
                        size: 16,
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Prodotto

    private var productCard:
        some View {

        HStack(spacing: 14) {
            PBProductImage(
                imageURL:
                    product.imageURL,
                size: 76
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(product.name)
                    .font(
                        .title3.bold()
                    )
                    .foregroundStyle(
                        PantryTheme.ink
                    )

                let details = [
                    product.brand,
                    product.packageQuantity
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " · "
                )

                if !details.isEmpty {
                    Text(details)
                        .font(
                            .subheadline
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }

                Text(
                    product.barcode
                        .hasPrefix(
                            "catalog-"
                        )
                    ? "Creato da uno scontrino"
                    : "Barcode: \(product.barcode)"
                )
                .font(.caption2)
                .foregroundStyle(
                    .tertiary
                )
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 23
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 23
            )
            .stroke(
                PantryTheme.forest
                    .opacity(0.10),
                lineWidth: 1
            )
        }
    }

    // MARK: - Negozio più conveniente

    private func cheapestStoreCard(
        _ store: PriceStoreGroup
    ) -> some View {
        HStack(spacing: 13) {
            Image(
                systemName:
                    "checkmark.seal.fill"
            )
            .font(
                .system(size: 28)
            )
            .foregroundStyle(
                PantryTheme.forest
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    "Ultimo prezzo più basso"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Text(store.storeName)
                    .font(.headline)
                    .foregroundStyle(
                        PantryTheme.ink
                    )
            }

            Spacer()

            Text(
                store.latest,
                format: .currency(
                    code: "NOK"
                )
            )
            .font(.headline)
            .foregroundStyle(
                PantryTheme.forest
            )
        }
        .padding(16)
        .background(
            PantryTheme.forest
                .opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20
            )
            .stroke(
                PantryTheme.forest
                    .opacity(0.18),
                lineWidth: 1
            )
        }
    }

    // MARK: - Supermercato

    private func storeCard(
        _ group: PriceStoreGroup
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            HStack {
                Label(
                    group.storeName,
                    systemImage: "cart.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    PantryTheme.ink
                )

                Spacer()

                Text(
                    group.records.count == 1
                    ? "1 prezzo"
                    : "\(group.records.count) prezzi"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            HStack(spacing: 8) {
                summary(
                    "Ultimo",
                    group.latest,
                    PantryTheme.forest
                )

                summary(
                    "Minimo",
                    group.minimum,
                    PantryTheme.leaf
                )

                summary(
                    "Massimo",
                    group.maximum,
                    PantryTheme.gold
                )
            }

            Divider()
                .overlay(
                    PantryTheme.forest
                        .opacity(0.10)
                )

            Text("Storico completo")
                .font(
                    .subheadline.bold()
                )
                .foregroundStyle(
                    PantryTheme.ink
                )

            ForEach(group.records) {
                record in

                historyRow(record)
            }
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 23
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 23
            )
            .stroke(
                PantryTheme.forest
                    .opacity(0.10),
                lineWidth: 1
            )
        }
    }

    private func summary(
        _ title: String,
        _ value: Double,
        _ color: Color
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )

            Text(
                value,
                format: .currency(
                    code: "NOK"
                )
            )
            .font(.caption.bold())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.60)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(10)
        .background(
            color.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: 13
            )
        )
    }

    private func historyRow(
        _ record: PriceRecord
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    record.purchaseDate,
                    format:
                        .dateTime
                        .day()
                        .month()
                        .year()
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    PantryTheme.ink
                )

                if !record
                    .receiptDescription
                    .isEmpty {

                    Text(
                        record
                            .receiptDescription
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(2)
                }
            }

            Spacer()

            Text(
                record.price,
                format: .currency(
                    code: "NOK"
                )
            )
            .font(
                .subheadline.bold()
            )
            .foregroundStyle(
                PantryTheme.forest
            )

            Menu {
                Button {
                    editingRecord =
                        record
                } label: {
                    Label(
                        "Modifica",
                        systemImage:
                            "pencil"
                    )
                }

                Button(
                    role: .destructive
                ) {
                    recordToDelete =
                        record
                } label: {
                    Label(
                        "Elimina",
                        systemImage:
                            "trash"
                    )
                }
            } label: {
                Image(
                    systemName:
                        "ellipsis"
                )
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 30,
                    height: 30
                )
                .background(
                    PantryTheme.background,
                    in: Circle()
                )
            }
        }
        .padding(12)
        .background(
            PantryTheme.background,
            in: RoundedRectangle(
                cornerRadius: 15
            )
        )
    }

    private func delete(
        _ record: PriceRecord
    ) {
        modelContext.delete(record)

        do {
            try modelContext.save()
        } catch {
            errorMessage =
                "Non sono riuscito a eliminare il prezzo."

            print(
                "Errore eliminazione prezzo:",
                error
            )
        }
    }
}

// MARK: - Modifica prodotto

private struct EditCatalogProductView:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    let product: Product

    @State private var name:
        String

    @State private var brand:
        String

    @State private var packageQuantity:
        String

    @State private var errorMessage:
        String?

    init(product: Product) {
        self.product = product

        _name = State(
            initialValue:
                product.name
        )

        _brand = State(
            initialValue:
                product.brand
        )

        _packageQuantity = State(
            initialValue:
                product.packageQuantity
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        PBProductImage(
                            imageURL:
                                product.imageURL,
                            size: 110
                        )

                        VStack(spacing: 14) {
                            PBTextField(
                                title: "Nome",
                                placeholder:
                                    "Nome prodotto",
                                text: $name
                            )

                            PBTextField(
                                title: "Marca",
                                placeholder:
                                    "Facoltativa",
                                text: $brand
                            )

                            PBTextField(
                                title:
                                    "Quantità confezione",
                                placeholder:
                                    "Es. 500 g",
                                text:
                                    $packageQuantity
                            )
                        }
                        .padding(16)
                        .background(
                            PantryTheme.card,
                            in:
                                RoundedRectangle(
                                    cornerRadius:
                                        22
                                )
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        PBPrimaryButton(
                            title:
                                "Salva modifiche",
                            systemImage:
                                "checkmark.circle.fill",
                            disabled:
                                name
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                                .isEmpty
                        ) {
                            save()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(
                "Modifica prodotto"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
        .tint(PantryTheme.forest)
    }

    private func save() {
        let cleanName =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
        }

        product.name = cleanName

        product.brand =
            brand.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        product.packageQuantity =
            packageQuantity
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage =
                "Non sono riuscito a modificare il prodotto."
        }
    }
}

// MARK: - Modifica prezzo

private struct EditPriceRecordView:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    let record: PriceRecord

    @State private var storeName:
        String

    @State private var priceText:
        String

    @State private var purchaseDate:
        Date

    @State private var errorMessage:
        String?

    init(record: PriceRecord) {
        self.record = record

        _storeName = State(
            initialValue:
                record.storeName
        )

        _priceText = State(
            initialValue:
                String(
                    format: "%.2f",
                    record.price
                )
        )

        _purchaseDate = State(
            initialValue:
                record.purchaseDate
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(
                            alignment: .leading,
                            spacing: 14
                        ) {
                            PBTextField(
                                title:
                                    "Supermercato",
                                placeholder:
                                    "Nome supermercato",
                                text:
                                    $storeName
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 7
                            ) {
                                Text("Prezzo")
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )

                                HStack {
                                    TextField(
                                        "0,00",
                                        text:
                                            $priceText
                                    )
                                    .keyboardType(
                                        .decimalPad
                                    )

                                    Text("NOK")
                                        .font(
                                            .subheadline
                                            .bold()
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                }
                                .padding(
                                    .horizontal,
                                    14
                                )
                                .frame(
                                    height: 48
                                )
                                .background(
                                    PantryTheme
                                        .background,
                                    in:
                                        RoundedRectangle(
                                            cornerRadius:
                                                14
                                        )
                                )
                            }

                            DatePicker(
                                "Data acquisto",
                                selection:
                                    $purchaseDate,
                                displayedComponents:
                                    .date
                            )
                        }
                        .padding(16)
                        .background(
                            PantryTheme.card,
                            in:
                                RoundedRectangle(
                                    cornerRadius:
                                        22
                                )
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        PBPrimaryButton(
                            title:
                                "Salva modifiche",
                            systemImage:
                                "checkmark.circle.fill"
                        ) {
                            save()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(
                "Modifica prezzo"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
        .tint(PantryTheme.forest)
    }

    private func save() {
        let cleanStore =
            storeName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let normalizedPrice =
            priceText
            .replacingOccurrences(
                of: " ",
                with: ""
            )
            .replacingOccurrences(
                of: ",",
                with: "."
            )

        guard !cleanStore.isEmpty else {
            errorMessage =
                "Inserisci il supermercato."

            return
        }

        guard
            let price =
                Double(normalizedPrice),
            price >= 0
        else {
            errorMessage =
                "Inserisci un prezzo valido."

            return
        }

        record.storeName =
            StoreNameNormalizer
            .canonicalName(
                cleanStore
            )

        record.price = price

        record.purchaseDate =
            purchaseDate

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage =
                "Non sono riuscito a salvare le modifiche."
        }
    }
}

// MARK: - Aggiungi prezzo

private struct AddManualPriceView:
    View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort:
            \PriceRecord.purchaseDate,
        order: .reverse
    )
    private var allPriceRecords:
        [PriceRecord]

    let product: Product

    @State private var storeName =
        ""

    @State private var priceText =
        ""

    @State private var purchaseDate =
        Date()

    @State private var note =
        ""

    @State private var errorMessage:
        String?

    private var storeSuggestions:
        [String] {

        StoreNameNormalizer
            .suggestions(
                existingNames:
                    allPriceRecords
                    .map(\.storeName)
            )
    }

    private var canonicalPreview:
        String? {

        let cleaned =
            storeName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return nil
        }

        let canonical =
            StoreNameNormalizer
            .canonicalName(cleaned)

        return canonical == cleaned
        ? nil
        : canonical
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PantryTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        productHeader

                        formCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        PBPrimaryButton(
                            title:
                                "Salva prezzo",
                            systemImage:
                                "checkmark.circle.fill",
                            disabled:
                                !canSave
                        ) {
                            save()
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(
                    .interactively
                )
            }
            .navigationTitle(
                "Aggiungi prezzo"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
        .tint(PantryTheme.forest)
    }

    private var productHeader:
        some View {

        HStack(spacing: 12) {
            PBProductImage(
                imageURL:
                    product.imageURL,
                size: 66
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

                let details = [
                    product.brand,
                    product.packageQuantity
                ]
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: " · "
                )

                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private var formCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            PBTextField(
                title: "Supermercato",
                placeholder:
                    "Es. Coop Extra",
                text: $storeName
            )

            if let canonicalPreview {
                Label(
                    "Verrà salvato come \(canonicalPreview)",
                    systemImage:
                        "wand.and.stars"
                )
                .font(.caption)
                .foregroundStyle(
                    PantryTheme.forest
                )
            }

            Text("Scelte rapide")
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 8) {
                    ForEach(
                        storeSuggestions,
                        id: \.self
                    ) { store in
                        Button {
                            storeName =
                                store
                        } label: {
                            Text(store)
                                .font(
                                    .caption
                                    .weight(
                                        .semibold
                                    )
                                )
                                .foregroundStyle(
                                    isSelected(
                                        store
                                    )
                                    ? PantryTheme
                                        .cream
                                    : PantryTheme
                                        .forest
                                )
                                .padding(
                                    .horizontal,
                                    12
                                )
                                .frame(height: 34)
                                .background(
                                    isSelected(
                                        store
                                    )
                                    ? AnyShapeStyle(
                                        PantryTheme
                                        .primaryGradient
                                    )
                                    : AnyShapeStyle(
                                        PantryTheme
                                        .forest
                                        .opacity(
                                            0.09
                                        )
                                    ),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text("Prezzo")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                HStack {
                    TextField(
                        "0,00",
                        text: $priceText
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    .font(
                        .headline
                        .monospacedDigit()
                    )

                    Text("NOK")
                        .font(
                            .subheadline
                            .bold()
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
                .padding(
                    .horizontal,
                    14
                )
                .frame(height: 48)
                .background(
                    PantryTheme.background,
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            }

            DatePicker(
                "Data acquisto",
                selection:
                    $purchaseDate,
                displayedComponents:
                    .date
            )

            PBTextField(
                title: "Nota",
                placeholder:
                    "Facoltativa, es. offerta",
                text: $note
            )
        }
        .padding(16)
        .background(
            PantryTheme.card,
            in: RoundedRectangle(
                cornerRadius: 22
            )
        )
    }

    private func isSelected(
        _ store: String
    ) -> Bool {
        StoreNameNormalizer
            .groupingKey(
                storeName
            )
        ==
        StoreNameNormalizer
            .groupingKey(
                store
            )
    }

    private var parsedPrice:
        Double? {

        let normalized =
            priceText
            .replacingOccurrences(
                of: " ",
                with: ""
            )
            .replacingOccurrences(
                of: ",",
                with: "."
            )

        guard
            let value =
                Double(normalized),
            value >= 0
        else {
            return nil
        }

        return value
    }

    private var canSave: Bool {
        !storeName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        &&
        parsedPrice != nil
    }

    private func save() {
        let cleanedStore =
            storeName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanedStore.isEmpty else {
            errorMessage =
                "Inserisci il supermercato."

            return
        }

        guard
            let price = parsedPrice
        else {
            errorMessage =
                "Inserisci un prezzo valido."

            return
        }

        let cleanedNote =
            note
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let record = PriceRecord(
            productBarcode:
                product.barcode,
            storeName:
                StoreNameNormalizer
                .canonicalName(
                    cleanedStore
                ),
            receiptDescription:
                cleanedNote.isEmpty
                ? "Inserimento manuale"
                : cleanedNote,
            price: price,
            purchaseDate:
                purchaseDate
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage =
                "Non sono riuscito a salvare il prezzo."
        }
    }
}

private struct PriceStoreGroup:
    Identifiable {

    let id: String
    let storeName: String
    let latest: Double
    let minimum: Double
    let maximum: Double
    let records: [PriceRecord]
}
