import Foundation
import Testing
@testable import CountriesKit

@Suite("Helpers")
struct SupportTests {
    private let english = Locale(identifier: "en_US")

    private func turkey() throws -> Country {
        try #require(try Fixture.decode([Country].self, from: "alpha-tur").first)
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

    @Test func compactPopulation() {
        #expect(CountryFormat.population(84_339_067, locale: english) == "84.3M")
        #expect(CountryFormat.population(1_402_112_000, locale: english) == "1.4B")
        #expect(CountryFormat.population(12_345, locale: english) == "12.3K")
        #expect(CountryFormat.population(5_000_000, locale: english) == "5M")
        #expect(CountryFormat.population(999_950, locale: english) == "1M")
        #expect(CountryFormat.population(451, locale: english) == "451")
        #expect(CountryFormat.population(0, locale: english) == "0")
    }

    @Test func otherPopulationStyles() {
        #expect(CountryFormat.population(84_339_067, style: .full, locale: english) == "84,339,067")
        #expect(CountryFormat.population(84_339_067, style: .words, locale: english) == "84.3 million")
        #expect(CountryFormat.population(29_458, style: .words, locale: english) == "29.5 thousand")
    }

    @Test func areaAndDensity() throws {
        let country = try turkey()

        #expect(CountryFormat.area(783_562, locale: english) == "783,562 km²")
        #expect(CountryFormat.area(0.44, locale: english) == "0.44 km²")
        #expect(country.formattedArea(locale: english) == "783,562 km²")
        #expect(country.formattedPopulation(locale: english) == "84.3M")
        let density = try #require(country.populationDensity)
        #expect(abs(density - 107.635) < 0.01)
        #expect(CountryFormat.density(density, locale: english) == "108 per km²")
        #expect(CountryFormat.distance(1234.4, locale: english) == "1,234 km")
    }

    @Test func countryHelpers() throws {
        let country = try turkey()

        #expect(country.commonName == "Turkey")
        #expect(country.officialName == "Republic of Turkey")
        #expect(country.regionValue == .asia)
        #expect(country.primaryCallingCode == "+90")
        #expect(country.callingCodes == ["+90"])
        #expect(country.drivingSide == .right)
        #expect(country.demonym == "Turkish")
        #expect(country.latestGini == GiniIndex(year: 2019, value: 41.9))
        #expect(country.currencyList.map(\.description) == ["Turkish lira (₺)"])
        #expect(country.languageList.map(\.name) == ["Turkish"])
        #expect(country.nativeNames.first?.common == "Türkiye")
        #expect(country.translatedName("FRA")?.common == "Turquie")
        #expect(country.translatedName("tur")?.common == "Türkiye")
        #expect(country.codes == ["TR", "TUR", "792", "TUR"])
        #expect(country.capitalCoordinate?.latitude == 39.93)
        #expect(country.postalCode?.matches("06100") == true)
        #expect(country.postalCode?.matches("ABC") == false)
        #expect(country.coordinate?.description == "39.0° N, 35.0° E")
    }

    @Test func flagWidths() throws {
        let flags = try #require(try turkey().flags)

        #expect(flags.pngURL(width: 640)?.absoluteString == "https://flagcdn.com/w640/tr.png")
        #expect(flags.pngURL(width: 100)?.absoluteString == "https://flagcdn.com/w160/tr.png")
        #expect(flags.pngURL(width: 9_999)?.absoluteString == "https://flagcdn.com/w2560/tr.png")
        let elsewhere = ImageLinks(png: URL(string: "https://example.com/flag.png"))
        #expect(elsewhere.pngURL(width: 640)?.absoluteString == "https://example.com/flag.png")
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
        #expect(Region.oceania.pathValue == "oceania")
    }

    @Test func bordersFromALoadedList() throws {
        let country = try turkey()
        let neighbours = try Fixture.decode([Country].self, from: "alpha-codes-tur-borders")
        let resolved = country.borderCountries(in: neighbours + neighbours)

        let expected: [String] = ["ARM", "AZE", "BGR", "GEO", "GRC", "IRN", "IRQ", "SYR"]
        #expect(resolved.map(\.id) == expected)
        let greece = try #require(neighbours.first { $0.id == "GRC" })
        #expect(country.sharesBorder(with: greece))
        #expect(greece.sharesBorder(with: country))
        #expect(!country.sharesBorder(with: Country(cca3: "JPN", borders: [])))
        #expect(Country(cca3: "ISL").borderCountries(in: neighbours).isEmpty)
    }

    @Test func groupingAndSorting() throws {
        let europe = try Fixture.decode([Country].self, from: "region-europe")
        let groups = europe.groupedBySubregion()

        let names = groups.map(\.name)
        let expectedNames: [String] = ["Northern Europe", "Southern Europe", "Western Europe"]
        #expect(names == expectedNames)
        let northern = groups[0].countries.map(\.commonName)
        let expectedNorthern: [String] = ["Åland Islands", "Norway"]
        #expect(northern == expectedNorthern)
        #expect(europe.sortedByName().first?.commonName == "Åland Islands")
        #expect(europe.totalPopulation == 83_240_525 + 29_458 + 67_391_582 + 5_379_475 + 59_554_023 + 451)

        let unsorted = [Country(cca3: "B"), Country(cca3: "A", region: "Antarctic")]
        let fallback = unsorted.groupedBySubregion().map(\.name)
        let expectedFallback: [String] = ["Antarctic", "Other"]
        #expect(fallback == expectedFallback)
    }

    @Test func matching() throws {
        let country = try turkey()
        let europe = try Fixture.decode([Country].self, from: "region-europe")
        let all = europe + [country]

        #expect(all.matching("turkiye").map(\.id) == ["TUR"])
        #expect(all.matching("ankara").map(\.id) == ["TUR"])
        #expect(all.matching("tr").map(\.id) == ["TUR"])
        #expect(all.matching("aland").map(\.id) == ["ALA"])
        #expect(all.matching("  ").count == 7)
    }

    @Test func fieldPresets() {
        #expect(CountryField.unique([.name, .flags, .name]) == [.name, .flags])
        #expect(CountryField.allCases.count == 35)
        #expect(CountriesClient.fieldsQuery([]).isEmpty)
        #expect(CountriesClient.fieldsQuery([.name, .cca3]).first?.value == "name,cca3")
    }
}
