import SwiftUI
import CountriesKit
import CountriesUI

/// iPad: a three-column split view. The sidebar picks a region or the flag quiz, the middle
/// column lists the region's countries by subregion, and the detail column shows the selected
/// country's page.
struct AtlasSplitView: View {
    enum SidebarItem: Hashable {
        case region(Region)
        case quiz
    }

    let scene: ScreenshotScene?

    @Environment(Atlas.self) private var atlas
    @State private var sidebar: SidebarItem? = .region(ScreenshotScene.region)
    @State private var selectedCode: String?
    @State private var revealedCode: String?
    @State private var detailPath: [CountryRoute] = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(scene: ScreenshotScene?) {
        self.scene = scene
        // The atlas scene opens on Germany's page.
        _selectedCode = State(initialValue: scene == .atlas ? ScreenshotScene.atlasCountryCode : nil)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarList
        } content: {
            switch sidebar ?? .region(ScreenshotScene.region) {
            case let .region(region):
                RegionColumn(region: region, selection: $selectedCode)
            case .quiz:
                QuizView(scene: nil) { country in
                    revealedCode = country.id
                }
                .navigationTitle("Flag Quiz")
                .navigationBarTitleDisplayMode(.inline)
                .atlasNavigationBar()
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                detailRoot
                    .navigationDestination(for: CountryRoute.self) { route in
                        CountryDetailView(code: route.code, scene: nil)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: sidebar) { detailPath = [] }
        .onChange(of: selectedCode) { detailPath = [] }
        .onChange(of: revealedCode) { detailPath = [] }
    }

    private var sidebarList: some View {
        List(selection: $sidebar) {
            Section("Regions") {
                ForEach(Region.allCases) { region in
                    Label(region.name, systemImage: Theme.symbol(for: region))
                        .tag(SidebarItem.region(region))
                }
            }
            Section("Play") {
                Label("Flag Quiz", systemImage: "flag.checkered")
                    .tag(SidebarItem.quiz)
            }
            Section {
                DataCredit()
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Atlas")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
    }

    @ViewBuilder
    private var detailRoot: some View {
        switch sidebar ?? .region(ScreenshotScene.region) {
        case .region:
            if let code = selectedCode {
                CountryDetailView(code: code, scene: scene == .atlas ? scene : nil)
                    .id(code)
            } else {
                ContentUnavailableView("Choose a country", systemImage: "globe", description: Text("Pick a country to see its flag, facts and neighbours."))
            }
        case .quiz:
            if let code = revealedCode {
                CountryDetailView(code: code, scene: nil)
                    .id(code)
            } else {
                ContentUnavailableView("Name the flag", systemImage: "flag.checkered", description: Text("Answer a question to learn about the country."))
            }
        }
    }
}

/// The middle column: a region's countries by subregion, with search.
struct RegionColumn: View {
    let region: Region
    @Binding var selection: String?

    @Environment(Atlas.self) private var atlas
    @State private var query = ""

    var body: some View {
        Group {
            if let countries = atlas.regions[region] {
                List(selection: $selection) {
                    Section {
                        RegionSummary(region: region, countries: countries)
                    }
                    ForEach(countries.matching(query).groupedBySubregion()) { group in
                        Section(group.name) {
                            ForEach(group.countries) { country in
                                CountryRow(country: country)
                                    .tag(country.id)
                            }
                        }
                    }
                }
                .searchable(text: $query, prompt: "Country, capital or code")
            } else if let error = atlas.regionErrors[region] {
                LoadErrorView(message: error) {
                    Task { await atlas.load(region) }
                }
            } else {
                ProgressView("Loading " + region.name)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(region.name)
        .navigationBarTitleDisplayMode(.inline)
        .atlasNavigationBar()
        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
        .task(id: region) {
            await atlas.load(region)
        }
    }
}
