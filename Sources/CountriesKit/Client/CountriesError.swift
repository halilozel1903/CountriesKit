import Foundation

/// Errors thrown by ``CountriesClient``.
public enum CountriesError: Error, Equatable, Sendable, LocalizedError {
    /// No country has this code. Only thrown by ``CountriesClient/country(code:)``; searches
    /// answer an empty array instead.
    case notFound(code: String)
    /// The dataset could not be downloaded: the server answered with this HTTP status.
    case http(statusCode: Int, url: URL)
    /// The download was not a JSON list of countries.
    case decoding(description: String)
    /// The download could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The call could never succeed, for example a lookup by an empty code.
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case let .notFound(code):
            return "No country has the code \(code)."
        case let .http(statusCode, url):
            return "The country data at \(url.host ?? url.absoluteString) answered with HTTP status \(statusCode)."
        case .decoding:
            return "The country data could not be read."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "The country data server sent an invalid response."
        case let .invalidRequest(reason):
            return reason
        }
    }
}
