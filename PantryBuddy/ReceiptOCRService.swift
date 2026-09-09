import Foundation
import UIKit
@preconcurrency import Vision

nonisolated struct ReceiptTextElement {

    let text: String

    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var centerY: CGFloat {
        y + height / 2
    }
}

nonisolated struct ReceiptProductItem: Identifiable {

    let id: UUID

    let description: String
    let price: Double

    init(
        id: UUID = UUID(),
        description: String,
        price: Double
    ) {
        self.id = id
        self.description = description
        self.price = price
    }
}

nonisolated struct ReceiptOCRResult {

    let storeName: String?
    let items: [ReceiptProductItem]

    // Rimane nil quando non viene riconosciuta una data valida.
    let purchaseDate: Date?

    // Testo completo riconosciuto.
    let rawText: String

    init(
        storeName: String?,
        items: [ReceiptProductItem],
        rawText: String,
        purchaseDate: Date? = nil
    ) {
        self.storeName = storeName
        self.items = items
        self.purchaseDate = purchaseDate
        self.rawText = rawText
    }
}

nonisolated enum ReceiptOCRError: Error {

    case invalidImage
    case recognitionFailed
}

nonisolated final class ReceiptOCRService {

    static func recognizeReceipt(
        from image: UIImage
    ) async throws -> ReceiptOCRResult {

        guard let cgImage = image.cgImage else {
            throw ReceiptOCRError.invalidImage
        }

        let orientation = cgImageOrientation(
            from: image.imageOrientation
        )

        return try await withCheckedThrowingContinuation { continuation in

            /*
             La richiesta non usa il callback di Vision.

             Tutta l’elaborazione viene completata attraverso un solo
             percorso, impedendo di eseguire due volte la continuation.
             */
            let request = VNRecognizeTextRequest()

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [
                "nb-NO",
                "en-US"
            ]

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            DispatchQueue.global(
                qos: .userInitiated
            ).async {
                do {
                    /*
                     Mantiene in vita gli oggetti di Vision fino alla fine
                     dell’estrazione, poi libera la memoria temporanea.
                     */
                    let result: ReceiptOCRResult = try autoreleasepool {
                        try handler.perform([request])

                        guard let observations = request.results else {
                            throw ReceiptOCRError.recognitionFailed
                        }

                        let elements = extractElements(
                            from: observations
                        )

                        let lines = reconstructLines(
                            from: elements
                        )

                        return ReceiptOCRResult(
                            storeName: detectStore(
                                from: lines
                            ),
                            items: extractProducts(
                                from: lines
                            ),
                            rawText: lines.joined(
                                separator: "\n"
                            ),
                            purchaseDate: detectPurchaseDate(
                                from: lines
                            )
                        )
                    }

                    continuation.resume(
                        returning: result
                    )
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }

    // MARK: - Elementi OCR

    private static func extractElements(
        from observations: [VNRecognizedTextObservation]
    ) -> [ReceiptTextElement] {

        observations.compactMap { observation in
            guard let candidate = observation
                .topCandidates(1)
                .first
            else {
                return nil
            }

            let text = candidate.string
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !text.isEmpty else {
                return nil
            }

            let box = observation.boundingBox

            return ReceiptTextElement(
                text: text,
                x: box.origin.x,
                y: box.origin.y,
                width: box.width,
                height: box.height
            )
        }
    }

    // MARK: - Ricostruzione righe

    private static func reconstructLines(
        from elements: [ReceiptTextElement]
    ) -> [String] {

        let sorted = elements.sorted {
            if abs($0.centerY - $1.centerY) > 0.004 {
                return $0.centerY > $1.centerY
            }

            return $0.x < $1.x
        }

        struct LineGroup {

            var elements: [ReceiptTextElement]

            var averageY: CGFloat {
                guard !elements.isEmpty else {
                    return 0
                }

                return elements
                    .map(\.centerY)
                    .reduce(0, +)
                    / CGFloat(elements.count)
            }

            var averageHeight: CGFloat {
                guard !elements.isEmpty else {
                    return 0
                }

                return elements
                    .map(\.height)
                    .reduce(0, +)
                    / CGFloat(elements.count)
            }
        }

        var groups: [LineGroup] = []

        for element in sorted {
            var bestIndex: Int?
            var bestDistance = CGFloat.greatestFiniteMagnitude

            for index in groups.indices {
                let group = groups[index]

                let distance = abs(
                    group.averageY - element.centerY
                )

                let tolerance = max(
                    0.004,
                    max(
                        group.averageHeight,
                        element.height
                    ) * 0.45
                )

                if distance <= tolerance,
                   distance < bestDistance {
                    bestDistance = distance
                    bestIndex = index
                }
            }

            if let bestIndex {
                groups[bestIndex]
                    .elements
                    .append(element)
            } else {
                groups.append(
                    LineGroup(
                        elements: [element]
                    )
                )
            }
        }

        groups.sort {
            $0.averageY > $1.averageY
        }

        let lines = groups.compactMap { group -> String? in
            let line = group.elements
                .sorted {
                    $0.x < $1.x
                }
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            return line.isEmpty ? nil : line
        }

        return mergeStandalonePrices(
            in: lines
        )
    }

    // MARK: - Prezzi su righe separate

    private static func mergeStandalonePrices(
        in lines: [String]
    ) -> [String] {

        var result: [String] = []
        var index = 0

        while index < lines.count {
            let current = lines[index]

            if index + 1 < lines.count {
                let next = lines[index + 1]

                if extractPrice(from: current) == nil,
                   isStandalonePrice(next) {
                    result.append(
                        current + " " + next
                    )

                    index += 2
                    continue
                }
            }

            result.append(current)
            index += 1
        }

        return result
    }

    // MARK: - Negozio

    private static func detectStore(
        from lines: [String]
    ) -> String? {

        let header = lines
            .prefix(10)
            .joined(separator: " ")
            .uppercased()

        if header.contains("REMA 1000") {
            return "REMA 1000"
        }

        if header.contains("KIWI") {
            return "KIWI"
        }

        if header.contains("EXTRA") {
            return "Coop Extra"
        }

        if header.contains("COOP PRIX") {
            return "Coop Prix"
        }

        if header.contains("COOP OBS")
            || header.contains("OBS") {
            return "Coop Obs"
        }

        if header.contains("COOP") {
            return "Coop"
        }

        if header.contains("MENY") {
            return "MENY"
        }

        if header.contains("BUNNPRIS") {
            return "Bunnpris"
        }

        if header.contains("SPAR") {
            return "SPAR"
        }

        return nil
    }

    // MARK: - Data di acquisto

    private static func detectPurchaseDate(
        from lines: [String]
    ) -> Date? {

        let text = lines.joined(
            separator: " "
        )

        /*
         Formati supportati:

         30.08.2026
         30/08/2026
         30-08-26
         */
        let dayFirstPattern =
            #"\b(\d{1,2})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{2}|\d{4})\b"#

        for values in dateComponentMatches(
            in: text,
            pattern: dayFirstPattern
        ) {
            if let date = makeDate(
                day: values[0],
                month: values[1],
                year: values[2]
            ) {
                return date
            }
        }

        /*
         Formato supportato:

         2026-08-30
         */
        let yearFirstPattern =
            #"\b(\d{4})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{1,2})\b"#

        for values in dateComponentMatches(
            in: text,
            pattern: yearFirstPattern
        ) {
            if let date = makeDate(
                day: values[2],
                month: values[1],
                year: values[0]
            ) {
                return date
            }
        }

        return nil
    }

    private static func dateComponentMatches(
        in text: String,
        pattern: String
    ) -> [[Int]] {

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return []
        }

        let fullRange = NSRange(
            text.startIndex...,
            in: text
        )

        var results: [[Int]] = []

        for match in regex.matches(
            in: text,
            range: fullRange
        ) {
            var values: [Int] = []

            for index in 1...3 {
                guard
                    let range = Range(
                        match.range(at: index),
                        in: text
                    ),
                    let value = Int(text[range])
                else {
                    values.removeAll()
                    break
                }

                values.append(value)
            }

            if values.count == 3 {
                results.append(values)
            }
        }

        return results
    }

    private static func makeDate(
        day: Int,
        month: Int,
        year: Int
    ) -> Date? {

        let resolvedYear =
            year < 100
            ? 2000 + year
            : year

        guard (2000...2100).contains(resolvedYear) else {
            return nil
        }

        var calendar = Calendar(
            identifier: .gregorian
        )

        calendar.timeZone = .current

        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: resolvedYear,
            month: month,
            day: day,
            hour: 12
        )

        guard let date = calendar.date(
            from: components
        ) else {
            return nil
        }

        let check = calendar.dateComponents(
            [
                .year,
                .month,
                .day
            ],
            from: date
        )

        guard
            check.year == resolvedYear,
            check.month == month,
            check.day == day
        else {
            return nil
        }

        return date
    }

    // MARK: - Prodotti

    private static func extractProducts(
        from lines: [String]
    ) -> [ReceiptProductItem] {

        var products: [ReceiptProductItem] = []

        for line in lines {
            guard let price = extractPrice(
                from: line
            ) else {
                continue
            }

            let description = removePrice(
                from: line
            )

            guard
                !description.isEmpty,
                isPossibleProduct(description)
            else {
                continue
            }

            products.append(
                ReceiptProductItem(
                    description: description,
                    price: price
                )
            )
        }

        return products
    }

    // MARK: - Filtri

    private static func isPossibleProduct(
        _ description: String
    ) -> Bool {

        let text = description.uppercased()

        let excludedWords = [
            "TOTAL",
            "TOTALT",
            "BANK",
            "DAGLIGVARER",
            "ØVRIGE VARER",
            "TOTALBELØP",
            "MVA",
            "MVA-GRUNNLAG",
            "SUMMER",
            "SPART",
            "RABATTER",
            "MEDLEMSFORDEL",
            "GODKJENT",
            "AUTHORIZATION",
            "TERMINAL",
            "CLERK",
            "KASSERER",
            "SALGSKVITTERING",
            "VISA",
            "DEBIT",
            "KJØP",
            "BUTIKK",
            "ORG.NR",
            "TELEFON"
        ]

        for word in excludedWords {
            if text.contains(word) {
                return false
            }
        }

        return text.range(
            of: #"[A-ZÆØÅ]"#,
            options: .regularExpression
        ) != nil
    }

    // MARK: - Prezzi

    private static func extractPrice(
        from text: String
    ) -> Double? {

        let pattern =
            #"(-?\d{1,6})\s*[.,]\s*(\d{2})\s*(?:NOK|KR)?\s*$"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return nil
        }

        let range = NSRange(
            text.startIndex...,
            in: text
        )

        guard
            let match = regex.firstMatch(
                in: text,
                range: range
            ),
            match.numberOfRanges >= 3,
            let integerRange = Range(
                match.range(at: 1),
                in: text
            ),
            let decimalRange = Range(
                match.range(at: 2),
                in: text
            )
        else {
            return nil
        }

        let integerPart = String(
            text[integerRange]
        )

        let decimalPart = String(
            text[decimalRange]
        )

        return Double(
            "\(integerPart).\(decimalPart)"
        )
    }

    private static func isStandalonePrice(
        _ text: String
    ) -> Bool {

        let pattern =
            #"^\s*-?\d{1,6}\s*[.,]\s*\d{2}\s*(?:NOK|KR)?\s*$"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return false
        }

        let range = NSRange(
            text.startIndex...,
            in: text
        )

        return regex.firstMatch(
            in: text,
            range: range
        ) != nil
    }

    private static func removePrice(
        from text: String
    ) -> String {

        let pattern =
            #"\s+-?\d{1,6}\s*[.,]\s*\d{2}\s*(?:NOK|KR)?\s*$"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return text
        }

        let range = NSRange(
            text.startIndex...,
            in: text
        )

        return regex
            .stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: ""
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    // MARK: - Orientamento immagine

    private static func cgImageOrientation(
        from orientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {

        switch orientation {
        case .up:
            return .up

        case .down:
            return .down

        case .left:
            return .left

        case .right:
            return .right

        case .upMirrored:
            return .upMirrored

        case .downMirrored:
            return .downMirrored

        case .leftMirrored:
            return .leftMirrored

        case .rightMirrored:
            return .rightMirrored

        @unknown default:
            return .up
        }
    }
}
