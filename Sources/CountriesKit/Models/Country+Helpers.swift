import Foundation

extension Country {
    /// The common name, such as `Germany`; the code when names were not requested.
    public var commonName: String {
        name?.common ?? cca3 ?? cca2 ?? ""
    }

    /// The official name, such as `Federal Republic of Germany`.
    public var officialName: String {
        name?.official ?? commonName
    }

    /// Every code the country has: cca2, cca3, ccn3 and cioc, when sent.
    public var codes: [String] {
        [cca2, cca3, ccn3, cioc].compactMap { $0 }.filter { !$0.isEmpty }
    }

    /// The flag emoji: the API's `flag` field, or one made from `cca2` when that field was not
    /// requested.
    public var flagEmoji: String? {
        if let flag, !flag.isEmpty {
            return flag
        }
        return cca2.flatMap { FlagEmoji.emoji(forRegionCode: $0) }
    }

    /// The flag PNG (320 points wide on flagcdn.com).
    public var flagURL: URL? {
        flags?.png
    }

    /// A description of the flag for VoiceOver, when the API has one.
    public var flagDescription: String? {
        flags?.alt
    }

    /// The first capital, such as `Ankara`.
    public var primaryCapital: String? {
        capital?.first(where: { !$0.isEmpty })
    }

    /// ``region`` as a ``Region``.
    public var regionValue: Region? {
        region.flatMap { Region(named: $0) }
    }

    /// The country's position (its rough centre).
    public var coordinate: Coordinate? {
        Coordinate(latlng)
    }

    /// The capital's position.
    public var capitalCoordinate: Coordinate? {
        capitalInfo?.coordinate
    }

    /// The name in each official language, sorted by language code.
    public var nativeNames: [LocalizedCountryName] {
        (name?.nativeName ?? [:])
            .map { LocalizedCountryName(languageCode: $0.key, common: $0.value.common, official: $0.value.official) }
            .sorted { $0.languageCode < $1.languageCode }
    }

    /// The name in another language by ISO 639-3 code (`deu`, `fra`, `jpn`…), from
    /// `translations`, falling back to the native names.
    public func translatedName(_ languageCode: String) -> TranslatedName? {
        let code = languageCode.lowercased()
        return translations?[code] ?? name?.nativeName?[code]
    }

    /// Currencies with their codes, sorted by code.
    public var currencyList: [CurrencyInfo] {
        (currencies ?? [:])
            .map { CurrencyInfo(code: $0.key, name: $0.value.name, symbol: $0.value.symbol) }
            .sorted { $0.code < $1.code }
    }

    /// Official languages with their codes, sorted by name.
    public var languageList: [Language] {
        (languages ?? [:])
            .map { Language(code: $0.key, name: $0.value) }
            .sorted { ($0.name, $0.code) < ($1.name, $1.code) }
    }

    /// The most recent Gini index.
    public var latestGini: GiniIndex? {
        (gini ?? [:])
            .compactMap { entry in Int(entry.key).map { GiniIndex(year: $0, value: entry.value) } }
            .max { $0.year < $1.year }
    }

    /// The side of the road traffic drives on.
    public var drivingSide: DrivingSide? {
        car?.side
    }

    /// Full calling codes: `["+90"]` for Türkiye, one per area code for countries that share a
    /// root (`+1201`, `+1202`… for the United States).
    public var callingCodes: [String] {
        guard let root = idd?.root, !root.isEmpty else { return [] }
        let suffixes = (idd?.suffixes ?? []).filter { !$0.isEmpty }
        return suffixes.isEmpty ? [root] : suffixes.map { root + $0 }
    }

    /// The calling code to show: root and suffix when there is one suffix (`+90`), the root
    /// alone when there are many (`+1`).
    public var primaryCallingCode: String? {
        guard let root = idd?.root, !root.isEmpty else { return nil }
        let suffixes = (idd?.suffixes ?? []).filter { !$0.isEmpty }
        return suffixes.count == 1 ? root + suffixes[0] : root
    }

    /// People per square kilometre; `nil` without population or a positive area.
    public var populationDensity: Double? {
        guard let population, let area, area > 0 else { return nil }
        return Double(population) / area
    }

    /// What the people are called in English, such as `Turkish`.
    public var demonym: String? {
        guard let english = demonyms?["eng"] else { return nil }
        return english.m ?? english.f
    }

    /// The distance between the two countries' centres in kilometres.
    public func distance(to other: Country) -> Double? {
        guard let from = coordinate, let to = other.coordinate else { return nil }
        return from.distance(to: to)
    }
}

/// A currency with its ISO 4217 code.
public struct CurrencyInfo: Hashable, Sendable, Identifiable, CustomStringConvertible {
    public var code: String
    public var name: String?
    public var symbol: String?

    public init(code: String, name: String? = nil, symbol: String? = nil) {
        self.code = code
        self.name = name
        self.symbol = symbol
    }

    public var id: String { code }

    /// `Turkish lira (₺)`, or the code when there is no name.
    public var description: String {
        let title = name ?? code
        guard let symbol, !symbol.isEmpty else { return title }
        return title + " (" + symbol + ")"
    }
}

/// A language with its ISO 639-3 code.
public struct Language: Hashable, Sendable, Identifiable {
    public var code: String
    public var name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    public var id: String { code }
}

/// A country's name in one of its official languages.
public struct LocalizedCountryName: Hashable, Sendable, Identifiable {
    public var languageCode: String
    public var common: String
    public var official: String

    public init(languageCode: String, common: String, official: String) {
        self.languageCode = languageCode
        self.common = common
        self.official = official
    }

    public var id: String { languageCode }
}

/// A World Bank Gini index for one year.
public struct GiniIndex: Hashable, Sendable {
    public var year: Int
    public var value: Double

    public init(year: Int, value: Double) {
        self.year = year
        self.value = value
    }
}
