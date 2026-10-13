import Foundation

/// A country or territory as REST Countries v3.1 sends it.
///
/// Every property is optional: with a `fields` filter the API sends only the fields you asked
/// for, and some countries leave fields out (Antarctica has no capital, many have no `gini`).
/// Decoding is lenient field by field, so one field of an unexpected shape becomes `nil` instead
/// of failing the whole list. Property names match the JSON keys, and the model encodes back to
/// the API's shape.
///
/// The extensions add the values apps usually want: ``commonName``, ``flagEmoji``,
/// ``coordinate``, ``currencyList``, ``languageList``, ``latestGini``, ``drivingSide`` and more.
public struct Country: Codable, Hashable, Sendable, Identifiable {
    /// Common, official and native names.
    public var name: CountryName?
    /// Top-level internet domains, such as `[".tr"]`.
    public var tld: [String]?
    /// ISO 3166-1 alpha-2 code, such as `TR`.
    public var cca2: String?
    /// ISO 3166-1 numeric code, such as `792`.
    public var ccn3: String?
    /// ISO 3166-1 alpha-3 code, such as `TUR`.
    public var cca3: String?
    /// International Olympic Committee code.
    public var cioc: String?
    /// Whether the country is independent (ISO 3166-1).
    public var independent: Bool?
    /// ISO 3166-1 assignment status, such as `officially-assigned`.
    public var status: String?
    /// Whether the country is a member of the United Nations.
    public var unMember: Bool?
    /// Currencies by ISO 4217 code. See ``currencyList``.
    public var currencies: [String: Currency]?
    /// International direct dialing. See ``callingCodes``.
    public var idd: CallingCode?
    /// Capital cities; some countries have several, some none.
    public var capital: [String]?
    /// Alternative spellings and short names.
    public var altSpellings: [String]?
    /// The UN demographic region, such as `Asia`. See ``regionValue``.
    public var region: String?
    /// The UN demographic subregion, such as `Western Asia`.
    public var subregion: String?
    /// Official languages by ISO 639-3 code, such as `["tur": "Turkish"]`. See ``languageList``.
    public var languages: [String: String]?
    /// The name in other languages, by ISO 639-3 code.
    public var translations: [String: TranslatedName]?
    /// Latitude and longitude. See ``coordinate``.
    public var latlng: [Double]?
    /// Whether the country has no coastline.
    public var landlocked: Bool?
    /// The cca3 codes of the countries it shares a land border with.
    public var borders: [String]?
    /// Area in square kilometres.
    public var area: Double?
    /// What its people are called, by language code (`eng`, `fra`).
    public var demonyms: [String: Demonym]?
    /// The flag emoji. See ``flagEmoji``, which also works without this field.
    public var flag: String?
    /// Links to Google Maps and OpenStreetMap.
    public var maps: Maps?
    /// Population.
    public var population: Int?
    /// World Bank Gini index by year. See ``latestGini``.
    public var gini: [String: Double]?
    /// FIFA code.
    public var fifa: String?
    /// Car distinguishing signs and the side of the road it drives on.
    public var car: Car?
    /// Time zones, such as `["UTC+03:00"]`.
    public var timezones: [String]?
    /// Continents; a few countries are on two.
    public var continents: [String]?
    /// Flag images: a PNG (320 px wide), an SVG and a description.
    public var flags: ImageLinks?
    /// Coat of arms images, when there is one.
    public var coatOfArms: ImageLinks?
    /// The first day of the week, such as `monday`.
    public var startOfWeek: String?
    /// Where the capital is.
    public var capitalInfo: CapitalInfo?
    /// Postal code format and pattern.
    public var postalCode: PostalCode?

    /// A stable identifier: the cca3 code, else cca2, else the common name.
    public var id: String {
        cca3 ?? cca2 ?? ccn3 ?? name?.common ?? ""
    }

    public init(
        name: CountryName? = nil,
        tld: [String]? = nil,
        cca2: String? = nil,
        ccn3: String? = nil,
        cca3: String? = nil,
        cioc: String? = nil,
        independent: Bool? = nil,
        status: String? = nil,
        unMember: Bool? = nil,
        currencies: [String: Currency]? = nil,
        idd: CallingCode? = nil,
        capital: [String]? = nil,
        altSpellings: [String]? = nil,
        region: String? = nil,
        subregion: String? = nil,
        languages: [String: String]? = nil,
        translations: [String: TranslatedName]? = nil,
        latlng: [Double]? = nil,
        landlocked: Bool? = nil,
        borders: [String]? = nil,
        area: Double? = nil,
        demonyms: [String: Demonym]? = nil,
        flag: String? = nil,
        maps: Maps? = nil,
        population: Int? = nil,
        gini: [String: Double]? = nil,
        fifa: String? = nil,
        car: Car? = nil,
        timezones: [String]? = nil,
        continents: [String]? = nil,
        flags: ImageLinks? = nil,
        coatOfArms: ImageLinks? = nil,
        startOfWeek: String? = nil,
        capitalInfo: CapitalInfo? = nil,
        postalCode: PostalCode? = nil
    ) {
        self.name = name
        self.tld = tld
        self.cca2 = cca2
        self.ccn3 = ccn3
        self.cca3 = cca3
        self.cioc = cioc
        self.independent = independent
        self.status = status
        self.unMember = unMember
        self.currencies = currencies
        self.idd = idd
        self.capital = capital
        self.altSpellings = altSpellings
        self.region = region
        self.subregion = subregion
        self.languages = languages
        self.translations = translations
        self.latlng = latlng
        self.landlocked = landlocked
        self.borders = borders
        self.area = area
        self.demonyms = demonyms
        self.flag = flag
        self.maps = maps
        self.population = population
        self.gini = gini
        self.fifa = fifa
        self.car = car
        self.timezones = timezones
        self.continents = continents
        self.flags = flags
        self.coatOfArms = coatOfArms
        self.startOfWeek = startOfWeek
        self.capitalInfo = capitalInfo
        self.postalCode = postalCode
    }

    enum CodingKeys: String, CodingKey {
        case name, tld, cca2, ccn3, cca3, cioc, independent, status, unMember, currencies, idd
        case capital, altSpellings, region, subregion, languages, translations, latlng, landlocked
        case borders, area, demonyms, flag, maps, population, gini, fifa, car, timezones, continents
        case flags, coatOfArms, startOfWeek, capitalInfo, postalCode
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenient(CountryName.self, .name)
        tld = c.lenient([String].self, .tld)
        cca2 = c.lenient(String.self, .cca2)
        ccn3 = c.lenient(String.self, .ccn3)
        cca3 = c.lenient(String.self, .cca3)
        cioc = c.lenient(String.self, .cioc)
        independent = c.lenient(Bool.self, .independent)
        status = c.lenient(String.self, .status)
        unMember = c.lenient(Bool.self, .unMember)
        currencies = c.lenient([String: Currency].self, .currencies)
        idd = c.lenient(CallingCode.self, .idd)
        capital = c.lenient([String].self, .capital)
        altSpellings = c.lenient([String].self, .altSpellings)
        region = c.lenient(String.self, .region)
        subregion = c.lenient(String.self, .subregion)
        languages = c.lenient([String: String].self, .languages)
        translations = c.lenient([String: TranslatedName].self, .translations)
        latlng = c.lenient([Double].self, .latlng)
        landlocked = c.lenient(Bool.self, .landlocked)
        borders = c.lenient([String].self, .borders)
        area = c.lenient(Double.self, .area)
        demonyms = c.lenient([String: Demonym].self, .demonyms)
        flag = c.lenient(String.self, .flag)
        maps = c.lenient(Maps.self, .maps)
        population = c.lenient(Int.self, .population)
        gini = c.lenient([String: Double].self, .gini)
        fifa = c.lenient(String.self, .fifa)
        car = c.lenient(Car.self, .car)
        timezones = c.lenient([String].self, .timezones)
        continents = c.lenient([String].self, .continents)
        flags = c.lenient(ImageLinks.self, .flags)
        coatOfArms = c.lenient(ImageLinks.self, .coatOfArms)
        startOfWeek = c.lenient(String.self, .startOfWeek)
        capitalInfo = c.lenient(CapitalInfo.self, .capitalInfo)
        postalCode = c.lenient(PostalCode.self, .postalCode)
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or `nil` when it is missing, `null` or of another shape.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let value = try? decodeIfPresent(type, forKey: key) else { return nil }
        return value
    }
}

/// A country's names: `{"common":"Germany","official":"Federal Republic of Germany",
/// "nativeName":{"deu":{…}}}`.
public struct CountryName: Codable, Hashable, Sendable {
    /// The everyday name, such as `Germany`.
    public var common: String
    /// The official name, such as `Federal Republic of Germany`.
    public var official: String
    /// The name in each official language, by ISO 639-3 code.
    public var nativeName: [String: TranslatedName]?

    public init(common: String, official: String, nativeName: [String: TranslatedName]? = nil) {
        self.common = common
        self.official = official
        self.nativeName = nativeName
    }

    enum CodingKeys: String, CodingKey {
        case common, official, nativeName
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let common = c.lenient(String.self, .common)
        let official = c.lenient(String.self, .official)
        guard common != nil || official != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "A name needs common or official."))
        }
        self.common = common ?? official ?? ""
        self.official = official ?? common ?? ""
        nativeName = c.lenient([String: TranslatedName].self, .nativeName)
    }
}

/// A name in one language: `{"official":"Türkiye Cumhuriyeti","common":"Türkiye"}`.
public struct TranslatedName: Codable, Hashable, Sendable {
    public var official: String
    public var common: String

    public init(official: String, common: String) {
        self.official = official
        self.common = common
    }
}

/// A currency: `{"name":"Euro","symbol":"€"}`. The code is the key it is stored under.
public struct Currency: Codable, Hashable, Sendable {
    public var name: String?
    public var symbol: String?

    public init(name: String? = nil, symbol: String? = nil) {
        self.name = name
        self.symbol = symbol
    }
}

/// International direct dialing: `{"root":"+9","suffixes":["0"]}`.
public struct CallingCode: Codable, Hashable, Sendable {
    public var root: String?
    public var suffixes: [String]?

    public init(root: String? = nil, suffixes: [String]? = nil) {
        self.root = root
        self.suffixes = suffixes
    }
}

/// What a country's people are called: `{"f":"Turkish","m":"Turkish"}`.
public struct Demonym: Codable, Hashable, Sendable {
    /// Feminine form.
    public var f: String?
    /// Masculine form.
    public var m: String?

    public init(f: String? = nil, m: String? = nil) {
        self.f = f
        self.m = m
    }

    public var feminine: String? { f }
    public var masculine: String? { m }
}

/// Map links.
public struct Maps: Codable, Hashable, Sendable {
    public var googleMaps: URL?
    public var openStreetMaps: URL?

    public init(googleMaps: URL? = nil, openStreetMaps: URL? = nil) {
        self.googleMaps = googleMaps
        self.openStreetMaps = openStreetMaps
    }

    enum CodingKeys: String, CodingKey {
        case googleMaps, openStreetMaps
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        googleMaps = c.lenientURL(.googleMaps)
        openStreetMaps = c.lenientURL(.openStreetMaps)
    }
}

/// The side of the road traffic drives on.
public enum DrivingSide: String, Codable, Hashable, Sendable, CaseIterable {
    case left
    case right
}

/// Car signs and driving side: `{"signs":["TR"],"side":"right"}`.
public struct Car: Codable, Hashable, Sendable {
    /// International vehicle registration codes.
    public var signs: [String]?
    /// The side of the road; `nil` when the API sends something else.
    public var side: DrivingSide?

    public init(signs: [String]? = nil, side: DrivingSide? = nil) {
        self.signs = signs
        self.side = side
    }

    enum CodingKeys: String, CodingKey {
        case signs, side
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        signs = c.lenient([String].self, .signs)?.filter { !$0.isEmpty }
        side = c.lenient(String.self, .side).flatMap { DrivingSide(rawValue: $0.lowercased()) }
    }
}

/// Image links for a flag or a coat of arms: `{"png":"https://flagcdn.com/w320/tr.png",
/// "svg":"https://flagcdn.com/tr.svg","alt":"…"}`. Missing or empty links are `nil`.
public struct ImageLinks: Codable, Hashable, Sendable {
    /// A PNG; for flags 320 points wide.
    public var png: URL?
    /// An SVG.
    public var svg: URL?
    /// A description of the image, for accessibility. Flags only.
    public var alt: String?

    public init(png: URL? = nil, svg: URL? = nil, alt: String? = nil) {
        self.png = png
        self.svg = svg
        self.alt = alt
    }

    enum CodingKeys: String, CodingKey {
        case png, svg, alt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        png = c.lenientURL(.png)
        svg = c.lenientURL(.svg)
        alt = c.lenient(String.self, .alt).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Whether there is no image at all (the API sends `{}` for a missing coat of arms).
    public var isEmpty: Bool {
        png == nil && svg == nil
    }

    /// A PNG flag in another width. flagcdn.com, where the API's flags live, serves
    /// `w20` to `w2560`; other hosts are left unchanged.
    public func pngURL(width: Int) -> URL? {
        guard let png = self.png, png.host == "flagcdn.com" else { return self.png }
        let widths = [20, 40, 80, 160, 320, 640, 1280, 2560]
        let chosen = widths.first(where: { $0 >= width }) ?? 2560
        var components = png.pathComponents.filter { $0 != "/" }
        guard components.count == 2, components[0].hasPrefix("w") else { return png }
        components[0] = "w" + String(chosen)
        return URL(string: "https://flagcdn.com/" + components.joined(separator: "/"))
    }
}

/// Where the capital is: `{"latlng":[39.93,32.87]}`.
public struct CapitalInfo: Codable, Hashable, Sendable {
    public var latlng: [Double]?

    public init(latlng: [Double]? = nil) {
        self.latlng = latlng
    }

    /// The capital's position, when known.
    public var coordinate: Coordinate? {
        Coordinate(latlng)
    }
}

/// Postal codes: `{"format":"#####","regex":"^(\\d{5})$"}`.
public struct PostalCode: Codable, Hashable, Sendable {
    public var format: String?
    public var regex: String?

    public init(format: String? = nil, regex: String? = nil) {
        self.format = format
        self.regex = regex
    }

    /// Whether `code` matches the country's pattern; `nil` when there is no pattern.
    public func matches(_ code: String) -> Bool? {
        guard let regex, !regex.isEmpty else { return nil }
        return code.range(of: regex, options: .regularExpression) != nil
    }
}

extension KeyedDecodingContainer {
    /// A URL sent as a string; `nil` when missing, empty or not a URL.
    func lenientURL(_ key: Key) -> URL? {
        guard let string = lenient(String.self, key)?.trimmingCharacters(in: .whitespaces), !string.isEmpty else {
            return nil
        }
        return URL(string: string)
    }
}
