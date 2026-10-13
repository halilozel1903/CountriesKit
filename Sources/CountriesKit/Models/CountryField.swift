import Foundation

/// A field of ``Country``, for the API's `fields` filter: `?fields=name,flags,population`.
///
/// Ask only for what you show; responses get much smaller. `/all` requires fields.
public enum CountryField: String, CaseIterable, Hashable, Sendable {
    case name, tld, cca2, ccn3, cca3, cioc, independent, status, unMember, currencies, idd
    case capital, altSpellings, region, subregion, languages, translations, latlng, landlocked
    case borders, area, demonyms, flag, maps, population, gini, fifa, car, timezones, continents
    case flags, coatOfArms, startOfWeek, capitalInfo, postalCode

    /// The code fields a country can be looked up by.
    public static let codeFields: Set<CountryField> = [.cca2, .cca3, .ccn3, .cioc]

    /// What a list row needs (10 fields, so it also works with `/all`): names, codes, the flag,
    /// capital, population, region, subregion and area.
    public static let listing: [CountryField] = [
        .name, .cca2, .cca3, .flags, .flag, .capital, .population, .region, .subregion, .area,
    ]

    /// What ``FlagQuiz`` needs: names, codes, the flag, capital, region, subregion and
    /// independence.
    public static let quiz: [CountryField] = [
        .name, .cca2, .cca3, .flags, .capital, .region, .subregion, .independent, .population,
    ]

    /// What a border chip needs: names, codes and the flag.
    public static let compact: [CountryField] = [.name, .cca2, .cca3, .flags, .flag]

    /// `fields` without duplicates, in their order.
    public static func unique(_ fields: [CountryField]) -> [CountryField] {
        var seen = Set<CountryField>()
        return fields.filter { seen.insert($0).inserted }
    }
}
