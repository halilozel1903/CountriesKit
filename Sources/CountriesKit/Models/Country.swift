import Foundation

/// A country or territory from the open [mledoze/countries](https://github.com/mledoze/countries)
/// dataset, the data REST Countries was originally built from.
///
/// Every property is optional, and decoding is lenient field by field: one field of an unexpected
/// shape becomes `nil` instead of failing the whole list. Property names match the dataset's JSON
/// keys (except ``CountryName/nativeName``, stored as `native`), and the model encodes back to the
/// dataset's shape.
///
/// The extensions add the values apps usually want: ``commonName``, ``flagURL``, ``flagEmoji``,
/// ``coordinate``, ``currencyList``, ``languageList``, ``callingCodes`` and more.
public struct Country: Codable, Hashable, Sendable, Identifiable {
    /// Common, official and native names.
    public var name: CountryName?
    /// Top-level internet domains, such as `[".tr"]`.
    public var tld: [String]?
    /// ISO 3166-1 alpha-2 code, such as `TR`. The flag images are looked up by it.
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
    /// The United Nations regional group, such as `Asia and the Pacific Group`.
    public var unRegionalGroup: String?
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
        unRegionalGroup: String? = nil,
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
        flag: String? = nil
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
        self.unRegionalGroup = unRegionalGroup
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
    }

    enum CodingKeys: String, CodingKey {
        case name, tld, cca2, ccn3, cca3, cioc, independent, status, unMember, unRegionalGroup
        case currencies, idd, capital, altSpellings, region, subregion, languages, translations
        case latlng, landlocked, borders, area, demonyms, flag
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenient(CountryName.self, .name)
        tld = c.lenient([String].self, .tld)
        cca2 = c.lenientText(.cca2)
        ccn3 = c.lenientText(.ccn3)
        cca3 = c.lenientText(.cca3)
        cioc = c.lenientText(.cioc)
        independent = c.lenient(Bool.self, .independent)
        status = c.lenientText(.status)
        unMember = c.lenient(Bool.self, .unMember)
        unRegionalGroup = c.lenientText(.unRegionalGroup)
        currencies = c.lenient([String: Currency].self, .currencies)
        idd = c.lenient(CallingCode.self, .idd)
        capital = c.lenient([String].self, .capital)
        altSpellings = c.lenient([String].self, .altSpellings)
        region = c.lenientText(.region)
        subregion = c.lenientText(.subregion)
        languages = c.lenient([String: String].self, .languages)
        translations = c.lenient([String: TranslatedName].self, .translations)
        latlng = c.lenient([Double].self, .latlng)
        landlocked = c.lenient(Bool.self, .landlocked)
        borders = c.lenient([String].self, .borders)
        area = c.lenient(Double.self, .area)
        demonyms = c.lenient([String: Demonym].self, .demonyms)
        flag = c.lenientText(.flag)
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or `nil` when it is missing, `null` or of another shape.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let value = try? decodeIfPresent(type, forKey: key) else { return nil }
        return value
    }

    /// A string for `key`; `nil` when it is missing, empty or not a string. The dataset writes
    /// `""` for values it does not have, such as the codes of Kosovo.
    func lenientText(_ key: Key) -> String? {
        guard let value = lenient(String.self, key), !value.isEmpty else { return nil }
        return value
    }
}

/// A country's names: `{"common":"Germany","official":"Federal Republic of Germany",
/// "native":{"deu":{…}}}`.
public struct CountryName: Codable, Hashable, Sendable {
    /// The everyday name, such as `Germany`.
    public var common: String
    /// The official name, such as `Federal Republic of Germany`.
    public var official: String
    /// The name in each official language, by ISO 639-3 code (the dataset's `native`).
    public var nativeName: [String: TranslatedName]?

    public init(common: String, official: String, nativeName: [String: TranslatedName]? = nil) {
        self.common = common
        self.official = official
        self.nativeName = nativeName
    }

    enum CodingKeys: String, CodingKey {
        case common, official
        case nativeName = "native"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let common = c.lenientText(.common)
        let official = c.lenientText(.official)
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
