# PantryBuddy

![Swift](https://img.shields.io/badge/Swift-iOS-orange)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![Status](https://img.shields.io/badge/status-active%20development-yellow)

**PantryBuddy** is a native iOS application designed to simplify grocery shopping and pantry management.

The app combines **barcode scanning, receipt OCR, inventory tracking, expiration management, and price history** into a single workflow, allowing users to keep track of what they own, what they paid, where they bought it, and when it should be consumed.

The project is currently under active development.

---

## Overview

Managing groceries usually involves information scattered across receipts, product packaging, supermarket apps, and memory.

PantryBuddy aims to bring all of this information together.

Users can add products by scanning their barcode or entering them manually, manage quantities and expiration dates, scan grocery receipts, associate receipt items with products in their pantry, and build a personal history of product prices across different stores.

The goal is to make the pantry a structured and searchable digital inventory rather than just a list of products.

---

## Features

### Pantry Management

- Add and manage products stored in the pantry
- Track product quantities
- View product details
- Update existing items
- Merge duplicate product entries
- Maintain a structured inventory of available products

### Barcode Scanning

- Scan product barcodes using the iPhone camera
- Automatically identify supported products
- Retrieve product information from external product databases
- Fall back to manual entry when no product information is available

### OpenFoodFacts Integration

PantryBuddy integrates with the **OpenFoodFacts API** to retrieve product information from scanned barcodes.

This can reduce the amount of information that needs to be entered manually when adding common supermarket products.

### Manual Product Entry

Products that cannot be identified automatically can still be added manually.

This makes the application usable even when:

- a barcode is unavailable
- the product is not present in OpenFoodFacts
- the user wants to create a custom pantry item

### Expiration Tracking

- Store expiration dates for products
- Identify products approaching their expiration date
- Organize inventory based on product freshness
- Help reduce unnecessary food waste

### Receipt Scanning

PantryBuddy can capture grocery receipts using the iPhone camera and process them through OCR.

The receipt workflow is designed to extract information such as:

- purchased items
- product prices
- store information
- receipt data useful for matching purchases with pantry products

### Receipt OCR

Receipt text is processed locally using Apple's text-recognition technologies.

The extracted information is then normalized and prepared for matching with known products.

### Receipt-to-Product Matching

The app can associate products detected on a receipt with items stored in the pantry.

Because receipt descriptions often differ significantly from actual product names, PantryBuddy includes dedicated matching logic to improve the association process.

Users can review and correct matches when necessary.

### Price Tracking

PantryBuddy keeps track of product purchase prices over time.

For each product, users can build a history containing information such as:

- purchase price
- supermarket or store
- purchase date

This makes it possible to compare how the price of the same product changes across stores and over time.

### Store Name Normalization

Supermarket names extracted from receipts may contain inconsistent formatting.

PantryBuddy normalizes store names so that different variations of the same supermarket can be treated consistently.

### Product Images

The app supports product image management and local image caching to provide a more visual browsing experience without repeatedly retrieving the same resources.

---

## Typical Workflow

A typical PantryBuddy workflow looks like this:

1. The user buys groceries.
2. Products are added by scanning their barcodes or entering them manually.
3. PantryBuddy retrieves available product information automatically.
4. Quantities and expiration dates are stored in the pantry.
5. The user scans the supermarket receipt.
6. OCR extracts receipt information.
7. Receipt items are matched with products stored in the app.
8. Purchase prices are associated with the corresponding products.
9. Over time, PantryBuddy builds both an inventory history and a personal price database.

---

## Tech Stack

PantryBuddy is developed as a native iOS application using Apple's ecosystem.

### Core Technologies

- **Swift**
- **SwiftUI**
- **Xcode**
- Native iOS frameworks
- Local data persistence

### Camera and Scanning

The project uses native iOS camera capabilities for:

- barcode scanning
- product photography
- receipt capture

### OCR

Apple's native computer vision and text-recognition technologies are used to process receipt images.

This allows receipt recognition to be performed without relying on paid external AI APIs.

### External Data

Product information can be retrieved through:

- **OpenFoodFacts API**

---

## Architecture

The project separates user interface components from the services responsible for product recognition, receipt processing, inventory management, and data normalization.

Some of the main components include:

```text
PantryBuddy/
│
├── PantryBuddyApp.swift
├── ContentView.swift
│
├── Pantry
│   ├── PantryView.swift
│   ├── Product.swift
│   ├── ProductDetailView.swift
│   ├── KnownProductView.swift
│   └── ManualProductEntryView.swift
│
├── Inventory
│   ├── InventoryTrackingComponents.swift
│   ├── ProductExpirationService.swift
│   ├── ProductExpirationComponents.swift
│   └── ProductMergeService.swift
│
├── Product Scanning
│   ├── BarcodeScannerView.swift
│   ├── OpenFoodFactsService.swift
│   └── ProductPhotoCameraView.swift
│
├── Receipts
│   ├── ReceiptCameraView.swift
│   ├── ReceiptScannerView.swift
│   ├── ReceiptOCRService.swift
│   ├── ReceiptMatchingView.swift
│   └── ReceiptAlias.swift
│
├── Prices
│   ├── PriceRecord.swift
│   ├── PriceCatalogView.swift
│   └── ProductPriceDetailView.swift
│
├── Supporting Services
│   ├── ProductImageCache.swift
│   ├── StoreNameNormalizer.swift
│   └── ArchiveRepairService.swift
│
├── UI
│   ├── PantryTheme.swift
│   ├── ProductUIComponents.swift
│   └── SettingsView.swift
│
└── PrivacyInfo.xcprivacy
```

The exact organization may evolve as development continues.

---

## Design Goals

PantryBuddy is being developed around a few core principles.

### Native iOS Experience

The interface is built using SwiftUI and is designed to feel consistent with the rest of the iOS ecosystem.

### Low-Friction Product Entry

Adding a product should require as little manual work as possible.

Barcode scanning and external product information are therefore used whenever possible.

### Local Processing

Whenever practical, information is processed directly on the device.

In particular, receipt OCR does not require a paid cloud-based AI service.

### Human-Correctable Automation

Information extracted automatically is not assumed to be perfect.

Users remain able to review and correct product information, OCR results, receipt matches, and other automatically generated data.

### Extensibility

Scanning, OCR, inventory management, price tracking, and product matching are implemented as separate components so that they can evolve independently as the application grows.

---

## Privacy

PantryBuddy is designed with privacy in mind.

Sensitive operations such as receipt text recognition can be performed using native on-device technologies rather than uploading receipt images to an external AI service.

The project also includes an iOS privacy manifest:

```text
PrivacyInfo.xcprivacy
```

Camera access is required for functionality such as barcode scanning, product photography, and receipt capture.

---

## Requirements

To build the project you need:

- macOS
- Xcode
- a recent iOS SDK
- an iPhone simulator or physical iPhone

Some camera-based functionality may require a physical iPhone to be tested properly.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/costafede/PantryBuddy.git
```

Enter the project directory:

```bash
cd PantryBuddy
```

Open the Xcode project:

```bash
open PantryBuddy.xcodeproj
```

Then:

1. Select an iPhone simulator or connected physical device.
2. Configure code signing if required.
3. Build and run the application from Xcode.

---

## Current Status

PantryBuddy is currently under active development.

The application already includes the foundations for:

- pantry management
- barcode-based product recognition
- OpenFoodFacts integration
- manual product entry
- expiration tracking
- receipt capture
- OCR processing
- receipt-to-product matching
- price tracking
- store normalization
- product image handling

Some workflows and matching algorithms are still being refined.

---

## Roadmap

Possible future improvements include:

- Improved receipt parsing and product matching
- More robust automatic product-name normalization
- Better handling of quantities and units
- Advanced price comparison between supermarkets
- Price trend visualization
- Shopping list generation
- Notifications for expiring products
- Pantry analytics
- Improved duplicate detection
- Search and advanced filtering
- Improved product categorization
- Import/export functionality
- Cloud synchronization across devices
- Enhanced accessibility
- Additional localization support

---

## Motivation

PantryBuddy started as a personal project aimed at solving a practical everyday problem: keeping track of groceries without manually maintaining multiple lists.

It also serves as an exploration of several areas of iOS development, including:

- mobile application architecture
- camera integration
- barcode recognition
- computer vision
- OCR
- external API integration
- local data management
- information normalization
- matching algorithms
- UI/UX design

The project is designed to evolve incrementally, with automation being introduced where it provides clear value while preserving the possibility of manual correction.

---

## Contributing

PantryBuddy is currently a personal project, but suggestions, feedback, and ideas are welcome.

If you find an issue or have an improvement in mind, feel free to open an issue in the repository.

---

## Author

**Federico Costa**

Computer Science and Engineering  
Politecnico di Milano

GitHub: [@costafede](https://github.com/costafede)

---

## Disclaimer

PantryBuddy is an independent personal project.

Product information retrieved from OpenFoodFacts depends on the availability and accuracy of data provided by the OpenFoodFacts database.

Receipt OCR and automatic product matching may not always produce perfect results and should therefore be considered assistive features rather than authoritative data sources.