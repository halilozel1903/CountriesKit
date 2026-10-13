import Foundation

/// Where and how ``CountriesClient`` sends its requests.
public struct CountriesConfiguration: Sendable {
    /// The REST Countries v3.1 API: `https://restcountries.com/v3.1`.
    public static let defaultBaseURL = URL(string: "https://restcountries.com/v3.1")!

    /// The API root every path is appended to. Point it at a proxy or a stub in tests.
    public var baseURL: URL
    /// The session requests are sent with.
    public var session: URLSession
    /// Sent as the `User-Agent` header; `nil` keeps the session's default.
    public var userAgent: String?
    /// Seconds before a request times out.
    public var timeout: TimeInterval

    public init(
        baseURL: URL = CountriesConfiguration.defaultBaseURL,
        session: URLSession = .shared,
        userAgent: String? = "CountriesKit/1.0 (+https://github.com/halilozel1903/CountriesKit)",
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.session = session
        self.userAgent = userAgent
        self.timeout = timeout
    }
}
