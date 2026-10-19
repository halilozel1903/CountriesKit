import Foundation
import Testing
@testable import CountriesKit

@Suite("CountriesClient")
struct ClientTests {
    // MARK: - Loading and caching

    @Test func loadsTheDatasetOnce() async throws {
        let stub = StubbedClient.dataset()
        let all = try await stub.client.all()
        _ = try await stub.client.country(code: "TUR")
        _ = try await stub.client.countries(in: .europe)

        #expect(all.count == 28)
        #expect(stub.requests.count == 1)
        let request = try #require(stub.requests.first)
        #expect(request.url?.path == "/mledoze/countries.json")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("CountriesKit") == true)
    }

    @Test func concurrentCallsShareOneDownload() async throws {
        let stub = StubbedClient.dataset()
        async let one = stub.client.all()
        async let two = stub.client.country(code: "DEU")
        async let three = stub.client.countries(in: .asia)
        let (all, germany, asia) = try await (one, two, three)

        #expect(all.count == 28)
        #expect(germany.id == "DEU")
        #expect(asia.count == 8)
        #expect(stub.requests.count == 1)
    }

    @Test func reloadAndExpiryDownloadAgain() async throws {
        let stub = StubbedClient.dataset()
        _ = try await stub.client.all()
        try await stub.client.reload()
        #expect(stub.requests.count == 2)

        let expiring = StubbedClient.dataset(cacheLifetime: 0)
        _ = try await expiring.client.all()
        _ = try await expiring.client.all()
        #expect(expiring.requests.count == 2)
    }

    @Test func failuresAreNotCached() async throws {
        let counter = Counter()
        let stub = StubbedClient { _ in
            if counter.next() == 1 {
                return .status(503)
            }
            return try .json("countries")
        }
        do {
            _ = try await stub.client.all()
            Issue.record("Expected an HTTP error")
        } catch let error as CountriesError {
            guard case let .http(status, url) = error else {
                Issue.record("Expected http, got \(error)")
                return
            }
            #expect(status == 503)
            #expect(url.lastPathComponent == "countries.json")
            #expect(error.errorDescription?.contains("503") == true)
        }
        let all = try await stub.client.all()
        #expect(all.count == 28)
        #expect(stub.requests.count == 2)
    }

    @Test func transportErrors() async throws {
        let stub = StubbedClient { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await stub.client.country(code: "TUR")
            Issue.record("Expected a transport error")
        } catch let error as CountriesError {
            guard case .transport = error else {
                Issue.record("Expected transport, got \(error)")
                return
            }
        }
    }

    @Test func aBodyThatIsNotAListThrows() async throws {
        // What the retired REST Countries v3.1 URLs answer now.
        let notice = #"{"success":false,"data":null,"errors":[{"message":"This API version has been deprecated."}]}"#
        let stub = StubbedClient { _ in .raw(notice) }
        do {
            _ = try await stub.client.countries(in: .europe)
            Issue.record("Expected a decoding error")
        } catch let error as CountriesError {
            guard case let .decoding(description) = error else {
                Issue.record("Expected decoding, got \(error)")
                return
            }
            #expect(description.contains("deprecated"))
        }

        let garbage = StubbedClient { _ in .raw("not json") }
        await #expect(throws: CountriesError.self) {
            _ = try await garbage.client.all()
        }
    }

    // MARK: - Lookups

    @Test func countryByAnyCode() async throws {
        let stub = StubbedClient.dataset()

        #expect(try await stub.client.country(code: "TUR").commonName == "Türkiye")
        #expect(try await stub.client.country(code: " tr ").id == "TUR")
        #expect(try await stub.client.country(code: "792").id == "TUR")
        #expect(try await stub.client.country(code: "XK").commonName == "Kosovo")
        #expect(try await stub.client.country(code: "kos").id == "UNK")
    }

    @Test func unknownAndBlankCodes() async throws {
        let stub = StubbedClient.dataset()
        do {
            _ = try await stub.client.country(code: "zzz")
            Issue.record("Expected notFound")
        } catch let error as CountriesError {
            #expect(error == .notFound(code: "ZZZ"))
        }
        await #expect(throws: CountriesError.self) {
            _ = try await stub.client.country(code: "  ")
        }
    }

    @Test func codesKeepTheirOrder() async throws {
        let stub = StubbedClient.dataset()
        let found = try await stub.client.countries(codes: ["DEU", "fr", "380", "DEU", "ZZ", "276", " "])

        let expected: [String] = ["DEU", "FRA", "ITA"]
        #expect(found.map(\.id) == expected)
        #expect(try await stub.client.countries(codes: []).isEmpty)
    }

    @Test func nameSearch() async throws {
        let stub = StubbedClient.dataset()

        let expectedUnited: [String] = ["MEX", "USA"]
        #expect(try await stub.client.countries(named: "united").map(\.id) == expectedUnited)
        #expect(try await stub.client.countries(named: "turk").map(\.id) == ["TUR"])
        #expect(try await stub.client.countries(named: "Türkiye Cumhuriyeti").map(\.id) == ["TUR"])
        #expect(try await stub.client.countries(named: "germany", fullText: true).map(\.id) == ["DEU"])
        #expect(try await stub.client.countries(named: "germ", fullText: true).isEmpty)
        #expect(try await stub.client.countries(named: "zzzz").isEmpty)
        #expect(try await stub.client.countries(named: " ").isEmpty)
    }

    @Test func searches() async throws {
        let stub = StubbedClient.dataset()
        let client = stub.client

        let euro: [String] = ["ALA", "BGR", "DEU", "ESP", "FRA", "GRC", "ITA", "UNK", "VAT"]
        #expect(try await client.countries(currency: "eur").map(\.id) == euro)
        #expect(try await client.countries(currency: "Euro").map(\.id) == euro)
        let spanish: [String] = ["ESP", "MEX", "PER"]
        #expect(try await client.countries(language: "spa").map(\.id) == spanish)
        #expect(try await client.countries(language: "Spanish").map(\.id) == spanish)
        let westernAsia: [String] = ["ARM", "AZE", "GEO", "IRQ", "SYR", "TUR"]
        #expect(try await client.countries(subregion: "western asia").map(\.id) == westernAsia)
        let ber: [String] = ["AUS", "CHE", "DEU"]
        #expect(try await client.countries(capital: "ber").map(\.id) == ber)
        #expect(try await client.countries(demonym: "peruvian").map(\.id) == ["PER"])
        #expect(try await client.countries(translation: "Alemania").map(\.id) == ["DEU"])
        #expect(try await client.countries(in: .europe).count == 12)
        #expect(try await client.countries(in: .antarctic).map(\.id) == ["ATA"])
        #expect(try await client.independentCountries().count == 24)
        let territories: [String] = ["ALA", "ATA", "GRL", "UNK"]
        #expect(try await client.independentCountries(false).map(\.id) == territories)
        #expect(stub.requests.count == 1)
    }

    @Test func borders() async throws {
        let stub = StubbedClient.dataset()
        let turkey = try await stub.client.country(code: "TUR")
        let neighbours = try await stub.client.borders(of: turkey)

        let expected: [String] = ["ARM", "AZE", "BGR", "GEO", "GRC", "IRN", "IRQ", "SYR"]
        #expect(neighbours.map(\.id) == expected)
        #expect(neighbours.allSatisfy { $0.flagURL != nil })
        // A country without its borders is looked up first.
        #expect(try await stub.client.borders(of: Country(cca3: "TUR")).map(\.id) == expected)
        // An island.
        #expect(try await stub.client.borders(of: stub.client.country(code: "ISL")).isEmpty)
        #expect(stub.requests.count == 1)
    }
}
