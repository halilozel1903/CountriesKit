import Foundation

/// An async client for the REST Countries v3.1 API (restcountries.com).
///
/// No API key is needed. Every method takes an optional list of ``CountryField``s; the API then
/// sends only those fields, which keeps responses small. `/all` *requires* fields (at most
/// ``maxFieldsForAll``).
///
/// ```swift
/// let api = CountriesClient()
/// let turkey = try await api.country(code: "TUR")
/// let neighbours = try await api.borders(of: turkey, fields: [.name, .cca3, .flags])
/// let europe = try await api.countries(in: .europe, fields: CountryField.listing)
/// ```
public struct CountriesClient: Sendable {
    /// A client with the default configuration.
    public static let shared = CountriesClient()

    /// The most fields `/all` accepts in one request.
    public static let maxFieldsForAll = 10

    /// Codes sent in one `/alpha?codes=` request; longer lists are split.
    public static let maxCodesPerRequest = 50

    public let configuration: CountriesConfiguration

    public init(configuration: CountriesConfiguration = CountriesConfiguration()) {
        self.configuration = configuration
    }

    // MARK: - Endpoints

    /// `GET /all?fields=…`: every country, with the given fields only.
    ///
    /// The API refuses `/all` without fields, so an empty list throws
    /// ``CountriesError/invalidRequest(_:)`` without sending anything, and so do more than
    /// ``maxFieldsForAll`` fields.
    public func all(fields: [CountryField]) async throws -> [Country] {
        let unique = CountryField.unique(fields)
        guard !unique.isEmpty else {
            throw CountriesError.invalidRequest("The /all endpoint needs the fields you want, for example [.name, .flags].")
        }
        guard unique.count <= Self.maxFieldsForAll else {
            throw CountriesError.invalidRequest("The /all endpoint takes at most \(Self.maxFieldsForAll) fields; \(unique.count) were given.")
        }
        return try await list(["all"], fields: unique)
    }

    /// `GET /name/{name}`: countries whose common, official or native name contains `name`.
    /// With `fullText`, only an exact common or official name matches.
    public func countries(named name: String, fullText: Bool = false, fields: [CountryField] = []) async throws -> [Country] {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        let extra = fullText ? [URLQueryItem(name: "fullText", value: "true")] : []
        return try await list(["name", name], fields: fields, extra: extra)
    }

    /// `GET /alpha/{code}`: one country by its cca2 (`TR`), cca3 (`TUR`), ccn3 (`792`) or cioc
    /// code. Throws ``CountriesError/notFound(url:)`` when no country has the code.
    public func country(code: String, fields: [CountryField] = []) async throws -> Country {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            throw CountriesError.invalidRequest("A country code is needed, such as TR or TUR.")
        }
        let request = try makeRequest(["alpha", code], query: Self.fieldsQuery(CountryField.unique(fields)))
        let body = try await data(for: request)
        guard let country = try countries(from: body, url: request.url ?? configuration.baseURL).first else {
            throw CountriesError.notFound(url: request.url ?? configuration.baseURL)
        }
        return country
    }

    /// `GET /alpha?codes=…`: several countries by code (any mix of cca2, cca3, ccn3 and cioc).
    ///
    /// The result follows the order of `codes`; duplicates and unknown codes are dropped. Long
    /// lists are split into several requests. When `fields` leave out every code field, `cca3` is
    /// added so the order can be kept.
    public func countries(codes: [String], fields: [CountryField] = []) async throws -> [Country] {
        var seen = Set<String>()
        let unique = codes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !unique.isEmpty else { return [] }

        var requested = CountryField.unique(fields)
        if !requested.isEmpty, !requested.contains(where: { CountryField.codeFields.contains($0) }) {
            requested.append(.cca3)
        }

        var found: [Country] = []
        var start = 0
        while start < unique.count {
            let end = min(start + Self.maxCodesPerRequest, unique.count)
            let chunk = unique[start..<end].joined(separator: ",")
            start = end
            let query = [URLQueryItem(name: "codes", value: chunk)] + Self.fieldsQuery(requested)
            found += try await list(["alpha"], query: query)
        }
        return Self.ordered(found, by: unique)
    }

    /// `GET /currency/{currency}`: countries that use a currency, by code (`EUR`) or name.
    public func countries(currency: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("currency", currency, fields: fields)
    }

    /// `GET /lang/{language}`: countries where a language is spoken, by code (`tur`) or name.
    public func countries(language: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("lang", language, fields: fields)
    }

    /// `GET /region/{region}`: the countries of a region.
    public func countries(in region: Region, fields: [CountryField] = []) async throws -> [Country] {
        try await search("region", region.pathValue, fields: fields)
    }

    /// `GET /subregion/{subregion}`: the countries of a subregion, such as `Western Asia`.
    public func countries(subregion: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("subregion", subregion, fields: fields)
    }

    /// `GET /capital/{capital}`: countries by capital city.
    public func countries(capital: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("capital", capital, fields: fields)
    }

    /// `GET /demonym/{demonym}`: countries by what their people are called, such as `peruvian`.
    public func countries(demonym: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("demonym", demonym, fields: fields)
    }

    /// `GET /translation/{name}`: countries by a translated name, such as `Alemania`.
    public func countries(translation: String, fields: [CountryField] = []) async throws -> [Country] {
        try await search("translation", translation, fields: fields)
    }

    /// `GET /independent?status=…`: independent countries, or with `false` the territories.
    public func independentCountries(_ independent: Bool = true, fields: [CountryField] = []) async throws -> [Country] {
        try await list(["independent"], fields: fields, extra: [URLQueryItem(name: "status", value: independent ? "true" : "false")])
    }

    // MARK: - Borders

    /// The countries that share a land border with `country`, in the order of its `borders`
    /// field, in one request. `country` must have been loaded with the `borders` field (a full
    /// lookup has it); an island answers `[]` without a request.
    public func borders(of country: Country, fields: [CountryField] = []) async throws -> [Country] {
        guard let borders = country.borders, !borders.isEmpty else { return [] }
        return try await countries(codes: borders, fields: fields)
    }

    // MARK: - Any path

    /// Fetches and decodes a path below the base URL, for anything this client has no method
    /// for. Each segment is percent-encoded.
    public func get<Value: Decodable>(_ segments: [String], query: [URLQueryItem] = [], as type: Value.Type = Value.self) async throws -> Value {
        try await decode(Value.self, from: data(for: makeRequest(segments, query: query)))
    }

    // MARK: - Internals

    /// The `fields` query item, or nothing.
    static func fieldsQuery(_ fields: [CountryField]) -> [URLQueryItem] {
        guard !fields.isEmpty else { return [] }
        return [URLQueryItem(name: "fields", value: fields.map(\.rawValue).joined(separator: ","))]
    }

    /// Sorts countries into the order of the codes they were asked for. Countries that match no
    /// code (their code fields were not sent) keep the API's order, after the others.
    static func ordered(_ countries: [Country], by codes: [String]) -> [Country] {
        let rank = Dictionary(codes.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var ranked: [(Int, Int, Country)] = []
        for (index, country) in countries.enumerated() {
            let position = country.codes.compactMap { rank[$0.uppercased()] }.min() ?? (codes.count + index)
            let key = country.id.isEmpty ? "#" + String(index) : country.id
            guard seen.insert(key).inserted else { continue }
            ranked.append((position, index, country))
        }
        return ranked.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map(\.2)
    }

    private func search(_ endpoint: String, _ value: String, fields: [CountryField]) async throws -> [Country] {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        return try await list([endpoint, value], fields: fields)
    }

    /// A list endpoint; the API's 404 for "no matches" is an empty array.
    func list(_ segments: [String], fields: [CountryField] = [], extra: [URLQueryItem] = []) async throws -> [Country] {
        try await list(segments, query: extra + Self.fieldsQuery(CountryField.unique(fields)))
    }

    func list(_ segments: [String], query: [URLQueryItem]) async throws -> [Country] {
        let request = try makeRequest(segments, query: query)
        let body: Data
        do {
            body = try await data(for: request)
        } catch CountriesError.notFound {
            return []
        }
        return try countries(from: body, url: request.url ?? configuration.baseURL)
    }

    /// The countries in a successful response: an array, or the single object `/alpha/{code}`
    /// answers with `fields`. A body that is the API's error object (`{"status":…,"message":…}`)
    /// throws ``CountriesError/http(statusCode:message:url:)`` instead of passing for an empty
    /// country, since every `Country` field is optional.
    func countries(from body: Data, url: URL) throws -> [Country] {
        if let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let message = object["message"] {
            let status = (object["status"] as? NSNumber)?.intValue ?? 200
            throw CountriesError.http(statusCode: status, message: (message as? String) ?? String(describing: message), url: url)
        }
        return try decode(OneOrMany<Country>.self, from: body).items
    }

    /// Characters left as they are in a path segment; `/`, `?`, `#` and `;` are encoded.
    private static let segmentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#;")
        return allowed
    }()

    func makeRequest(_ segments: [String], query: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw CountriesError.transport(URLError(.badURL))
        }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        for segment in segments {
            guard let encoded = segment.addingPercentEncoding(withAllowedCharacters: Self.segmentAllowed) else {
                throw CountriesError.transport(URLError(.badURL))
            }
            path += "/" + encoded
        }
        components.percentEncodedPath = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else {
            throw CountriesError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let start = String(decoding: data.prefix(300), as: UTF8.self)
            throw CountriesError.decoding(type: String(describing: Value.self), description: "\(error); the body starts with: \(start)")
        }
    }

    /// Performs a request and returns the body of a successful response; other statuses throw.
    func data(for request: URLRequest) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw CountriesError.transport(error)
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw CountriesError.invalidResponse
        }
        let url = request.url ?? configuration.baseURL
        switch http.statusCode {
        case 200..<300:
            return result.0
        case 404:
            throw CountriesError.notFound(url: url)
        default:
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: result.0))?.message
            throw CountriesError.http(statusCode: http.statusCode, message: message, url: url)
        }
    }
}

/// The API answers an array almost everywhere, but `/alpha/{code}` with `fields` answers a
/// single object. Both are read as an array.
struct OneOrMany<Item: Decodable>: Decodable {
    let items: [Item]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let many = try? container.decode([Item].self) {
            items = many
        } else {
            items = [try container.decode(Item.self)]
        }
    }
}
