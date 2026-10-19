import Foundation

/// An async client for country data: the open
/// [mledoze/countries](https://github.com/mledoze/countries) dataset, loaded live from jsDelivr,
/// with flag images from flagcdn.com.
///
/// No API key is needed. The first call downloads the whole dataset (one JSON file, about 250
/// countries and territories) and keeps it in memory for
/// ``CountriesConfiguration/cacheLifetime``; every lookup and search after that is answered from
/// memory. Calls made while the download runs share it.
///
/// ```swift
/// let api = CountriesClient()
/// let turkey = try await api.country(code: "TUR")
/// let neighbours = try await api.borders(of: turkey)
/// let europe = try await api.countries(in: .europe)
/// ```
public struct CountriesClient: Sendable {
    /// A client with the default configuration.
    public static let shared = CountriesClient()

    public let configuration: CountriesConfiguration
    private let cache = DatasetCache()

    public init(configuration: CountriesConfiguration = CountriesConfiguration()) {
        self.configuration = configuration
    }

    // MARK: - Lookups

    /// Every country and territory, in the dataset's order (by cca3 code).
    public func all() async throws -> [Country] {
        let configuration = self.configuration
        return try await cache.countries(maxAge: configuration.cacheLifetime) {
            try await Self.download(configuration)
        }
    }

    /// Loads the dataset again now, even when the cached copy is still fresh.
    @discardableResult
    public func reload() async throws -> [Country] {
        await cache.clear()
        return try await all()
    }

    /// One country by its cca2 (`TR`), cca3 (`TUR`), ccn3 (`792`) or cioc code, ignoring case.
    /// Throws ``CountriesError/notFound(code:)`` when no country has the code.
    public func country(code: String) async throws -> Country {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            throw CountriesError.invalidRequest("A country code is needed, such as TR or TUR.")
        }
        guard let country = try await all().first(where: { Self.has($0, code: code) }) else {
            throw CountriesError.notFound(code: code)
        }
        return country
    }

    /// Several countries by code (any mix of cca2, cca3, ccn3 and cioc), in the order of `codes`.
    /// Duplicates and unknown codes are dropped.
    public func countries(codes: [String]) async throws -> [Country] {
        var seen = Set<String>()
        let wanted = codes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !wanted.isEmpty else { return [] }
        let index = try await all().indexedByCode()
        var found = Set<String>()
        return wanted.compactMap { code in
            guard let country = index[code], found.insert(country.id).inserted else { return nil }
            return country
        }
    }

    /// Countries whose common, official or native name contains `name`, ignoring case and
    /// accents. With `fullText`, only an exact common or official name matches.
    public func countries(named name: String, fullText: Bool = false) async throws -> [Country] {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        return try await all().filter { country in
            guard let names = country.name else { return false }
            if fullText {
                return Self.equal(names.common, name) || Self.equal(names.official, name)
            }
            let native = (names.nativeName ?? [:]).values.flatMap { [$0.common, $0.official] }
            return ([names.common, names.official] + native).contains { Self.contains($0, name) }
        }
    }

    /// Countries that use a currency, by ISO 4217 code (`EUR`) or by name (`euro`).
    public func countries(currency: String) async throws -> [Country] {
        let currency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currency.isEmpty else { return [] }
        return try await all().filter { country in
            (country.currencies ?? [:]).contains { code, info in
                Self.equal(code, currency) || info.name.map { Self.contains($0, currency) } == true
            }
        }
    }

    /// Countries where a language is official, by ISO 639-3 code (`tur`) or by name
    /// (`Turkish`).
    public func countries(language: String) async throws -> [Country] {
        let language = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !language.isEmpty else { return [] }
        return try await all().filter { country in
            (country.languages ?? [:]).contains { code, name in
                Self.equal(code, language) || Self.equal(name, language)
            }
        }
    }

    /// The countries of a region.
    public func countries(in region: Region) async throws -> [Country] {
        try await all().filter { $0.regionValue == region }
    }

    /// The countries of a subregion, such as `Western Asia`.
    public func countries(subregion: String) async throws -> [Country] {
        let subregion = subregion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subregion.isEmpty else { return [] }
        return try await all().filter { country in
            country.subregion.map { Self.equal($0, subregion) } == true
        }
    }

    /// Countries whose capital contains `capital`, ignoring case and accents.
    public func countries(capital: String) async throws -> [Country] {
        let capital = capital.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !capital.isEmpty else { return [] }
        return try await all().filter { country in
            (country.capital ?? []).contains { Self.contains($0, capital) }
        }
    }

    /// Countries by what their people are called, in any language the dataset has, such as
    /// `Peruvian`.
    public func countries(demonym: String) async throws -> [Country] {
        let demonym = demonym.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !demonym.isEmpty else { return [] }
        return try await all().filter { country in
            (country.demonyms ?? [:]).values.contains { forms in
                [forms.f, forms.m].compactMap { $0 }.contains { Self.equal($0, demonym) }
            }
        }
    }

    /// Countries by a translated name, such as `Alemania`; partial names match.
    public func countries(translation: String) async throws -> [Country] {
        let translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translation.isEmpty else { return [] }
        return try await all().filter { country in
            (country.translations ?? [:]).values.contains { name in
                Self.contains(name.common, translation) || Self.contains(name.official, translation)
            }
        }
    }

    /// Independent countries, or with `false` the territories.
    public func independentCountries(_ independent: Bool = true) async throws -> [Country] {
        try await all().filter { ($0.independent == true) == independent }
    }

    /// The countries that share a land border with `country`, in the order of its `borders`.
    /// A country without its `borders` (one you made yourself) is looked up by code first; an
    /// island answers `[]`.
    public func borders(of country: Country) async throws -> [Country] {
        var borders = country.borders
        if borders == nil, !country.id.isEmpty {
            borders = try? await self.country(code: country.id).borders
        }
        guard let borders, !borders.isEmpty else { return [] }
        return try await countries(codes: borders)
    }

    // MARK: - Matching

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func equal(_ value: String, _ query: String) -> Bool {
        value.compare(query, options: options) == .orderedSame
    }

    static func contains(_ value: String, _ query: String) -> Bool {
        value.range(of: query, options: options) != nil
    }

    static func has(_ country: Country, code: String) -> Bool {
        country.codes.contains { $0.uppercased() == code }
    }

    // MARK: - Loading

    static func download(_ configuration: CountriesConfiguration) async throws -> [Country] {
        var request = URLRequest(url: configuration.datasetURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw CountriesError.transport(error)
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw CountriesError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CountriesError.http(statusCode: http.statusCode, url: configuration.datasetURL)
        }
        return try decode(result.0)
    }

    /// The countries in the dataset file; anything but a JSON array throws
    /// ``CountriesError/decoding(description:)``.
    static func decode(_ data: Data) throws -> [Country] {
        do {
            return try JSONDecoder().decode([Country].self, from: data)
        } catch {
            let start = String(decoding: data.prefix(300), as: UTF8.self)
            throw CountriesError.decoding(description: "\(error); the body starts with: \(start)")
        }
    }
}

/// The downloaded dataset, shared by every copy of one client. Calls made while a download runs
/// wait for it instead of starting another.
actor DatasetCache {
    private var countries: [Country]?
    private var loadedAt: Date?
    private var inFlight: Task<[Country], any Error>?
    private var generation = 0

    func countries(
        maxAge: TimeInterval,
        load: @escaping @Sendable () async throws -> [Country]
    ) async throws -> [Country] {
        if let countries, let loadedAt, Date().timeIntervalSince(loadedAt) < maxAge {
            return countries
        }
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await load() }
        inFlight = task
        let started = generation
        do {
            let loaded = try await task.value
            if generation == started {
                countries = loaded
                loadedAt = Date()
                inFlight = nil
            }
            return loaded
        } catch {
            if generation == started {
                inFlight = nil
            }
            throw error
        }
    }

    /// Forgets the dataset, so the next call downloads it again.
    func clear() {
        generation += 1
        countries = nil
        loadedAt = nil
        inFlight = nil
    }
}
