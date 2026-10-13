import Foundation

/// Errors thrown by ``CountriesClient``.
public enum CountriesError: Error, Equatable, Sendable, LocalizedError {
    /// Nothing matches (HTTP 404). Only thrown for single lookups such as
    /// ``CountriesClient/country(code:fields:)``; searches answer an empty array instead.
    case notFound(url: URL)
    /// Any other unsuccessful HTTP status, with the API's `message` when it sent one.
    case http(statusCode: Int, message: String?, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The request was not sent because it could never succeed, for example `/all` without
    /// fields.
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "REST Countries has no country matching this request."
        case let .http(statusCode, message, _):
            return message.map { "REST Countries answered with HTTP status \(statusCode): \($0)" }
                ?? "REST Countries answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "REST Countries sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "REST Countries sent an invalid response."
        case let .invalidRequest(reason):
            return reason
        }
    }
}

/// The body the API sends with an error status: `{"status":404,"message":"Not Found"}`.
struct APIErrorBody: Decodable {
    let message: String?
    let status: Int?
}
