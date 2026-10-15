import CountryData
import Foundation
import OSLog

enum CountryErrorPresentation {
    enum Context: String {
        case countries
        case country
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CountryBrowser",
        category: "CountryLoading"
    )

    static func message(for error: any Error, context: Context) -> String {
        let category: CountryRepositoryError.Category = switch error {
        case let repositoryError as CountryRepositoryError:
            repositoryError.category
        case is URLError:
            .network
        default:
            .request
        }

        logger.error(
            """
            \(context.rawValue, privacy: .public) load failed \
            (\(category.rawValue, privacy: .public)): \
            \(String(reflecting: error), privacy: .private)
            """
        )

        return switch (context, category) {
        case (.countries, .network):
            String(localized: "countries.error.load", bundle: .module)
        case (.countries, .graphQL):
            String(localized: "countries.error.graphQL", bundle: .module)
        case (.countries, .missingData):
            String(localized: "countries.error.missingData", bundle: .module)
        case (.countries, .request):
            String(localized: "countries.error.request", bundle: .module)
        case (.country, .network):
            String(localized: "country.error.load", bundle: .module)
        case (.country, .graphQL):
            String(localized: "country.error.graphQL", bundle: .module)
        case (.country, .missingData):
            String(localized: "country.error.missingData", bundle: .module)
        case (.country, .request):
            String(localized: "country.error.request", bundle: .module)
        }
    }
}
