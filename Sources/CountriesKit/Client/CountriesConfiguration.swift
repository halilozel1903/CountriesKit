import Foundation

/// Where and how ``CountriesClient`` loads the country dataset.
public struct CountriesConfiguration: Sendable {
    /// The open [mledoze/countries](https://github.com/mledoze/countries) dataset on jsDelivr:
    /// one JSON file with every country, the data REST Countries was originally built from.
    public static let jsDelivrURL = URL(string: "https://cdn.jsdelivr.net/gh/mledoze/countries@master/countries.json")!

    /// The same file straight from GitHub, for when jsDelivr is not reachable.
    public static let gitHubRawURL = URL(string: "https://raw.githubusercontent.com/mledoze/countries/master/countries.json")!

    /// The default dataset URL: ``jsDelivrURL``.
    public static let defaultDatasetURL = jsDelivrURL

    /// The JSON file of every country. Point it at ``gitHubRawURL``, a pinned version
    /// (`…/gh/mledoze/countries@<tag>/countries.json`), your own mirror or a stub in tests.
    public var datasetURL: URL
    /// The session the dataset is loaded with.
    public var session: URLSession
    /// Sent as the `User-Agent` header; `nil` keeps the session's default.
    public var userAgent: String?
    /// Seconds before the download times out.
    public var timeout: TimeInterval
    /// Seconds a loaded dataset is reused before the next call loads it again.
    public var cacheLifetime: TimeInterval

    public init(
        datasetURL: URL = CountriesConfiguration.defaultDatasetURL,
        session: URLSession = .shared,
        userAgent: String? = "CountriesKit/1.0 (+https://github.com/halilozel1903/CountriesKit)",
        timeout: TimeInterval = 30,
        cacheLifetime: TimeInterval = 6 * 60 * 60
    ) {
        self.datasetURL = datasetURL
        self.session = session
        self.userAgent = userAgent
        self.timeout = timeout
        self.cacheLifetime = cacheLifetime
    }
}
