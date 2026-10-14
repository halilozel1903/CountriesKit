import Foundation
import SwiftUI
import CountriesKit
import CountriesUI

/// Scenes used by CI to capture the README screenshots on iPhone and iPad.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene loads real data and the real flag PNGs from the live APIs (restcountries.com for
/// the data, flagcdn.com for the flags it links to). Nothing is bundled and nothing falls back:
/// when a request or a flag fails, the scene never reports ready and CI fails.
enum ScreenshotScene: String {
    /// iPhone: the countries of Europe, grouped by subregion.
    case countries
    /// iPhone: the page of Türkiye (cca3 `TUR`) with its eight land borders.
    case country
    /// iPhone: the first question of the flag quiz, answered, with a fixed seed.
    case quiz
    /// iPad: the split view with the regions, the countries of Europe and Germany's page.
    case atlas

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    /// The region the list scenes show.
    static let region = Region.europe
    /// The country the `country` scene opens.
    static let countryCode = "TUR"
    /// The country the `atlas` scene selects.
    static let atlasCountryCode = "DEU"
    /// The quiz seed of the `quiz` scene, so the same flags are asked on every run.
    static let quizSeed: UInt64 = 20261012

    /// The image loader for the screenshot scenes: the network, retried a few times, and counted
    /// so the scene is only reported ready once every flag on screen has loaded.
    static let imageLoader = FlagImageLoader { url in
        await ScreenshotImageTracker.shared.begin()
        var lastError: any Error = URLError(.unknown)
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if Task.isCancelled { break }
            do {
                let data = try await FlagImageLoader.urlSession.data(for: url)
                await ScreenshotImageTracker.shared.end(failed: false)
                return data
            } catch {
                lastError = error
                screenshotLog("Screenshot image \(url) failed (attempt \(attempt + 1) of 4): \(error)")
            }
        }
        // A view that went away cancels its load; that is not a failure.
        await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
        throw lastError
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed { state.failed += 1 }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until no image load started or finished for `quiet` seconds, and with
    /// `expectsImages` until at least one image has loaded. Returns false, and the scene is never
    /// reported ready, when an image failed to load.
    static func waitUntilSettled(expectsImages: Bool, quiet: TimeInterval = 2.5) async -> Bool {
        var lastReport = Date()
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                screenshotLog("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started > 0 || !expectsImages,
               state.inFlight == 0,
               Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            if Date().timeIntervalSince(lastReport) >= 10 {
                lastReport = Date()
                screenshotLog("Screenshot scene: waiting for flags (started \(state.started), in flight \(state.inFlight))")
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true (the data has loaded) and every flag the
    /// scene shows has loaded too. Nothing is written when loading fails, so CI fails instead of
    /// committing a broken capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool, expectsImages: Bool = true) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            screenshotLog("Screenshot scene \(scene.rawValue): data loaded, waiting for its flags")
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1))
            guard await ScreenshotImageTracker.waitUntilSettled(expectsImages: expectsImages), !Task.isCancelled else {
                return
            }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            do {
                try scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
                screenshotLog("Screenshot scene \(scene.rawValue) is ready")
            } catch {
                screenshotLog("Could not write the screenshot marker: \(error)")
            }
        }
    }
}

/// Prints a line and, in a screenshot scene, also appends it to `screenshot-log.txt` in the
/// temporary directory. scripts/screenshots.sh prints that file when a scene does not become
/// ready, since the app's console is not reliably captured on CI.
func screenshotLog(_ message: String) {
    print(message)
    guard ScreenshotScene.current != nil else { return }
    ScreenshotLog.append(message)
}

enum ScreenshotLog {
    private static let lock = NSLock()

    static var url: URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-log.txt")
    }

    static func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = Data((message + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }
}
