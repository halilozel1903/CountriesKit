import Foundation
import Testing
@testable import CountriesKit

@Suite("Decoding")
struct DecodingTests {
    private func dataset() throws -> [Country] {
        try Fixture.decode([Country].self, from: "countries")
    }

    private func country(_ code: String) throws -> Country {
        try #require(try dataset().first { $0.cca3 == code })
    }

    @Test func fullCountry() throws {
        let country = try country("TUR")

        #expect(country.id == "TUR")
        #expect(country.name?.common == "Türkiye")
        #expect(country.name?.official == "Republic of Türkiye")
        #expect(country.name?.nativeName?["tur"]?.official == "Türkiye Cumhuriyeti")
        #expect(country.tld == [".tr"])
        #expect(country.cca2 == "TR")
        #expect(country.ccn3 == "792")
        #expect(country.cioc == "TUR")
        #expect(country.independent == true)
        #expect(country.unMember == true)
        #expect(country.unRegionalGroup == "Western European and Others Group")
        #expect(country.status == "officially-assigned")
        #expect(country.currencies?["TRY"]?.symbol == "₺")
        #expect(country.idd?.root == "+9")
        #expect(country.capital == ["Ankara"])
        #expect(country.altSpellings?.contains("Turkiye") == true)
        #expect(country.region == "Asia")
        #expect(country.subregion == "Western Asia")
        #expect(country.languages?["tur"] == "Turkish")
        #expect(country.translations?["deu"]?.common == "Türkei")
        let latlng: [Double] = [39.0, 35.0]
        #expect(country.latlng == latlng)
        #expect(country.landlocked == false)
        #expect(country.borders?.count == 8)
        #expect(country.area == 783_562)
        #expect(country.demonyms?["fra"]?.feminine == "Turque")
        #expect(country.flag == "🇹🇷")
    }

    @Test func emptyValuesAreNil() throws {
        let kosovo = try country("UNK")
        #expect(kosovo.cca2 == "XK")
        #expect(kosovo.ccn3 == nil)
        #expect(kosovo.independent == nil)
        #expect(kosovo.codes == ["XK", "UNK", "KOS"])

        let antarctica = try country("ATA")
        #expect(antarctica.subregion == nil)
        #expect(antarctica.primaryCapital == nil)
        #expect(antarctica.borders == [])
        #expect(antarctica.regionValue == .antarctic)
    }

    @Test func oddShapesAreNil() throws {
        let json = Data(#"""
        [{"name":{"common":"Oddland","official":"Odd Republic","native":"none"},"cca2":"OD","cca3":"ODD",
          "area":"big","latlng":[1],"idd":{"root":"","suffixes":[]},"capital":[""],"borders":null,
          "currencies":[],"languages":{"odd":"Oddish"},"independent":"yes","flag":""}]
        """#.utf8)
        let odd = try #require(try JSONDecoder().decode([Country].self, from: json).first)

        #expect(odd.name?.common == "Oddland")
        #expect(odd.name?.nativeName == nil)
        #expect(odd.area == nil)
        #expect(odd.coordinate == nil)
        #expect(odd.callingCodes.isEmpty)
        #expect(odd.primaryCallingCode == nil)
        #expect(odd.primaryCapital == nil)
        #expect(odd.borders == nil)
        #expect(odd.currencies == nil)
        #expect(odd.independent == nil)
        #expect(odd.languageList.map(\.name) == ["Oddish"])
        #expect(odd.flag == nil)
        #expect(odd.flagEmoji == "🇴🇩")
    }

    @Test func roundTrip() throws {
        let country = try country("TUR")
        let data = try JSONEncoder().encode(country)
        let decoded = try JSONDecoder().decode(Country.self, from: data)

        #expect(decoded == country)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""native""#))
        #expect(!text.contains("nativeName"))
    }

    @Test func nameNeedsCommonOrOfficial() throws {
        let json = Data(#"{"name":{"native":{}},"cca3":"ABC"}"#.utf8)
        let country = try JSONDecoder().decode(Country.self, from: json)

        #expect(country.name == nil)
        #expect(country.commonName == "ABC")
    }
}
