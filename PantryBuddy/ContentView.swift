import SwiftData
import SwiftUI

struct ContentView: View {

  @Environment(\.modelContext)
  private var modelContext

  @Environment(\.horizontalSizeClass)
  private var horizontalSizeClass

  @Environment(\.dynamicTypeSize)
  private var dynamicTypeSize

  @ScaledMetric(relativeTo: .title)
  private var appIconSize: CGFloat = 68

  @State private var showBarcodeScanner = false
  @State private var showReceiptScanner = false
  @State private var showSettings = false

  @State private var showProductDetail = false
  @State private var product: OpenFoodFactsProduct?

  @State private var showManualEntry = false
  @State private var showKnownProduct = false
  @State private var knownProduct: Product?

  @State private var scannedCode: String?
  @State private var isLoading = false
  @State private var searchFailure: ProductLookupFailure?

  var body: some View {
    NavigationStack {
      ZStack {
        PantryTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(spacing: 16) {
            homeHeader
              .padding(.bottom, 12)

            actionLayout

            if isLoading {
              loadingCard
            }

            if let searchFailure {
              productLookupErrorCard(searchFailure)
            }
          }
          .frame(maxWidth: 820)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, horizontalPadding)
          .padding(.top, 16)
          .padding(.bottom, 34)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .fullScreenCover(isPresented: $showBarcodeScanner) {
        BarcodeScannerView { code in
          scannedCode = code
          showBarcodeScanner = false

          Task {
            await handleScannedBarcode(
              barcode: code
            )
          }
        }
      }
      .sheet(isPresented: $showReceiptScanner) {
        ReceiptScannerView()
      }
      .sheet(isPresented: $showSettings) {
        SettingsView()
      }
      .sheet(
        isPresented: $showProductDetail,
        onDismiss: resetSearchState
      ) {
        if let product,
          let scannedCode
        {
          ProductDetailView(
            barcode: scannedCode,
            product: product
          )
        }
      }
      .sheet(
        isPresented: $showManualEntry,
        onDismiss: resetSearchState
      ) {
        if let scannedCode {
          ManualProductEntryView(
            barcode: scannedCode
          )
        }
      }
      .sheet(
        isPresented: $showKnownProduct,
        onDismiss: resetSearchState
      ) {
        if let knownProduct {
          KnownProductView(
            product: knownProduct
          )
        }
      }
    }
    .tint(PantryTheme.forest)
  }

  // MARK: - Header

  private var horizontalPadding: CGFloat {
    horizontalSizeClass == .regular ? 28 : 16
  }

  private var usesTwoColumns: Bool {
    horizontalSizeClass == .regular
      && !dynamicTypeSize.isAccessibilitySize
  }

  private var homeHeader: some View {
    HStack(spacing: 12) {
      Image("PantryBuddyIcon")
        .resizable()
        .scaledToFit()
        .frame(
          width: min(appIconSize, 72),
          height: min(appIconSize, 72)
        )
        .clipShape(
          RoundedRectangle(cornerRadius: 18)
        )
        .shadow(
          color: PantryTheme.forest.opacity(0.14),
          radius: 10,
          y: 5
        )

      VStack(alignment: .leading, spacing: 3) {
        Text("PantryBuddy")
          .font(.title.bold())
          .foregroundStyle(PantryTheme.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.65)
          .allowsTightening(true)

        Text("La tua dispensa digitale")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .allowsTightening(true)
      }
      .layoutPriority(1)

      Spacer(minLength: 0)

      Button {
        showSettings = true
      } label: {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(PantryTheme.forest)
          .frame(width: 44, height: 44)
          .background(
            PantryTheme.card,
            in: Circle()
          )
          .overlay {
            Circle()
              .stroke(
                PantryTheme.forest.opacity(0.10),
                lineWidth: 1
              )
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Impostazioni")
    }
  }

  // MARK: - Actions

  @ViewBuilder
  private var actionLayout: some View {
    if usesTwoColumns {
      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 16),
          GridItem(.flexible(), spacing: 16),
        ],
        alignment: .leading,
        spacing: 16
      ) {
        scanProductButton
        scanReceiptButton
        pantryButton
        priceCatalogButton
      }
    } else {
      VStack(spacing: 16) {
        scanProductButton
        scanReceiptButton
        pantryButton
        priceCatalogButton
      }
    }
  }

  private var scanProductButton: some View {
    Button {
      resetSearchState()
      showBarcodeScanner = true
    } label: {
      HomeActionLabel(
        title: "Scansiona prodotto",
        subtitle: nil,
        systemImage: "barcode.viewfinder",
        accent: PantryTheme.cream,
        primary: true
      )
    }
    .buttonStyle(.plain)
  }

  private var scanReceiptButton: some View {
    Button {
      showReceiptScanner = true
    } label: {
      HomeActionLabel(
        title: "Scansiona scontrino",
        subtitle: "Salva prodotti e prezzi",
        systemImage: "doc.text.viewfinder",
        accent: PantryTheme.forest
      )
    }
    .buttonStyle(.plain)
  }

  private var pantryButton: some View {
    NavigationLink {
      PantryView()
    } label: {
      HomeActionLabel(
        title: "La mia dispensa",
        subtitle: "I prodotti che hai in casa",
        systemImage: "cabinet.fill",
        accent: PantryTheme.forest
      )
    }
    .buttonStyle(.plain)
  }

  private var priceCatalogButton: some View {
    NavigationLink {
      PriceCatalogView()
    } label: {
      HomeActionLabel(
        title: "Catalogo prezzi",
        subtitle: "Storico e confronto negozi",
        systemImage: "tag.fill",
        accent: PantryTheme.gold
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Loading and error

  private var loadingCard: some View {
    HStack(spacing: 13) {
      ProgressView()
        .tint(PantryTheme.forest)

      Text("Cerco il prodotto…")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PantryTheme.ink)

      Spacer()
    }
    .padding(16)
    .background(
      PantryTheme.card,
      in: RoundedRectangle(cornerRadius: 20)
    )
  }

  private func productLookupErrorCard(
    _ failure: ProductLookupFailure
  ) -> some View {
    VStack(spacing: 13) {
      HStack {
        Spacer()

        Button {
          resetSearchState()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .background(
              PantryTheme.background,
              in: Circle()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Annulla")
      }

      Image(systemName: failure.systemImage)
        .font(.system(size: 42))
        .foregroundStyle(failure.color)

      Text(failure.title)
        .font(.headline)
        .foregroundStyle(PantryTheme.ink)
        .multilineTextAlignment(.center)

      Text(failure.message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if let scannedCode {
        Text("Barcode: \(scannedCode)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
      }

      if failure.canRetry,
        let scannedCode
      {
        Button {
          Task {
            await handleScannedBarcode(
              barcode: scannedCode
            )
          }
        } label: {
          Label(
            "Riprova",
            systemImage: "arrow.clockwise"
          )
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(PantryTheme.cream)
          .frame(maxWidth: .infinity)
          .frame(height: 46)
          .background(
            PantryTheme.primaryGradient,
            in: RoundedRectangle(cornerRadius: 15)
          )
        }
        .buttonStyle(.plain)
      }

      if failure.allowsManualEntry {
        Button {
          showManualEntry = true
        } label: {
          Text("Inserisci manualmente")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PantryTheme.forest)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
              PantryTheme.forest.opacity(0.09),
              in: RoundedRectangle(cornerRadius: 15)
            )
        }
        .buttonStyle(.plain)
      }

      if failure == .invalidBarcode {
        Button {
          resetSearchState()
          showBarcodeScanner = true
        } label: {
          Label(
            "Scansiona di nuovo",
            systemImage: "barcode.viewfinder"
          )
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(PantryTheme.forest)
        }
        .buttonStyle(.plain)
      }

      Button("Annulla") {
        resetSearchState()
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
    }
    .padding(18)
    .background(
      PantryTheme.card,
      in: RoundedRectangle(cornerRadius: 23)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 23)
        .stroke(
          PantryTheme.gold.opacity(0.14),
          lineWidth: 1
        )
    }
  }

  // MARK: - Barcode

  @MainActor
  private func handleScannedBarcode(
    barcode: String
  ) async {
    isLoading = true
    searchFailure = nil
    product = nil
    knownProduct = nil

    let scannedBarcode = barcode

    let descriptor = FetchDescriptor<Product>(
      predicate: #Predicate {
        $0.barcode == scannedBarcode
      }
    )

    do {
      let localProducts = try modelContext.fetch(
        descriptor
      )

      if let localProduct = localProducts.first {
        knownProduct = localProduct
        isLoading = false
        showKnownProduct = true
        return
      }
    } catch {
      print("Errore ricerca locale:", error)
    }

    do {
      let foundProduct =
        try await OpenFoodFactsService
        .fetchProduct(barcode: barcode)

      product = foundProduct
      isLoading = false
      showProductDetail = true
    } catch OpenFoodFactsError.productNotFound {
      isLoading = false
      searchFailure = .productNotFound
    } catch OpenFoodFactsError.invalidURL {
      isLoading = false
      searchFailure = .invalidBarcode
    } catch OpenFoodFactsError.noConnection {
      isLoading = false
      searchFailure = .noConnection
    } catch OpenFoodFactsError.serviceUnavailable {
      isLoading = false
      searchFailure = .serviceUnavailable
    } catch OpenFoodFactsError.invalidResponse {
      isLoading = false
      searchFailure = .serviceUnavailable
    } catch {
      isLoading = false
      searchFailure = .unknown
      print("Errore sconosciuto:", error)
    }
  }

  private func resetSearchState() {
    searchFailure = nil
    product = nil
    knownProduct = nil
    scannedCode = nil
    isLoading = false
  }
}

private enum ProductLookupFailure: Equatable {
  case productNotFound
  case invalidBarcode
  case noConnection
  case serviceUnavailable
  case unknown

  var title: String {
    switch self {
    case .productNotFound:
      return "Prodotto non riconosciuto"

    case .invalidBarcode:
      return "Codice a barre non valido"

    case .noConnection:
      return "Connessione assente"

    case .serviceUnavailable:
      return "Servizio non disponibile"

    case .unknown:
      return "Ricerca non riuscita"
    }
  }

  var message: String {
    switch self {
    case .productNotFound:
      return
        "Non ho trovato questo prodotto nel catalogo online. Puoi inserirlo manualmente."

    case .invalidBarcode:
      return
        "Il codice letto non sembra essere un barcode prodotto valido. Prova a scansionarlo di nuovo."

    case .noConnection:
      return
        "Controlla Wi-Fi o rete mobile, poi premi Riprova."

    case .serviceUnavailable:
      return
        "Open Food Facts non risponde in questo momento. I dati già salvati restano disponibili."

    case .unknown:
      return
        "Si è verificato un problema imprevisto. Puoi riprovare o inserire il prodotto manualmente."
    }
  }

  var systemImage: String {
    switch self {
    case .productNotFound:
      return "questionmark.circle.fill"

    case .invalidBarcode:
      return "barcode.viewfinder"

    case .noConnection:
      return "wifi.slash"

    case .serviceUnavailable:
      return "exclamationmark.icloud.fill"

    case .unknown:
      return "exclamationmark.triangle.fill"
    }
  }

  var color: Color {
    switch self {
    case .noConnection,
      .serviceUnavailable,
      .unknown:
      return PantryTheme.gold

    case .productNotFound,
      .invalidBarcode:
      return PantryTheme.forest
    }
  }

  var canRetry: Bool {
    switch self {
    case .noConnection,
      .serviceUnavailable,
      .unknown:
      return true

    case .productNotFound,
      .invalidBarcode:
      return false
    }
  }

  var allowsManualEntry: Bool {
    self != .invalidBarcode
  }
}

private struct HomeActionLabel: View {
  let title: String
  let subtitle: String?
  let systemImage: String
  let accent: Color

  var primary = false

  @ScaledMetric(relativeTo: .headline)
  private var iconBoxSize: CGFloat = 54

  var body: some View {
    HStack(spacing: 15) {
      Image(systemName: systemImage)
        .font(
          .system(
            size: 22,
            weight: .semibold
          )
        )
        .foregroundStyle(
          primary
            ? PantryTheme.cream
            : accent
        )
        .frame(
          width: min(iconBoxSize, 64),
          height: min(iconBoxSize, 64)
        )
        .background(
          primary
            ? AnyShapeStyle(
              Color.white.opacity(0.14)
            )
            : AnyShapeStyle(
              accent.opacity(0.10)
            ),
          in: RoundedRectangle(
            cornerRadius: 17
          )
        )

      VStack(
        alignment: .leading,
        spacing: 3
      ) {
        Text(title)
          .font(.headline)
          .foregroundStyle(
            primary
              ? PantryTheme.cream
              : PantryTheme.ink
          )
          .lineLimit(2)
          .minimumScaleFactor(0.80)
          .fixedSize(
            horizontal: false,
            vertical: true
          )

        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(
              primary
                ? PantryTheme.cream.opacity(0.80)
                : Color.secondary
            )
            .lineLimit(2)
            .fixedSize(
              horizontal: false,
              vertical: true
            )
        }
      }
      .layoutPriority(1)

      Spacer()

      Image(systemName: "chevron.right")
        .font(
          .system(
            size: 15,
            weight: .bold
          )
        )
        .foregroundStyle(
          primary
            ? PantryTheme.cream.opacity(0.80)
            : accent.opacity(0.65)
        )
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity)
    .frame(
      minHeight: primary
        ? 92
        : 82
    )
    .background {
      if primary {
        PantryTheme.primaryGradient
      } else {
        PantryTheme.card
      }
    }
    .clipShape(
      RoundedRectangle(
        cornerRadius: 24
      )
    )
    .overlay {
      RoundedRectangle(
        cornerRadius: 24
      )
      .stroke(
        primary
          ? Color.clear
          : accent.opacity(0.10),
        lineWidth: 1
      )
    }
    .shadow(
      color: primary
        ? PantryTheme.forest.opacity(0.14)
        : Color.clear,
      radius: 12,
      y: 6
    )
    .contentShape(
      RoundedRectangle(
        cornerRadius: 24
      )
    )
    .accessibilityElement(
      children: .combine
    )
  }
}
