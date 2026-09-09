import SwiftData
import SwiftUI

struct ReceiptMatchingView: View {

  @Environment(\.modelContext)
  private var modelContext

  @Environment(\.dismiss)
  private var dismiss

  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass

  @Query(sort: \Product.name)
  private var products: [Product]

  @Query(sort: \PriceRecord.purchaseDate, order: .reverse)
  private var existingPriceRecords: [PriceRecord]

  let result: ReceiptOCRResult
  let onSaved: () -> Void

  @State private var storeName: String
  @State private var usesSpecificDate: Bool
  @State private var purchaseDate: Date
  @State private var items: [EditableReceiptItem]

  @State private var isPreparing = true
  @State private var didPrepare = false
  @State private var savedSuccessfully = false
  @State private var savedRecordCount = 0
  @State private var saveErrorMessage: String?
  @State private var isSaving = false
  @State private var showDuplicateWarning = false
  @State private var pendingPurchaseDate: Date?

  init(
    result: ReceiptOCRResult,
    onSaved: @escaping () -> Void = {}
  ) {
    self.result = result
    self.onSaved = onSaved

    let initialItems = result.items
      .filter {
        !Self.shouldIgnoreAutomatically(
          $0.description
        )
      }
      .map {
        EditableReceiptItem(
          id: $0.id,
          originalDescription: $0.description,
          description: $0.description,
          priceText: Self.priceText(
            for: $0.price
          ),
          destination: .catalog
        )
      }

    _storeName = State(
      initialValue:
        result.storeName
        ?? "Negozio sconosciuto"
    )

    _usesSpecificDate = State(
      initialValue:
        result.purchaseDate != nil
    )

    _purchaseDate = State(
      initialValue:
        result.purchaseDate
        ?? Date()
    )

    _items = State(
      initialValue: initialItems
    )
  }

  var body: some View {
    NavigationStack {
      ZStack {
        PantryTheme.background
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 16) {
            purchaseInformationCard

            if isPreparing {
              HStack(spacing: 10) {
                ProgressView()
                  .tint(PantryTheme.forest)

                Text(
                  "Cerco associazioni conosciute…"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
              }
              .padding(16)
              .background(
                PantryTheme.card,
                in: RoundedRectangle(
                  cornerRadius: 18
                )
              )
            }

            if items.isEmpty {
              emptyState
            } else {
              VStack(
                alignment: .leading,
                spacing: 6
              ) {
                Text("Prodotti")
                  .font(.title3.bold())
                  .foregroundStyle(
                    PantryTheme.ink
                  )

                Text(
                  "Controlla i dati e scegli dove salvare ogni riga."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
              }
              .frame(
                maxWidth: .infinity,
                alignment: .leading
              )
              .padding(.top, 2)

              ForEach($items) { $item in
                receiptItemCard(
                  item: $item
                )
              }

              PBPrimaryButton(
                title: saveButtonTitle,
                systemImage: isSaving
                  ? "hourglass"
                  : "checkmark.circle.fill",
                disabled: !canSave
              ) {
                attemptSavePrices()
              }
              .padding(.top, 4)
            }
          }
          .frame(maxWidth: 760)
          .frame(maxWidth: .infinity)
          .padding(
            .horizontal,
            horizontalSizeClass == .regular
              ? 28
              : 16
          )
          .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(
          .interactively
        )
      }
      .navigationTitle(
        "Controlla prezzi"
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
          placement: .topBarLeading
        ) {
          Button("Annulla") {
            dismiss()
          }
          .foregroundStyle(
            PantryTheme.forest
          )
        }
      }
      .task {
        prepareMatchesIfNeeded()
      }
      .interactiveDismissDisabled(
        isSaving
      )
      .alert(
        "Possibile doppio salvataggio",
        isPresented: $showDuplicateWarning
      ) {
        Button(
          "Annulla",
          role: .cancel
        ) {
          pendingPurchaseDate = nil
        }

        Button("Salva comunque") {
          let date =
            pendingPurchaseDate
            ?? Date()

          pendingPurchaseDate = nil

          savePrices(
            effectivePurchaseDate: date
          )
        }
      } message: {
        Text(
          "Nel catalogo risultano già gli stessi prodotti, prezzi, supermercato e data. Potrebbe essere lo stesso scontrino."
        )
      }
      .alert(
        "Prezzi salvati",
        isPresented: $savedSuccessfully
      ) {
        Button("Fine") {
          dismiss()
          onSaved()
        }
      } message: {
        Text(successMessage)
      }
      .alert(
        "Salvataggio non riuscito",
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
    .tint(PantryTheme.forest)
  }

  // MARK: - Purchase information

  private var purchaseInformationCard:
    some View
  {
    VStack(
      alignment: .leading,
      spacing: 16
    ) {
      Label(
        "Informazioni acquisto",
        systemImage: "bag.fill"
      )
      .font(.headline)
      .foregroundStyle(
        PantryTheme.ink
      )

      PBTextField(
        title: "Supermercato",
        placeholder:
          "Nome del supermercato",
        text: $storeName
      )

      Divider()

      Toggle(
        "Imposta una data specifica",
        isOn: $usesSpecificDate
      )
      .font(
        .subheadline.weight(
          .semibold
        )
      )
      .tint(PantryTheme.leaf)

      if usesSpecificDate {
        DatePicker(
          "Data acquisto",
          selection: $purchaseDate,
          displayedComponents: .date
        )
        .font(.subheadline)

        Text(dateHelpText)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text(
          "Quando salvi verrà usata la data e l’ora di quel momento."
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
        PantryTheme.forest.opacity(
          0.08
        ),
        lineWidth: 1
      )
    }
  }

  private var dateHelpText: String {
    if result.purchaseDate != nil {
      return
        "Questa data è stata rilevata dallo scontrino. Puoi correggerla."
    }

    return
      "Hai scelto manualmente la data dell’acquisto."
  }

  // MARK: - Receipt item

  private func receiptItemCard(
    item: Binding<EditableReceiptItem>
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: 14
    ) {
      ViewThatFits(in: .horizontal) {
        HStack(
          alignment: .firstTextBaseline,
          spacing: 12
        ) {
          receiptDescriptionField(
            item
          )

          receiptPriceField(
            item
          )
        }

        VStack(
          alignment: .leading,
          spacing: 12
        ) {
          receiptDescriptionField(
            item
          )

          receiptPriceField(
            item
          )
        }
      }

      Divider()

      HStack(spacing: 12) {
        destinationIcon(
          for:
            item.wrappedValue
            .destination
        )

        VStack(
          alignment: .leading,
          spacing: 2
        ) {
          Text("Salva come")
            .font(.caption)
            .foregroundStyle(.secondary)

          Picker(
            "Destinazione",
            selection: item.destination
          ) {
            Text(
              "Nuovo nel catalogo"
            )
            .tag(
              ReceiptItemDestination
                .catalog
            )

            Text(
              "Ignora questa riga"
            )
            .tag(
              ReceiptItemDestination
                .ignore
            )

            if !products.isEmpty {
              Section(
                "Prodotti esistenti"
              ) {
                ForEach(products) {
                  product in

                  Text(
                    productLabel(
                      product
                    )
                  )
                  .tag(
                    ReceiptItemDestination
                      .product(
                        product.barcode
                      )
                  )
                }
              }
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .tint(PantryTheme.forest)
          .lineLimit(2)
        }

        Spacer()
      }

      destinationHelp(
        for:
          item.wrappedValue
          .destination
      )
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
        borderColor(
          for:
            item.wrappedValue
            .destination
        ),
        lineWidth: 1
      )
    }
  }

  private func receiptDescriptionField(
    _ item:
      Binding<EditableReceiptItem>
  ) -> some View {
    TextField(
      "Descrizione prodotto",
      text: item.description
    )
    .font(.headline)
    .textInputAutocapitalization(
      .characters
    )
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }

  private func receiptPriceField(
    _ item:
      Binding<EditableReceiptItem>
  ) -> some View {
    HStack(spacing: 5) {
      TextField(
        "0,00",
        text: item.priceText
      )
      .keyboardType(.decimalPad)
      .multilineTextAlignment(
        .trailing
      )
      .font(
        .headline.monospacedDigit()
      )
      .frame(
        minWidth: 72,
        maxWidth: 110
      )

      Text("NOK")
        .font(
          .caption.weight(
            .semibold
          )
        )
        .foregroundStyle(.secondary)
    }
    .fixedSize(
      horizontal: true,
      vertical: false
    )
  }

  private func destinationIcon(
    for destination:
      ReceiptItemDestination
  ) -> some View {
    let configuration =
      destinationConfiguration(
        for: destination
      )

    return Image(
      systemName:
        configuration.icon
    )
    .font(
      .system(
        size: 15,
        weight: .bold
      )
    )
    .foregroundStyle(
      configuration.color
    )
    .frame(
      width: 38,
      height: 38
    )
    .background(
      configuration.color.opacity(
        0.10
      ),
      in: RoundedRectangle(
        cornerRadius: 12
      )
    )
  }

  @ViewBuilder
  private func destinationHelp(
    for destination:
      ReceiptItemDestination
  ) -> some View {
    switch destination {
    case .catalog:
      Text(
        "Verrà creato nel catalogo prezzi, senza aggiungerlo alla dispensa."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

    case .ignore:
      Text(
        "Questa riga non verrà salvata."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

    case .product:
      Text(
        "Il prezzo verrà aggiunto allo storico del prodotto scelto."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(
        systemName:
          "doc.text.magnifyingglass"
      )
      .font(.system(size: 42))
      .foregroundStyle(
        PantryTheme.forest.opacity(
          0.55
        )
      )

      Text(
        "Nessun prodotto da salvare"
      )
      .font(.headline)

      Text(
        "Le righe non acquistabili, come PANT, vengono escluse automaticamente."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(
        .center
      )
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 42)
    .padding(.horizontal, 24)
    .background(
      PantryTheme.card,
      in: RoundedRectangle(
        cornerRadius: 22
      )
    )
  }

  // MARK: - Automatic matching

  @MainActor
  private func prepareMatchesIfNeeded() {
    guard !didPrepare else {
      return
    }

    didPrepare = true
    isPreparing = true

    for index in items.indices {
      let receiptText =
        items[index]
        .originalDescription

      if let barcode =
        findExistingAlias(
          for: receiptText
        ),
        products.contains(
          where: {
            $0.barcode == barcode
          }
        )
      {
        items[index].destination =
          .product(barcode)

        continue
      }

      if let exactProduct =
        exactProductMatch(
          for: receiptText
        )
      {
        items[index].destination =
          .product(
            exactProduct.barcode
          )

        continue
      }

      if let suggestion =
        bestLocalSuggestion(
          for: receiptText
        )
      {
        items[index].destination =
          .product(
            suggestion.barcode
          )
      }
    }

    isPreparing = false
  }

  private func findExistingAlias(
    for receiptText: String
  ) -> String? {
    let normalizedStore =
      normalize(storeName)

    let normalizedReceipt =
      normalize(receiptText)

    let descriptor =
      FetchDescriptor<ReceiptAlias>()

    guard
      let aliases =
        try? modelContext.fetch(
          descriptor
        )
    else {
      return nil
    }

    return aliases.first {
      normalize($0.storeName)
        == normalizedStore
        && normalize($0.receiptText)
          == normalizedReceipt
    }?.productBarcode
  }

  private func exactProductMatch(
    for receiptText: String
  ) -> Product? {
    let normalizedReceipt =
      normalize(receiptText)

    return products.first {
      normalize($0.name)
        == normalizedReceipt
    }
  }

  private func bestLocalSuggestion(
    for receiptText: String
  ) -> Product? {
    let receiptWords =
      words(from: receiptText)

    guard !receiptWords.isEmpty else {
      return nil
    }

    var bestProduct: Product?
    var bestScore = 0.0

    for product in products {
      let productText = [
        product.name,
        product.brand,
        product.packageQuantity,
      ]
      .joined(separator: " ")

      let productWords =
        words(from: productText)

      guard !productWords.isEmpty else {
        continue
      }

      let sharedWords =
        receiptWords.intersection(
          productWords
        )

      let score =
        Double(sharedWords.count)
        / Double(
          max(
            receiptWords.count,
            1
          )
        )

      if score > bestScore {
        bestScore = score
        bestProduct = product
      }
    }

    // Meglio creare un elemento da unire in seguito che scegliere
    // automaticamente il prodotto sbagliato.
    guard bestScore >= 0.60 else {
      return nil
    }

    return bestProduct
  }

  // MARK: - Save

  private func attemptSavePrices() {
    guard canSave else {
      return
    }

    let effectivePurchaseDate =
      usesSpecificDate
      ? purchaseDate
      : Date()

    if looksLikePreviouslySavedReceipt(
      effectivePurchaseDate:
        effectivePurchaseDate
    ) {
      pendingPurchaseDate =
        effectivePurchaseDate

      showDuplicateWarning = true
      return
    }

    savePrices(
      effectivePurchaseDate:
        effectivePurchaseDate
    )
  }

  private func savePrices(
    effectivePurchaseDate: Date
  ) {
    guard canSave else {
      return
    }

    isSaving = true

    defer {
      isSaving = false
    }

    let cleanStoreName =
      storeName.trimmingCharacters(
        in: .whitespacesAndNewlines
      )

    let effectiveStoreName =
      cleanStoreName.isEmpty
      ? "Negozio sconosciuto"
      : cleanStoreName

    var insertedRecords = 0

    var newlyCreatedProducts:
      [String: Product] = [:]

    for item in items {
      guard
        item.destination != .ignore,
        let price = parsedPrice(
          item.priceText
        )
      else {
        continue
      }

      let cleanDescription =
        item.description
        .trimmingCharacters(
          in:
            .whitespacesAndNewlines
        )

      guard !cleanDescription.isEmpty
      else {
        continue
      }

      let barcode: String

      switch item.destination {
      case .ignore:
        continue

      case .product(
        let existingBarcode
      ):
        barcode = existingBarcode

      case .catalog:
        let normalizedName =
          normalize(
            cleanDescription
          )

        if let existingProduct =
          products.first(
            where: {
              normalize($0.name)
                == normalizedName
            }
          )
        {
          barcode =
            existingProduct.barcode

        } else if let newProduct =
          newlyCreatedProducts[
            normalizedName
          ]
        {
          barcode =
            newProduct.barcode

        } else {
          let newProduct =
            makeCatalogProduct(
              named:
                cleanDescription
            )

          newlyCreatedProducts[
            normalizedName
          ] = newProduct

          barcode =
            newProduct.barcode
        }
      }

      saveAlias(
        storeName:
          effectiveStoreName,
        receiptText:
          item.originalDescription,
        barcode: barcode
      )

      let priceRecord =
        PriceRecord(
          productBarcode: barcode,
          storeName:
            effectiveStoreName,
          receiptDescription:
            cleanDescription,
          price: price,
          purchaseDate:
            effectivePurchaseDate
        )

      // Ogni acquisto genera sempre un nuovo PriceRecord.
      modelContext.insert(
        priceRecord
      )

      insertedRecords += 1
    }

    guard insertedRecords > 0 else {
      saveErrorMessage =
        "Controlla che almeno una riga abbia descrizione e prezzo validi."

      return
    }

    do {
      try modelContext.save()

      savedRecordCount =
        insertedRecords

      savedSuccessfully = true
    } catch {
      modelContext.rollback()

      saveErrorMessage =
        "Non sono riuscito a salvare i prezzi. Riprova."

      print(
        "Errore salvataggio scontrino:",
        error
      )
    }
  }

  private func
    looksLikePreviouslySavedReceipt(
      effectivePurchaseDate: Date
    ) -> Bool
  {
    let candidates =
      items.compactMap {
        item
          -> ReceiptSaveCandidate?
        in

        guard
          item.destination != .ignore,
          let price = parsedPrice(
            item.priceText
          )
        else {
          return nil
        }

        let description =
          item.description
          .trimmingCharacters(
            in:
              .whitespacesAndNewlines
          )

        guard !description.isEmpty else {
          return nil
        }

        return ReceiptSaveCandidate(
          descriptionKey:
            normalize(description),
          priceInCents:
            Int(
              (price * 100)
                .rounded()
            )
        )
      }

    guard !candidates.isEmpty else {
      return false
    }

    let cleanStoreName =
      storeName.trimmingCharacters(
        in: .whitespacesAndNewlines
      )

    let storeKey =
      normalize(
        cleanStoreName.isEmpty
          ? "Negozio sconosciuto"
          : cleanStoreName
      )

    let matchingRecords =
      existingPriceRecords.filter {
        record in

        guard
          normalize(record.storeName)
            == storeKey
        else {
          return false
        }

        if usesSpecificDate {
          return Calendar.current
            .isDate(
              record.purchaseDate,
              inSameDayAs:
                effectivePurchaseDate
            )
        }

        return abs(
          record.purchaseDate
            .timeIntervalSince(
              effectivePurchaseDate
            )
        ) <= 15 * 60
      }

    guard
      matchingRecords.count
        >= candidates.count
    else {
      return false
    }

    var availableCounts:
      [ReceiptSaveCandidate: Int] =
        [:]

    for record in matchingRecords {
      let key =
        ReceiptSaveCandidate(
          descriptionKey:
            normalize(
              record
                .receiptDescription
            ),
          priceInCents:
            Int(
              (record.price * 100)
                .rounded()
            )
        )

      availableCounts[
        key,
        default: 0
      ] += 1
    }

    for candidate in candidates {
      guard
        let count =
          availableCounts[
            candidate
          ],
        count > 0
      else {
        return false
      }

      availableCounts[
        candidate
      ] = count - 1
    }

    return true
  }

  private func makeCatalogProduct(
    named name: String
  ) -> Product {
    let product =
      Product(
        barcode:
          "catalog-\(UUID().uuidString)",
        name: name,
        brand: "",
        packageQuantity: "",
        imageURL: nil,
        inventoryQuantity: 0,
        storageLocation:
          "Solo catalogo"
      )

    modelContext.insert(product)

    return product
  }

  private func saveAlias(
    storeName: String,
    receiptText: String,
    barcode: String
  ) {
    let normalizedStore =
      normalize(storeName)

    let normalizedReceipt =
      normalize(receiptText)

    let descriptor =
      FetchDescriptor<ReceiptAlias>()

    if let aliases =
      try? modelContext.fetch(
        descriptor
      ),
      let existingAlias =
        aliases.first(
          where: {
            normalize(
              $0.storeName
            ) == normalizedStore
              && normalize(
                $0.receiptText
              ) == normalizedReceipt
          }
        )
    {
      existingAlias
        .productBarcode =
        barcode

      existingAlias
        .lastSeenAt =
        Date()

      return
    }

    let alias =
      ReceiptAlias(
        storeName: storeName,
        receiptText: receiptText,
        productBarcode: barcode
      )

    modelContext.insert(alias)
  }

  // MARK: - Validation and formatting

  private var canSave: Bool {
    guard
      !isSaving,
      !savedSuccessfully
    else {
      return false
    }

    let rowsToSave =
      items.filter {
        $0.destination != .ignore
      }

    guard !rowsToSave.isEmpty else {
      return false
    }

    return rowsToSave.allSatisfy {
      !$0.description
        .trimmingCharacters(
          in:
            .whitespacesAndNewlines
        )
        .isEmpty
        && parsedPrice(
          $0.priceText
        ) != nil
    }
  }

  private var saveButtonTitle: String {
    if isSaving {
      return "Salvataggio…"
    }

    let count =
      items.filter {
        $0.destination != .ignore
      }
      .count

    return count == 1
      ? "Salva 1 prezzo"
      : "Salva \(count) prezzi"
  }

  private var successMessage: String {
    if savedRecordCount == 1 {
      return
        "Il prezzo è stato aggiunto al catalogo."
    }

    return
      "Sono stati aggiunti \(savedRecordCount) prezzi al catalogo."
  }

  private func parsedPrice(
    _ text: String
  ) -> Double? {
    let normalized =
      text
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

  private func productLabel(
    _ product: Product
  ) -> String {
    var components = [
      product.name
    ]

    if !product
      .packageQuantity
      .isEmpty
    {
      components.append(
        product.packageQuantity
      )
    }

    components.append(
      product.inventoryQuantity > 0
        ? "in dispensa"
        : "catalogo"
    )

    return components.joined(
      separator: " · "
    )
  }

  private func
    destinationConfiguration(
      for destination:
        ReceiptItemDestination
    )
    -> (
      icon: String,
      color: Color
    )
  {
    switch destination {
    case .catalog:
      return (
        "tag.fill",
        PantryTheme.gold
      )

    case .ignore:
      return (
        "minus.circle.fill",
        .secondary
      )

    case .product:
      return (
        "checkmark.circle.fill",
        PantryTheme.forest
      )
    }
  }

  private func borderColor(
    for destination:
      ReceiptItemDestination
  ) -> Color {
    switch destination {
    case .catalog:
      return
        PantryTheme.gold.opacity(
          0.18
        )

    case .ignore:
      return
        Color.secondary.opacity(
          0.12
        )

    case .product:
      return
        PantryTheme.forest.opacity(
          0.16
        )
    }
  }

  private func normalize(
    _ text: String
  ) -> String {
    text
      .uppercased()
      .folding(
        options:
          .diacriticInsensitive,
        locale: .current
      )
      .replacingOccurrences(
        of: #"[^A-Z0-9ÆØÅ]+"#,
        with: " ",
        options: .regularExpression
      )
      .split(separator: " ")
      .joined(separator: " ")
  }

  private func words(
    from text: String
  ) -> Set<String> {
    Set(
      normalize(text)
        .split(separator: " ")
        .map(String.init)
        .filter {
          $0.count >= 2
        }
    )
  }

  private static func
    shouldIgnoreAutomatically(
      _ description: String
    ) -> Bool
  {
    let normalized =
      description
      .uppercased()
      .trimmingCharacters(
        in:
          .whitespacesAndNewlines
      )

    return normalized == "PANT"
      || normalized.hasPrefix(
        "PANT "
      )
  }

  private static func priceText(
    for price: Double
  ) -> String {
    String(
      format: "%.2f",
      price
    )
    .replacingOccurrences(
      of: ".",
      with: ","
    )
  }
}

private struct EditableReceiptItem:
  Identifiable
{
  let id: UUID
  let originalDescription: String

  var description: String
  var priceText: String

  var destination:
    ReceiptItemDestination
}

private enum ReceiptItemDestination:
  Hashable
{
  case catalog
  case ignore
  case product(String)
}

private struct ReceiptSaveCandidate:
  Hashable
{
  let descriptionKey: String
  let priceInCents: Int
}
