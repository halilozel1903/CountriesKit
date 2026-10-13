<p align="center">
  <img src="docs/banner.svg" alt="CountriesKit: a Swift client for the REST Countries API with an iPhone and iPad atlas" width="100%">
</p>

<p align="center">
  <a href="https://github.com/halilozel1903/CountriesKit/actions/workflows/ci.yml"><img src="https://github.com/halilozel1903/CountriesKit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?logo=apple" alt="iOS 17+">
  <img src="https://img.shields.io/badge/iPadOS-17%2B-000000?logo=apple" alt="iPadOS 17+">
  <img src="https://img.shields.io/badge/REST%20Countries-v3.1-55C7F0" alt="REST Countries v3.1">
  <img src="https://img.shields.io/badge/SPM-compatible-brightgreen" alt="Swift Package Manager">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"></a>
</p>

**CountriesKit** is an async Swift client for the free [REST Countries API](https://restcountries.com) (v3.1), with SwiftUI views and a demo atlas for **iPhone and iPad**. Every endpoint (all, name, alpha and codes, currency, language, region, subregion, capital, demonym, translation, independent), the `fields` filter typed as an enum, models for every field the API sends (names with native names, flags as PNG and SVG, coat of arms, coordinates, borders, time zones, population, area, Gini, the side of the road), border resolution in one request, flag emoji, population formatting and a seeded flag quiz. No API key, no dependencies.

```swift
import CountriesKit

let api = CountriesClient()

let turkey = try await api.country(code: "TUR")
print(turkey.commonName, turkey.primaryCapital ?? "")      // name and "Ankara"
print(turkey.formattedPopulation() ?? "")                  // compact, such as "85.3M"
print(turkey.currencyList.map(\.description))              // ["Turkish lira (₺)"]

let neighbours = try await api.borders(of: turkey, fields: CountryField.compact)
print(neighbours.map(\.commonName))                        // one request for all eight

let europe = try await api.countries(in: .europe, fields: CountryField.listing)
for group in europe.groupedBySubregion() {
    print(group.name, group.countries.map(\.commonName))
}
```

## Screenshots

Captured by CI from the example app, *Atlas*, on an iPhone and an iPad simulator, with real data loaded live from [restcountries.com](https://restcountries.com) and the real flag PNGs it links to on flagcdn.com. Nothing is bundled: if the API or a flag fails to load, the capture fails instead of showing placeholder data.

| Countries by region | Country page | Flag quiz |
| :---: | :---: | :---: |
| <img src="docs/screenshots/iphone-countries.png" alt="iPhone: the countries of Europe grouped by subregion, each with its flag, capital and population, under region chips" width="250"> | <img src="docs/screenshots/iphone-country.png" alt="iPhone: the page of Türkiye (code TUR) with its flag, official and native names, facts such as capital, population, area and calling code, its language and currency, and its land borders as flag chips" width="250"> | <img src="docs/screenshots/iphone-quiz.png" alt="iPhone: the first question of a seeded flag quiz, a real flag with four country names and the right answer marked" width="250"> |

<img src="docs/screenshots/ipad-atlas.png" alt="iPad: a split view with the regions in the sidebar, the countries of Europe by subregion with their flags, and Germany's page with its facts and neighbours in the detail column" width="100%">

## Features

- **Every endpoint**: `/all`, `/name` (with `fullText`), `/alpha/{code}`, `/alpha?codes=`, `/currency`, `/lang`, `/region`, `/subregion`, `/capital`, `/demonym`, `/translation` and `/independent`. See the table below.
- **The `fields` filter, typed**: `CountryField` has a case for every field, and presets (`listing`, `quiz`, `compact`) for common screens. Duplicates are dropped. `/all` requires fields, and asking for none, or for more than ten, throws `CountriesError.invalidRequest` before anything is sent.
- **Models for everything the API sends**: `Country` with `CountryName` (common, official, native names), `ImageLinks` for `flags` and `coatOfArms` (PNG, SVG, alt text), `latlng`, `borders`, `timezones`, `population`, `area`, `gini`, `Car` with a `DrivingSide`, `CallingCode`, `Currency`, `Demonym`, `Maps`, `CapitalInfo` and `PostalCode`. Every field is optional because a `fields` filter leaves the others out, and decoding is lenient field by field: one odd value is `nil`, never a failed list. The models are `Codable` and encode back to the API's shape.
- **Borders resolved**: `borders(of:)` loads a country's neighbours in one `/alpha?codes=` request, in the order of its `borders` field. `borderCountries(in:)` does the same offline from a list you already have, and `sharesBorder(with:)` checks both sides.
- **Helpers apps need**: `flagEmoji` (from the `flag` field, or made from `cca2` with `FlagEmoji`), `primaryCapital`, `regionValue`, `coordinate` and `distance(to:)`, `currencyList`, `languageList`, `nativeNames`, `translatedName(_:)`, `latestGini`, `callingCodes` and `primaryCallingCode`, `populationDensity`, `demonym`, and flag PNGs in any width with `pngURL(width:)`.
- **Formatting**: `CountryFormat.population` writes `84.3M`, `84.3 million` or `84,339,067`, and there is formatting for area (`783,562 km²`), density, distance and the Gini index, all for any locale.
- **Lists**: `groupedBySubregion()`, `sortedByName()` (ignoring case and accents, so Åland Islands sorts with the A's), `matching(_:)` for search by name, capital, alternative spelling or code ("turkiye" finds Türkiye), `indexedByCode()` and `totalPopulation`.
- **A seeded flag quiz**: `FlagQuiz` makes questions from real countries with a `SeededGenerator` (SplitMix64, with its own shuffle), so the same seed gives the same flags and option order on every device and Swift version. Wrong answers come from the same region to make it harder.
- **Errors you can act on**: a search with no matches is an empty array, not an error; a single lookup throws `notFound`; other statuses throw `http` with the API's message.
- **Optional SwiftUI**: the `CountriesUI` library has `FlagImage` (fits any flag shape, with the emoji while it loads and a swappable loader), `CountryRow` and `CountryChip`. The client works without it.
- **Testable and Swift 6 ready**: point the client at any `URLSession` and base URL. The package's own tests answer every request from a `URLProtocol` stub and hand-written fixtures, never the network. The client is `Sendable`; tested with Swift Testing on macOS and on an iOS simulator.

## API coverage

| Endpoint | Method |
| --- | --- |
| `GET /all?fields=` | `all(fields:)` → `[Country]` (fields required, at most 10) |
| `GET /name/{name}?fullText=` | `countries(named:fullText:fields:)` → `[Country]` |
| `GET /alpha/{code}` | `country(code:fields:)` → `Country` (cca2, cca3, ccn3 or cioc) |
| `GET /alpha?codes=` | `countries(codes:fields:)` → `[Country]` in the order asked |
| `GET /currency/{currency}` | `countries(currency:fields:)` |
| `GET /lang/{language}` | `countries(language:fields:)` |
| `GET /region/{region}` | `countries(in:fields:)` with a `Region` |
| `GET /subregion/{subregion}` | `countries(subregion:fields:)` |
| `GET /capital/{capital}` | `countries(capital:fields:)` |
| `GET /demonym/{demonym}` | `countries(demonym:fields:)` |
| `GET /translation/{name}` | `countries(translation:fields:)` |
| `GET /independent?status=` | `independentCountries(_:fields:)` |
| a country's `borders` | `borders(of:fields:)` → `[Country]`, one request |
| anything else | `get(_:query:as:)` decodes any path into your own `Decodable` |

Every method takes an optional `fields: [CountryField]`; pass only what you show and responses get much smaller.

## Installation

In Xcode choose **File › Add Package Dependencies…** and enter:

```
https://github.com/halilozel1903/CountriesKit
```

Or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/halilozel1903/CountriesKit", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "CountriesKit", package: "CountriesKit"),
        .product(name: "CountriesUI", package: "CountriesKit"),   // optional SwiftUI views
    ])
]
```

## Usage

### Looking countries up

```swift
let api = CountriesClient.shared

let japan = try await api.country(code: "JP")                  // cca2, cca3, ccn3 or cioc
let few = try await api.countries(codes: ["DEU", "fr", "380"])  // in this order
let found = try await api.countries(named: "united")            // every partial match
let exact = try await api.countries(named: "Germany", fullText: true)
let euro = try await api.countries(currency: "EUR", fields: [.name, .flags])
let spanish = try await api.countries(language: "spa", fields: CountryField.listing)
let westAsia = try await api.countries(subregion: "Western Asia")
let territories = try await api.independentCountries(false, fields: [.name, .cca3])

let nobody = try await api.countries(named: "zzzz")             // [] , not an error
```

### Only the fields you need

```swift
// /all requires fields, ten at most.
let everyFlag = try await api.all(fields: [.name, .cca3, .flags])

// Presets for common screens.
CountryField.listing   // name, codes, flags, capital, population, region, subregion, area
CountryField.quiz      // what FlagQuiz needs
CountryField.compact   // name, codes and flags, for chips
```

Properties you did not ask for are `nil`.

### The model

```swift
let turkey = try await api.country(code: "TUR")

turkey.name?.official                    // official name
turkey.nativeNames                       // [LocalizedCountryName], one per official language
turkey.translatedName("deu")?.common     // the German name
turkey.flags?.png                        // https://flagcdn.com/w320/tr.png
turkey.flags?.pngURL(width: 640)         // a sharper PNG from flagcdn.com
turkey.flags?.alt                        // a description of the flag for VoiceOver
turkey.flagEmoji                         // "🇹🇷", from `flag` or made from cca2
turkey.coatOfArms?.svg
turkey.coordinate                        // Coordinate(latitude: 39, longitude: 35)
turkey.capitalCoordinate
turkey.borders                           // ["ARM", "AZE", "BGR", …] as cca3 codes
turkey.timezones                         // ["UTC+03:00"]
turkey.drivingSide                       // .right
turkey.primaryCallingCode                // "+90"
turkey.currencyList                      // [CurrencyInfo(code: "TRY", name: "Turkish lira", symbol: "₺")]
turkey.languageList                      // [Language(code: "tur", name: "Turkish")]
turkey.latestGini                        // GiniIndex(year:value:), the newest year
turkey.populationDensity                 // people per km²
turkey.postalCode?.matches("06100")      // true
```

### Borders

```swift
// One request for every neighbour, in the order of `borders`.
let neighbours = try await api.borders(of: turkey, fields: CountryField.compact)

// Or offline, when you already hold every country.
let world = try await api.all(fields: [.name, .cca3, .borders, .flags])
let sameNeighbours = turkey.borderCountries(in: world)
turkey.sharesBorder(with: neighbours[0])   // true
```

An island answers `[]` without a request.

### Formatting

```swift
CountryFormat.population(84_339_067)                       // "84.3M"
CountryFormat.population(84_339_067, style: .words)        // "84.3 million"
CountryFormat.population(84_339_067, style: .full)         // "84,339,067"
CountryFormat.area(783_562)                                // "783,562 km²"
CountryFormat.density(107.6)                               // "108 per km²"
FlagEmoji.emoji(forRegionCode: "NO")                       // "🇳🇴"
```

All of them take a `locale:`.

### A flag quiz

```swift
let countries = try await api.all(fields: CountryField.quiz)
let quiz = FlagQuiz(countries: countries, questionCount: 10, optionCount: 4,
                    seed: 2026, independentOnly: true)

let question = quiz.questions[0]
question.answer.flagURL            // the flag to show
question.options                   // four countries, the answer among them
question.isCorrect(question.options[1])
quiz.score([1: question.options[1]])
```

The same countries and seed always give the same quiz, so you can offer a daily challenge by seeding with the date. The demo app does.

### SwiftUI

```swift
import CountriesUI

List(europe) { country in
    CountryRow(country: country)        // flag, name, capital, population
}

FlagImage(country: turkey)              // fitted, never cropped
    .frame(height: 180)

CountryChip(country: neighbour)         // small flag and name in a capsule
```

`FlagImage` loads through the `flagImageLoader` in the environment; swap in your own cache with `.flagImageLoader(FlagImageLoader { url in … })`.

### Errors

```swift
do {
    _ = try await api.country(code: "ZZZ")
} catch CountriesError.notFound(let url) {
    print("No country at", url)
} catch CountriesError.http(let status, let message, _) {
    print(status, message ?? "")
} catch CountriesError.transport(let error) {
    print("Offline?", error.code)
}
```

### Testing your code

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MyStubProtocol.self]
let api = CountriesClient(configuration: CountriesConfiguration(
    baseURL: URL(string: "https://stub.test/v3.1")!,
    session: URLSession(configuration: configuration)
))
```

## Example app

`Example/` holds *Atlas*, a SwiftUI app for iPhone and iPad built with this package. On iPhone it has tabs for the countries of each region (grouped by subregion, with search) and the flag quiz; on iPad a three-column split view with regions, countries and the country page. Country pages show the flag, names, facts, languages, currencies and land borders, and every neighbour opens its own page.

```bash
brew install xcodegen
cd Example && xcodegen generate && open CountriesAtlas.xcodeproj
```

## Requirements

- Swift 6.2, Xcode 26
- iOS 17 and iPadOS 17 or later (macOS 14 for running the tests)

## Credits

Country data from [REST Countries](https://restcountries.com) (an open source project; please be gentle with the free service). Flag images are served by flagcdn.com, where the API links to. This package is not affiliated with either.

## License

MIT. See [LICENSE](LICENSE).
