import Foundation
import Testing
@testable import CountriesKit

@Suite("CountriesClient requests")
struct ClientTests {
    @Test func countryByCode() async throws {
        let stub = StubbedClient { _ in try .json("alpha-tur") }
        let turkey = try await stub.client.country(code: "TUR")

        #expect(turkey.cca3 == "TUR")
        #expect(turkey.primaryCapital == "Ankara")
        #expect(stub.lastPath == "/v3.1/alpha/TUR")
        #expect(stub.lastQuery.isEmpty)
    }

    @Test func headers() async throws {
        let stub = StubbedClient { _ in try .json("alpha-tur") }
        _ = try await stub.client.country(code: "tr")

        let request = try #require(stub.requests.last)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let agent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        #expect(agent.hasPrefix("CountriesKit"))
    }

    @Test func singleObjectWithFields() async throws {
        let stub = StubbedClient { _ in try .json("alpha-tur-fields") }
        let turkey = try await stub.client.country(code: "TUR", fields: [.name, .cca3, .flags, .population, .name])

        #expect(turkey.commonName == "Turkey")
        #expect(turkey.population == 84_339_067)
        #expect(turkey.capital == nil)
        #expect(stub.lastQueryValue("fields") == "name,cca3,flags,population")
    }

    @Test func allNeedsFields() async throws {
        let stub = StubbedClient { _ in try .json("all-quiz") }

        await #expect(throws: CountriesError.self) {
            _ = try await stub.client.all(fields: [])
        }
        let tooMany = Array(CountryField.allCases.prefix(11))
        await #expect(throws: CountriesError.self) {
            _ = try await stub.client.all(fields: tooMany)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func allSendsFields() async throws {
        let stub = StubbedClient { _ in try .json("all-quiz") }
        let countries = try await stub.client.all(fields: [.name, .flags, .name, .cca3])

        #expect(countries.count == 20)
        #expect(stub.lastPath == "/v3.1/all")
        #expect(stub.lastQueryValue("fields") == "name,flags,cca3")
    }

    @Test func listingFieldsFitAll() async throws {
        let stub = StubbedClient { _ in try .json("region-europe") }
        _ = try await stub.client.all(fields: CountryField.listing)

        #expect(CountryField.listing.count <= CountriesClient.maxFieldsForAll)
        #expect(CountryField.quiz.count <= CountriesClient.maxFieldsForAll)
        #expect(stub.requests.count == 1)
    }

    @Test func region() async throws {
        let stub = StubbedClient { _ in try .json("region-europe") }
        let europe = try await stub.client.countries(in: .europe, fields: CountryField.listing)

        #expect(europe.count == 6)
        #expect(stub.lastPath == "/v3.1/region/europe")
        #expect(stub.lastQueryValue("fields") == "name,cca2,cca3,flags,flag,capital,population,region,subregion,area")
    }

    @Test func searchEndpoints() async throws {
        let stub = StubbedClient { _ in try .json("region-europe") }

        _ = try await stub.client.countries(currency: "EUR")
        #expect(stub.lastPath == "/v3.1/currency/EUR")
        _ = try await stub.client.countries(language: "tur")
        #expect(stub.lastPath == "/v3.1/lang/tur")
        _ = try await stub.client.countries(subregion: "Western Asia")
        #expect(stub.lastPath == "/v3.1/subregion/Western Asia")
        _ = try await stub.client.countries(capital: "Ankara")
        #expect(stub.lastPath == "/v3.1/capital/Ankara")
        _ = try await stub.client.countries(demonym: "peruvian")
        #expect(stub.lastPath == "/v3.1/demonym/peruvian")
        _ = try await stub.client.countries(translation: "Alemania")
        #expect(stub.lastPath == "/v3.1/translation/Alemania")
        _ = try await stub.client.independentCountries(false, fields: [.name])
        #expect(stub.lastPath == "/v3.1/independent")
        #expect(stub.lastQueryValue("status") == "false")
        #expect(stub.lastQueryValue("fields") == "name")
        #expect(stub.requests.count == 7)
    }

    @Test func nameSearchIsEncoded() async throws {
        let stub = StubbedClient { _ in try .json("region-europe") }
        _ = try await stub.client.countries(named: " united states ", fullText: true)

        let url = try #require(stub.requests.last?.url)
        #expect(url.absoluteString.contains("/v3.1/name/united%20states?"))
        #expect(stub.lastQueryValue("fullText") == "true")

        _ = try await stub.client.countries(named: "a/b?c")
        let encoded = try #require(stub.requests.last?.url)
        #expect(encoded.absoluteString.hasSuffix("/v3.1/name/a%2Fb%3Fc"))
    }

    @Test func blankSearchSendsNothing() async throws {
        let stub = StubbedClient { _ in try .json("region-europe") }
        let found = try await stub.client.countries(named: "   ")

        #expect(found.isEmpty)
        #expect(stub.requests.isEmpty)
    }

    @Test func noMatchesIsEmpty() async throws {
        let stub = StubbedClient { _ in try .json("error-not-found", status: 404) }
        let found = try await stub.client.countries(named: "zzzz")

        #expect(found.isEmpty)
    }

    @Test func unknownCodeThrowsNotFound() async throws {
        let stub = StubbedClient { _ in try .json("error-not-found", status: 404) }
        do {
            _ = try await stub.client.country(code: "ZZZ")
            Issue.record("Expected notFound")
        } catch let error as CountriesError {
            guard case let .notFound(url) = error else {
                Issue.record("Expected notFound")
                return
            }
            #expect(url.path == "/v3.1/alpha/ZZZ")
        }
    }

    @Test func httpErrorCarriesMessage() async throws {
        let stub = StubbedClient { _ in try .json("error-bad-request", status: 400) }
        do {
            _ = try await stub.client.countries(in: .asia)
            Issue.record("Expected an HTTP error")
        } catch let error as CountriesError {
            guard case let .http(status, message, _) = error else {
                Issue.record("Expected http")
                return
            }
            #expect(status == 400)
            #expect(message == "Bad Request")
            #expect(error.errorDescription?.contains("400") == true)
        }
    }

    @Test func transportErrors() async throws {
        let stub = StubbedClient { _ in throw URLError(.badServerResponse) }
        do {
            _ = try await stub.client.country(code: "TUR")
            Issue.record("Expected a transport error")
        } catch let error as CountriesError {
            guard case .transport = error else {
                Issue.record("Expected transport")
                return
            }
        }
    }

    @Test func errorObjectWithSuccessStatusThrows() async throws {
        let stub = StubbedClient { _ in .raw(#"{"status":400,"message":"Bad Request"}"#) }
        do {
            _ = try await stub.client.countries(in: .europe, fields: CountryField.listing)
            Issue.record("Expected an HTTP error")
        } catch let error as CountriesError {
            guard case let .http(status, message, _) = error else {
                Issue.record("Expected http")
                return
            }
            #expect(status == 400)
            #expect(message == "Bad Request")
        }
    }

    @Test func errorsArrayWithSuccessStatusThrows() async throws {
        let stub = StubbedClient { _ in .raw(#"{"success":false,"data":null,"errors":[{"message":"This API version has been deprecated."}]}"#) }
        do {
            _ = try await stub.client.country(code: "TUR")
            Issue.record("Expected an HTTP error")
        } catch let error as CountriesError {
            guard case let .http(_, message, _) = error else {
                Issue.record("Expected http")
                return
            }
            #expect(message == "This API version has been deprecated.")
        }
    }

    @Test func undecodableBody() async throws {
        let stub = StubbedClient { _ in .raw("not json") }
        do {
            _ = try await stub.client.countries(in: .asia)
            Issue.record("Expected a decoding error")
        } catch let error as CountriesError {
            guard case .decoding = error else {
                Issue.record("Expected decoding")
                return
            }
        }
    }

    @Test func bordersKeepTheirOrder() async throws {
        let stub = StubbedClient { request in
            try request.url?.path == "/v3.1/alpha/TUR" ? .json("alpha-tur") : .json("alpha-codes-tur-borders")
        }
        let turkey = try await stub.client.country(code: "TUR")
        let neighbours = try await stub.client.borders(of: turkey, fields: CountryField.compact)

        let ids = neighbours.map(\.id)
        let expected: [String] = ["ARM", "AZE", "BGR", "GEO", "GRC", "IRN", "IRQ", "SYR"]
        #expect(ids == expected)
        #expect(stub.lastPath == "/v3.1/alpha")
        #expect(stub.lastQueryValue("codes") == "ARM,AZE,BGR,GEO,GRC,IRN,IRQ,SYR")
        #expect(stub.lastQueryValue("fields") == "name,cca2,cca3,flags,flag")
    }

    @Test func codesAreDeduplicatedAndOrdered() async throws {
        let stub = StubbedClient { _ in try .json("alpha-codes-tur-borders") }
        let found = try await stub.client.countries(codes: ["grc", "ARM", "GRC", " ", "ir"], fields: [.name])

        let ids = found.prefix(3).map(\.id)
        let expected: [String] = ["GRC", "ARM", "IRN"]
        #expect(ids == expected)
        #expect(stub.lastQueryValue("codes") == "GRC,ARM,IR")
        // No code field was asked for, so cca3 is added to keep the order.
        #expect(stub.lastQueryValue("fields") == "name,cca3")
    }

    @Test func longCodeListsAreSplit() async throws {
        let stub = StubbedClient { _ in .raw("[]") }
        let codes = (0..<120).map { "C" + String($0) }
        let found = try await stub.client.countries(codes: codes)

        #expect(found.isEmpty)
        #expect(stub.requests.count == 3)
    }

    @Test func islandHasNoBorders() async throws {
        let stub = StubbedClient { _ in .raw("[]") }
        let iceland = Country(cca3: "ISL", borders: [])
        let neighbours = try await stub.client.borders(of: iceland)

        #expect(neighbours.isEmpty)
        #expect(stub.requests.isEmpty)
    }

    @Test func customPath() async throws {
        struct Named: Decodable { let name: CountryName }
        let stub = StubbedClient { _ in try .json("region-europe") }
        let names = try await stub.client.get(["region", "europe"], query: [URLQueryItem(name: "fields", value: "name")], as: [Named].self)

        #expect(names.first?.name.common == "Germany")
        #expect(stub.lastPath == "/v3.1/region/europe")
    }
}
