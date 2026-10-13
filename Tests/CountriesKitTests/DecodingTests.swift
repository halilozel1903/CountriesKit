import Foundation
import Testing
@testable import CountriesKit

@Suite("Decoding")
struct DecodingTests {
    private func turkey() throws -> Country {
        let countries = try Fixture.decode([Country].self, from: "alpha-tur")
        return try #require(countries.first)
    }

    @Test func fullCountry() throws {
        let country = try turkey()

        #expect(country.id == "TUR")
        #expect(country.name?.common == "Turkey")
        #expect(country.name?.official == "Republic of Turkey")
        #expect(country.name?.nativeName?["tur"]?.common == "Türkiye")
        #expect(country.tld == [".tr"])
        #expect(country.cca2 == "TR")
        #expect(country.ccn3 == "792")
        #expect(country.cioc == "TUR")
        #expect(country.independent == true)
        #expect(country.unMember == true)
        #expect(country.status == "officially-assigned")
        #expect(country.currencies?["TRY"]?.symbol == "₺")
        #expect(country.idd?.root == "+9")
        #expect(country.region == "Asia")
        #expect(country.subregion == "Western Asia")
        #expect(country.languages?["tur"] == "Turkish")
        #expect(country.translations?["deu"]?.common == "Türkei")
        let latlng: [Double] = [39.0, 35.0]
        #expect(country.latlng == latlng)
        #expect(country.landlocked == false)
        #expect(country.borders?.count == 8)
        #expect(country.area == 783_562)
        #expect(country.flag == "🇹🇷")
        #expect(country.maps?.openStreetMaps?.host == "www.openstreetmap.org")
        #expect(country.population == 84_339_067)
        #expect(country.gini?["2019"] == 41.9)
        #expect(country.fifa == "TUR")
        #expect(country.car?.signs == ["TR"])
        #expect(country.car?.side == .right)
        #expect(country.timezones == ["UTC+03:00"])
        #expect(country.continents == ["Europe", "Asia"])
        #expect(country.flags?.png?.absoluteString == "https://flagcdn.com/w320/tr.png")
        #expect(country.flags?.svg?.absoluteString == "https://flagcdn.com/tr.svg")
        #expect(country.flags?.alt?.hasPrefix("The flag of Turkey") == true)
        #expect(country.coatOfArms?.isEmpty == false)
        #expect(country.startOfWeek == "monday")
        let capitalLatlng: [Double] = [39.93, 32.87]
        #expect(country.capitalInfo?.latlng == capitalLatlng)
        #expect(country.postalCode?.format == "#####")
    }

    @Test func partialCountry() throws {
        let country = try Fixture.decode(Country.self, from: "alpha-tur-fields")

        #expect(country.id == "TUR")
        #expect(country.flagURL != nil)
        #expect(country.borders == nil)
        #expect(country.region == nil)
        #expect(country.regionValue == nil)
        #expect(country.callingCodes.isEmpty)
    }

    @Test func oddShapesAreNil() throws {
        let countries = try Fixture.decode([Country].self, from: "odd-shapes")
        let odd = try #require(countries.first)

        #expect(odd.name?.common == "Oddland")
        #expect(odd.gini == nil)
        #expect(odd.latestGini == nil)
        #expect(odd.population == nil)
        #expect(odd.area == 12)
        #expect(odd.coordinate == nil)
        #expect(odd.car?.side == nil)
        #expect(odd.car?.signs == [])
        #expect(odd.coatOfArms?.isEmpty == true)
        #expect(odd.flags?.png == nil)
        #expect(odd.flags?.svg != nil)
        #expect(odd.flags?.alt == nil)
        #expect(odd.callingCodes.isEmpty)
        #expect(odd.primaryCallingCode == nil)
        #expect(odd.primaryCapital == nil)
        #expect(odd.flagEmoji == "🇴🇩")
    }

    @Test func sharedCallingCodeRoot() throws {
        let countries = try Fixture.decode([Country].self, from: "odd-shapes")
        let usa = try #require(countries.last)

        let expected: [String] = ["+1201", "+1202", "+1203"]
        #expect(usa.callingCodes == expected)
        #expect(usa.primaryCallingCode == "+1")
        #expect(usa.primaryCapital == "Washington, D.C.")
    }

    @Test func roundTrip() throws {
        let country = try turkey()
        let data = try JSONEncoder().encode(country)
        let decoded = try JSONDecoder().decode(Country.self, from: data)

        #expect(decoded == country)
    }

    @Test func nameNeedsCommonOrOfficial() throws {
        let json = Data(#"{"name":{"nativeName":{}},"cca3":"ABC"}"#.utf8)
        let country = try JSONDecoder().decode(Country.self, from: json)

        #expect(country.name == nil)
        #expect(country.commonName == "ABC")
    }

    @Test func oneOrMany() throws {
        let one = try JSONDecoder().decode(OneOrMany<Country>.self, from: Fixture.data("alpha-tur-fields"))
        let many = try JSONDecoder().decode(OneOrMany<Country>.self, from: Fixture.data("region-europe"))

        #expect(one.items.count == 1)
        #expect(many.items.count == 6)
    }
}
