import Foundation
import Observation
import CountriesKit

/// The app's data, all from one `CountriesClient`: the mledoze/countries dataset, downloaded live
/// once and kept in memory. It holds the countries of each region, full country pages with their
/// borders, and the countries of the flag quiz.
@Observable
@MainActor
final class Atlas {
    let client: CountriesClient

    /// The countries of each loaded region.
    private(set) var regions: [Region: [Country]] = [:]
    private(set) var regionErrors: [Region: String] = [:]

    /// The quiz countries (every country; the quiz keeps the independent ones).
    private(set) var quizCountries: [Country]?
    private(set) var quizError: String?

    @ObservationIgnored private var details: [String: Country] = [:]
    @ObservationIgnored private var borders: [String: [Country]] = [:]
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    init(client: CountriesClient, attempts: Int = 1) {
        self.client = client
        self.attempts = max(1, attempts)
    }

    /// The live dataset. Screenshot scenes retry a failed download a few times, since a capture
    /// must not show an error.
    static func make(for scene: ScreenshotScene?) -> Atlas {
        Atlas(client: .shared, attempts: scene == nil ? 2 : 4)
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < attempts, !Task.isCancelled else { throw error }
                screenshotLog("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 2))
                attempt += 1
            }
        }
    }

    // MARK: - Regions

    /// Loads the countries of `region`, once (again after an error).
    func load(_ region: Region) async {
        guard regions[region] == nil else { return }
        regionErrors[region] = nil
        do {
            let client = self.client
            let countries = try await Self.retrying(attempts: attempts) {
                try await client.countries(in: region)
            }
            regions[region] = countries.sortedByName()
            screenshotLog("Loaded \(countries.count) countries of \(region.name)")
        } catch {
            guard !Task.isCancelled else { return }
            screenshotLog("Loading \(region.name) failed: \(error)")
            regionErrors[region] = error.localizedDescription
        }
    }

    /// A country from a loaded region list, for a quick first paint of its page.
    func listed(code: String) -> Country? {
        for countries in regions.values {
            if let country = countries.first(where: { $0.codes.contains(code) }) {
                return country
            }
        }
        return nil
    }

    // MARK: - Country pages

    /// One country.
    func country(code: String) async throws -> Country {
        if let cached = details[code] {
            return cached
        }
        let client = self.client
        let country = try await Self.retrying(attempts: attempts) {
            try await client.country(code: code)
        }
        details[code] = country
        return country
    }

    /// The countries that share a land border with `country`, with their flags.
    func borders(of country: Country) async throws -> [Country] {
        if let cached = borders[country.id] {
            return cached
        }
        let client = self.client
        let found = try await Self.retrying(attempts: attempts) {
            try await client.borders(of: country)
        }
        borders[country.id] = found
        return found
    }

    // MARK: - Quiz

    /// Loads the quiz countries, once (again after an error).
    func loadQuiz() async {
        guard quizCountries == nil else { return }
        quizError = nil
        do {
            let client = self.client
            let countries = try await Self.retrying(attempts: attempts) {
                try await client.all()
            }
            quizCountries = countries
            screenshotLog("Loaded \(countries.count) quiz countries")
        } catch {
            guard !Task.isCancelled else { return }
            screenshotLog("Loading the quiz failed: \(error)")
            quizError = error.localizedDescription
        }
    }

    /// Today's quiz seed: the same flags all day, new ones tomorrow.
    nonisolated static var dailySeed: UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970 / 86_400))
    }
}
