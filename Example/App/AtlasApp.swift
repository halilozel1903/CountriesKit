import SwiftUI
import CountriesKit
import CountriesUI

@main
struct AtlasApp: App {
    @State private var atlas: Atlas
    private let scene = ScreenshotScene.current

    init() {
        _atlas = State(initialValue: Atlas.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            RootView(scene: scene)
                .environment(atlas)
                // Screenshot scenes count their flag loads, to report ready once all are on screen.
                .flagImageLoader(scene == nil ? FlagImageLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(.dark)
                .tint(Theme.ocean)
        }
    }
}

/// A split view with a sidebar where there is room (iPad), tabs otherwise (iPhone).
struct RootView: View {
    let scene: ScreenshotScene?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if usesSplitView {
            AtlasSplitView(scene: scene)
        } else {
            PhoneRootView(scene: scene)
        }
    }

    private var usesSplitView: Bool {
        switch scene {
        case .atlas: return true
        case .some: return false
        case nil: return horizontalSizeClass == .regular
        }
    }
}

/// iPhone: countries and the flag quiz in tabs.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case countries
        case quiz
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab
    @State private var path: [CountryRoute]

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _tab = State(initialValue: scene == .quiz ? .quiz : .countries)
        // The country scene starts on Türkiye's page, pushed without an animation.
        _path = State(initialValue: scene == .country ? [CountryRoute(code: ScreenshotScene.countryCode)] : [])
    }

    var body: some View {
        TabView(selection: $tab) {
            CountriesScreen(scene: scene, path: $path)
                .tabItem { Label("Countries", systemImage: "globe.europe.africa.fill") }
                .tag(Tab.countries)
            QuizScreen(scene: scene == .quiz ? scene : nil)
                .tabItem { Label("Flag Quiz", systemImage: "flag.checkered") }
                .tag(Tab.quiz)
        }
    }
}
