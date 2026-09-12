# PantryBuddy

![Swift](https://img.shields.io/badge/Swift-6-orange)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Persistence](https://img.shields.io/badge/persistence-SwiftData-green)
![Status](https://img.shields.io/badge/status-active%20development-yellow)

**PantryBuddy** is a native iOS app for managing groceries, tracking expiration dates, comparing purchase prices, and keeping a shopping list.

It brings together **barcode scanning, on-device receipt OCR, flexible inventory tracking, product photos, and local expiration reminders**.

The app separates two different questions:

- **What do I have at home?** — the pantry.
- **What did I pay, and where?** — the price catalog.

Products can remain in the price catalog even when they are no longer in the pantry.

> PantryBuddy is a personal project under active development. The interface is currently primarily in Italian, and prices are displayed in Norwegian kroner (NOK).

## Features

### Pantry and Storage Locations

Organize products by where they are stored:

- Pantry
- Refrigerator
- Freezer
- All products

Each product can include its name, brand, package size, image, storage location, available quantity, and expiration date.

Removing a product from the pantry does not require deleting its catalog entry or purchase-price history.

### Package and Individual-Unit Tracking

Choose how to track each product:

- **Packages** for products managed as whole containers.
- **Individual units** for products such as eggs, wraps, or other countable items.

For example, a package containing six wraps can be tracked by the number of wraps remaining instead of simply showing one package.

The tracking mode is selected per product: counting every biscuit or slice is not required.

### Barcode Scanning

Scan product barcodes using the iPhone camera.

PantryBuddy retrieves available product information through **Open Food Facts**, reducing manual entry when a matching product is available.

When a product cannot be identified, users can enter its details manually or cancel the operation.

### Optional Product Photos

Add a personal photo when a product image is missing or needs replacing.

- Take a photo directly in the app.
- Retake or remove a manually added photo.
- Save a product without taking a photo.
- Store personal product photos locally.

Photography is optional and does not block product entry.

Remote product images are cached in memory and on disk, allowing cached images to be reused when switching between pantry sections.

### Expiration Dates and Reminders

Assign an optional expiration date to a product.

The app distinguishes between products that are:

- Expired
- Expiring today
- Expiring soon
- Not close to expiration

With notification permission, PantryBuddy can schedule local reminders three days before expiration and on the expiration date.

Reminders are refreshed when relevant product information changes and cancelled when a product is no longer in stock.

The current model stores one expiration date per product, rather than separate dates for individual packages or batches.

### Receipt Scanning and On-Device OCR

Photograph a supermarket receipt and extract its text locally using Apple's Vision framework.

The receipt workflow attempts to identify:

- Supermarket name
- Product descriptions
- Prices
- Purchase date

Users review the extracted information before saving.

When a purchase date is available from the receipt, it can be used or corrected. Otherwise, the app uses the date and time at which prices are saved.

Receipt images are not uploaded to an external AI service for OCR.

### Receipt Matching and Catalog-Only Products

Receipt descriptions often differ from the names returned by barcode lookups.

PantryBuddy supports reviewing product associations and remembering confirmed receipt aliases for future purchases.

Receipt items can also become catalog-only products without being added to the pantry. This allows old receipts to contribute to price history even when their products are no longer at home.

Save guards help prevent repeated taps from saving the same operation multiple times.

### Price Catalog

Browse a separate, searchable product-price catalog.

Search by:

- Product name
- Brand
- Barcode

Prices are grouped by supermarket. Each group shows:

- Latest recorded price
- Historical minimum
- Historical maximum
- Full saved price history with purchase dates

New price observations do not replace earlier ones.

Comparisons reflect recorded purchases, not live supermarket prices.

### Duplicate Review and Product Merging

Review possible duplicates, including entries created through different workflows such as receipt scanning and barcode scanning.

Users can:

- Confirm that entries represent the same product.
- Merge their associated price history and receipt aliases.
- Mark suggested pairs as different products.
- Preserve relevant product information when merging.

Duplicate suggestions are assistive: similar descriptions do not necessarily mean two products are identical.

Supermarket-name normalization also helps group variations of the same store name consistently.

### Shopping List

A dedicated shopping-list screen supports:

- Adding free-text items.
- Editing item names.
- Marking items as purchased.
- Separating pending and purchased items.
- Deleting individual entries.
- Clearing purchased items after confirmation.

The list is saved locally and remains available after reopening the app.

It is currently a manual list, without automatic stock-based suggestions or sharing between devices.

### Settings and Data Management

Manage the local archive through a dedicated settings screen.

Available tools include:

- Removing products from the pantry while retaining catalog information.
- Permanently deleting products and their associated records.
- Exporting a JSON backup.
- Importing a backup by merging or replacing the archive.
- Exporting price history as CSV.
- Checking and repairing archive inconsistencies.
- Clearing the archive with confirmation.

Archive repair can address issues such as orphaned price records, invalid receipt aliases, and duplicate records left by earlier versions.

JSON backups include product information, inventory-tracking fields, expiration dates, personal product photos, price records, receipt aliases, and saved duplicate-review information.

> The shopping list is stored separately and is not currently included in JSON backups. Downloaded remote-image cache files are also excluded; product image URLs are retained.

### Adaptive Interface and Error Handling

The SwiftUI interface adapts to different screen sizes and text settings.

The app includes feedback for situations such as:

- Camera permission being denied, with a link to Settings.
- No internet connection.
- Product lookup services being unavailable.
- Receipt text being unreadable.
- Backup validation or import failures.

## Example Workflows

### Add Groceries

1. Scan a product barcode.
2. Review retrieved information or enter missing details.
3. Optionally take a product photo.
4. Choose a storage location.
5. Select package-based or individual-unit tracking.
6. Optionally add an expiration date.
7. Save and update the remaining quantity as the product is used.

### Record Purchase Prices

1. Photograph a receipt.
2. Review the detected supermarket, date, descriptions, and prices.
3. Associate receipt lines with existing products or create catalog entries.
4. Save the price observations.
5. Compare recorded prices across supermarkets in the price catalog.

A receipt can be processed independently of the current pantry contents.

## Technology

- **Swift 6** — application language.
- **SwiftUI** — interface and navigation.
- **SwiftData** — local product, price, and receipt-alias persistence.
- **AVFoundation** — camera and barcode-scanning functionality.
- **UIKit** — camera integration and image handling.
- **Vision** — on-device receipt text recognition.
- **UserNotifications** — local expiration reminders.
- **URLSession** — product and image requests.
- **UserDefaults / AppStorage** — preferences and the local shopping list.
- **Open Food Facts** — external product information.

## Project Structure

The main application sources currently live in the `PantryBuddy/` directory.

```text
PantryBuddy/
├── PantryBuddy.xcodeproj/
├── PrivacyInfo.xcprivacy
├── README.md
└── PantryBuddy/
    ├── Assets.xcassets/
    ├── PantryBuddyApp.swift
    ├── ContentView.swift
    ├── Product.swift
    ├── PriceRecord.swift
    ├── ReceiptAlias.swift
    ├── PantryView.swift
    ├── ProductDetailView.swift
    ├── KnownProductView.swift
    ├── ManualProductEntryView.swift
    ├── ShoppingListView.swift
    ├── BarcodeScannerView.swift
    ├── OpenFoodFactsService.swift
    ├── ProductPhotoCameraView.swift
    ├── ProductImageCache.swift
    ├── InventoryTrackingComponents.swift
    ├── ProductExpirationService.swift
    ├── ProductExpirationComponents.swift
    ├── ReceiptCameraView.swift
    ├── ReceiptScannerView.swift
    ├── ReceiptOCRService.swift
    ├── ReceiptMatchingView.swift
    ├── PriceCatalogView.swift
    ├── ProductPriceDetailView.swift
    ├── ProductMergeService.swift
    ├── StoreNameNormalizer.swift
    ├── ArchiveRepairService.swift
    ├── SettingsView.swift
    ├── PantryTheme.swift
    └── ProductUIComponents.swift
```

Views handle presentation and user interaction, while dedicated services handle recognition, normalization, image caching, expiration reminders, merging, and archive repair.

## Privacy and Offline Use

PantryBuddy does not require an in-app account and currently has no cloud synchronization.

- Inventory and price records are stored locally.
- Receipt OCR runs on the device.
- Personal product photos are stored locally.
- Expiration reminders use local notifications.
- Barcode lookups send the scanned barcode to Open Food Facts.
- Loading uncached remote images requires requests to their image hosts.

Existing local records and personal photos can be used offline. Product lookups and downloads of uncached images require an internet connection.

The project includes a `PrivacyInfo.xcprivacy` manifest.

Exported backups contain personal inventory and purchase information, so they should be stored and shared carefully.

## Build and Run

### Requirements

- A Mac with Xcode.
- An iOS SDK compatible with the project.
- An iPhone running **iOS 17.6 or later**, or a compatible simulator.
- Code signing configured for physical-device installation.

The current development environment uses **Xcode 26.6** and **Swift 6 language mode**.

Use a physical iPhone to test barcode scanning and camera-based workflows.

### Installation

Clone the repository and open the project:

```bash
git clone https://github.com/costafede/PantryBuddy.git
cd PantryBuddy
open PantryBuddy.xcodeproj
```

In Xcode:

1. Select the `PantryBuddy` scheme.
2. Choose a simulator or connected iPhone.
3. Configure your signing team for a physical device.
4. Build and run the app.
5. Grant camera and notification permissions when using the corresponding features.

## Current Limitations

- OCR and product matching can make mistakes and require review.
- Product lookup coverage depends on Open Food Facts.
- Price comparisons use saved observations, not current store listings.
- Expiration tracking uses one date per product, not per batch.
- The shopping list is local, manual, and excluded from JSON backups.
- There is no household sharing or cross-device synchronization.
- Multi-currency support and additional interface languages are not currently implemented.

## Possible Next Steps

- Further improvements to receipt parsing and matching.
- Separate expiration dates for different packages or batches.
- Shopping-list backup and restore.
- Optional shopping suggestions based on remaining stock.
- Price trend charts and additional comparison tools.
- Household sharing and cross-device synchronization.
- Additional localization and accessibility refinements.

These are potential directions rather than a committed release schedule.

## Contributing

PantryBuddy is a personal project. Feedback, bug reports, and improvement suggestions are welcome.

When reporting a problem, include the relevant steps, device model, and iOS version. Screenshots are helpful, but remove personal information from receipts and backups before sharing them.

## Author

**Federico Costa**

Computer Science and Engineering  
Politecnico di Milano

GitHub: [@costafede](https://github.com/costafede)

## Acknowledgments

PantryBuddy uses product information from **Open Food Facts** and native Apple frameworks for scanning, text recognition, persistence, and notifications.

This is an independent project and is not affiliated with Open Food Facts or any supermarket.

Product information, receipt recognition, and duplicate suggestions are assistive features. Users should review automatically retrieved or extracted information before relying on it.
