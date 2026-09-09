import Foundation

struct OpenFoodFactsProduct: Codable, Sendable {
    let productName: String?
    let brands: String?
    let quantity: String?
    let imageFrontUrl: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case quantity
        case imageFrontUrl = "image_front_url"
    }
}

enum OpenFoodFactsError: LocalizedError, Equatable {
    case invalidURL
    case productNotFound
    case noConnection
    case serviceUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Il codice a barre non è valido."

        case .productNotFound:
            return "Il prodotto non è presente nel catalogo online."

        case .noConnection:
            return "Non c’è connessione a Internet."

        case .serviceUnavailable:
            return "Il servizio prodotti non è disponibile in questo momento."

        case .invalidResponse:
            return "Il servizio ha restituito una risposta non valida."
        }
    }
}

enum OpenFoodFactsService {

    static func fetchProduct(
        barcode rawBarcode: String
    ) async throws -> OpenFoodFactsProduct {
        let barcode = rawBarcode.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !barcode.isEmpty,
            barcode.allSatisfy({ $0.isNumber })
        else {
            throw OpenFoodFactsError.invalidURL
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(barcode).json"
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value:
                    "product_name,brands,quantity,image_front_url"
            )
        ]

        guard let url = components.url else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        request.setValue(
            "PantryBuddy/1.0 (iOS)",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) =
                try await URLSession.shared.data(
                    for: request
                )
        } catch let urlError as URLError {
            throw mapNetworkError(urlError)
        } catch {
            throw OpenFoodFactsError
                .serviceUnavailable
        }

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw OpenFoodFactsError
                .invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break

        case 404:
            throw OpenFoodFactsError
                .productNotFound

        case 408, 425, 429, 500...599:
            throw OpenFoodFactsError
                .serviceUnavailable

        default:
            throw OpenFoodFactsError
                .invalidResponse
        }

        do {
            let decoded =
                try JSONDecoder().decode(
                    OpenFoodFactsResponse.self,
                    from: data
                )

            guard
                decoded.status == 1,
                let product = decoded.product
            else {
                throw OpenFoodFactsError
                    .productNotFound
            }

            return product
        } catch let error as OpenFoodFactsError {
            throw error
        } catch {
            throw OpenFoodFactsError
                .invalidResponse
        }
    }

    private static func mapNetworkError(
        _ error: URLError
    ) -> OpenFoodFactsError {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dataNotAllowed,
             .internationalRoamingOff:
            return .noConnection

        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .resourceUnavailable:
            return .serviceUnavailable

        default:
            return .serviceUnavailable
        }
    }
}

private struct OpenFoodFactsResponse:
    Codable,
    Sendable {

    let status: Int
    let product: OpenFoodFactsProduct?
}
