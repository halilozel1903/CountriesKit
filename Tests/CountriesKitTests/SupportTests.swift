import Foundation
import Testing
@testable import CountriesKit

@Suite("Helpers")
struct SupportTests {
    private let english = Locale(identifier: "en_US")

    private func dataset() throws -> [Country] {
        try Fixture.decode([Country].self, from: "countries")
    }

    private func country(_ code: String) throws -> Country {
        try #require(try dataset().first { $0.cca3 == code })
    }

    @Test func flagEmoji() {
        #expect(FlagEmoji.emoji(forRegionCode: "TR") == "🇹🇷")
        #expect(FlagEmoji.emoji(forRegionCode: " de ") == "🇩🇪")
        #expect(FlagEmoji.emoji(forRegionCode: "TUR") == nil)
        #expect(FlagEmoji.emoji(forRegionCode: "1A") == nil)
        #expect(FlagEmoji.emoji(forRegionCode: "") == nil)
        #expect(FlagEmoji.regionCode(forEmoji: "🇯🇵") == "JP")
        #expect(FlagEmoji.regionCode(forEmoji: "JP") == nil)
    }

    @Test func flagEmojiFallsBackToCode() {
        let withoutField = Country(cca2: "NO")
        let withField = Country(cca2: "NO", flag: "🏳️")

        #expect(withoutField.flagEmoji == "🇳🇴")
        #expect(withField.flagEmoji == "🏳️")
        #expect(Country(cca3: "XYZ").flagEmoji == nil)
    }

    @Test func flagURLs() throws {
        let turkey = try country("TUR")

        #expect(turkey.flagURL?.absoluteString == "https://flagcdn.com/w320/tr.png")
        #expect(turkey.flagPNGURL(width: 640)?.absoluteString == "https://flagcdn.com/w640/tr.png")
        #expect(turkey.flagPNGURL(width: 100)?.absoluteString == "https://flagcdn.com/w160/tr.png")
        #expect(turkey.flagPNGURL(width: 9_999)?.absoluteString == "https://flagcdn.com/w2560/tr.png")
        #expect(turkey.flagSVGURL?.absoluteString == "https://flagcdn.com/tr.svg")
        #expect(try country("UNK").flagURL?.absoluteString == "https://flagcdn.com/w320/xk.png")
        #expect(Country(cca3: "XYZ").flagURL == nil)
        #expect(FlagCDN.pngURL(regionCode: "TUR") == nil)
        #expect(FlagCDN.pngURL(regionCode: " De ")?.absoluteString == "https://flagcdn.com/w320/de.png")
        #expect(FlagCDN.svgURL(regionCode: "1a") == nil)
    }

    @Test func numbersAndAreas() throws {
        #expect(CountryFormat.number(250, locale: english) == "250")
        #expect(CountryFormat.number(17_098_246, style: .compact, locale: english) == "17.1M")
        #expect(CountryFormat.number(999_950, style: .compact, locale: english) == "1M")
        #expect(CountryFormat.number(29_458, style: .words, locale: english) == "29.5 thousand")
        #expect(CountryFormat.number(451, style: .compact, locale: english) == "451")
        #expect(CountryFormat.area(783_562, locale: english) == "783,562 km²")
        #expect(CountryFormat.area(0.44, locale: english) == "0.44 km²")
        #expect(CountryFormat.area(783_562, style: .compact, locale: english) == "783.6K km²")
        #expect(CountryFormat.area(0.44, style: .compact, locale: english) == "0.44 km²")
        #expect(try country("TUR").formattedArea(locale: english) == "783,562 km²")
        #expect(try country("VAT").formattedArea(locale: english) == "0.44 km²")
        #expect(Country(cca3: "XYZ").formattedArea() == nil)
        #expect(CountryFormat.distance(1234.4, locale: english) == "1,234 km")
    }

    @Test func countryHelpers() throws {
        let country = try country("TUR")

        #expect(country.commonName == "Türkiye")
        #expect(country.officialName == "Republic of Türkiye")
        #expect(country.regionValue == .asia)
        #expect(country.primaryCallingCode == "+90")
        #expect(country.callingCodes == ["+90"])
        #expect(country.demonym == "Turkish")
        #expect(country.currencyList.map(\.description) == ["Turkish lira (₺)"])
        #expect(country.languageList.map(\.name) == ["Turkish"])
        #expect(country.nativeNames.first?.official == "Türkiye Cumhuriyeti")
        #expect(country.translatedName("FRA")?.common == "Turquie")
        #expect(country.translatedName("tur")?.common == "Türkiye")
        #expect(country.codes == ["TR", "TUR", "792", "TUR"])
        #expect(country.coordinate?.description == "39.0° N, 35.0° E")
    }

    @Test func sharedCallingCodeRoot() throws {
        let usa = try country("USA")

        let first: [String] = Array(usa.callingCodes.prefix(3))
        #expect(first == ["+1201", "+1202", "+1203"])
        #expect(usa.primaryCallingCode == "+1")
        #expect(usa.primaryCapital == "Washington D.C.")
    }

    @Test func distance() {
        let origin = Coordinate(latitude: 0, longitude: 0)
        let east = Coordinate(latitude: 0, longitude: 1)

        #expect(abs(origin.distance(to: east) - 111.195) < 0.01)
        #expect(origin.distance(to: origin) == 0)
        #expect(Coordinate([1]) == nil)
    }

    @Test func regions() {
        #expect(Region(named: "europe") == .europe)
        #expect(Region(named: " Americas") == .americas)
        #expect(Region(named: "Atlantis") == nil)
        #expect(Region.allCases.count == 6)
    }

    @Test func bordersFromALoadedList() throws {
        let all = try dataset()
        let turkey = try country("TUR")
        let resolved = turkey.borderCountries(in: all + all)

        let expected: [String] = ["ARM", "AZE", "BGR", "GEO", "GRC", "IRN", "IRQ", "SYR"]
        #expect(resolved.map(\.id) == expected)
        let greece = try country("GRC")
        #expect(turkey.sharesBorder(with: greece))
        #expect(greece.sharesBorder(with: turkey))
        let japan = try country("JPN")
        #expect(!turkey.sharesBorder(with: japan))
        #expect(try country("ISL").borderCountries(in: all).isEmpty)
    }

    @Test func groupingAndSorting() throws {
        let europe = try dataset().filter { $0.region == "Europe" }
        let groups = europe.groupedBySubregion()

        let names = groups.map(\.name)
        let expectedNames: [String] = ["Northern Europe", "Southeast Europe", "Southern Europe", "Western Europe"]
        #expect(names == expectedNames)
        let northern = groups[0].countries.map(\.commonName)
        let expectedNorthern: [String] = ["Åland Islands", "Iceland", "Norway"]
        #expect(northern == expectedNorthern)
        #expect(europe.sortedByName().first?.commonName == "Åland Islands")
        #expect(abs(europe.totalArea - 2_439_580.44) < 0.01)

        let unsorted = [Country(cca3: "B"), Country(cca3: "A", region: "Antarctic")]
        let fallback = unsorted.groupedBySubregion().map(\.name)
        let expectedFallback: [String] = ["Antarctic", "Other"]
        #expect(fallback == expectedFallback)
    }

    @Test func matching() throws {
        let all = try dataset().filter { $0.region == "Europe" || $0.cca3 == "TUR" }

        #expect(all.matching("turkiye").map(\.id) == ["TUR"])
        #expect(all.matching("ankara").map(\.id) == ["TUR"])
        #expect(all.matching("tr").map(\.id) == ["TUR"])
        #expect(all.matching("aland").map(\.id) == ["ALA"])
        #expect(all.matching("  ").count == 13)
    }
}
