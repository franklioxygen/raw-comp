import Foundation
import Sparkle
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system:
            "settings.theme.system"
        case .light:
            "settings.theme.light"
        case .dark:
            "settings.theme.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case chinese
    case french
    case german
    case italian
    case japanese
    case korean
    case portuguese
    case spanish

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system:
            "settings.language.system"
        case .english:
            "settings.language.english"
        case .chinese:
            "settings.language.chinese"
        case .french:
            "settings.language.french"
        case .german:
            "settings.language.german"
        case .italian:
            "settings.language.italian"
        case .japanese:
            "settings.language.japanese"
        case .korean:
            "settings.language.korean"
        case .portuguese:
            "settings.language.portuguese"
        case .spanish:
            "settings.language.spanish"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .chinese:
            Locale(identifier: "zh-Hans")
        case .french:
            Locale(identifier: "fr")
        case .german:
            Locale(identifier: "de")
        case .italian:
            Locale(identifier: "it")
        case .japanese:
            Locale(identifier: "ja")
        case .korean:
            Locale(identifier: "ko")
        case .portuguese:
            Locale(identifier: "pt")
        case .spanish:
            Locale(identifier: "es")
        }
    }

    var resourceLocalizationIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .chinese:
            "zh-Hans"
        case .french:
            "fr"
        case .german:
            "de"
        case .italian:
            "it"
        case .japanese:
            "ja"
        case .korean:
            "ko"
        case .portuguese:
            "pt"
        case .spanish:
            "es"
        }
    }

    var bundleLanguagePreferences: [String]? {
        switch self {
        case .system:
            nil
        case .english:
            ["en"]
        case .chinese:
            ["zh-Hans", "zh_CN", "zh"]
        case .french:
            ["fr"]
        case .german:
            ["de"]
        case .italian:
            ["it"]
        case .japanese:
            ["ja"]
        case .korean:
            ["ko"]
        case .portuguese:
            ["pt-PT", "pt-BR", "pt"]
        case .spanish:
            ["es"]
        }
    }

    static let mainBundleLocalizations = [
        "en",
        "zh-Hans",
        "fr",
        "de",
        "it",
        "ja",
        "ko",
        "pt-PT",
        "pt-BR",
        "es"
    ]
}

@MainActor
final class AppSettingsController: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            Self.applyBundleLanguagePreference(language)
        }
    }

    @Published private(set) var autoUpdateEnabled = false
    @Published private(set) var canManageAutoUpdate = false
    @Published private(set) var canCheckForUpdates = false

    private weak var updater: SPUUpdater?
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticChecksObservation: NSKeyValueObservation?

    init(updater: SPUUpdater?) {
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: Self.themeKey) ?? "") ?? .system
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.languageKey) ?? "") ?? .system
        Self.applyBundleLanguagePreference(language)

        connectToUpdater(updater)
    }

    var colorScheme: ColorScheme? {
        theme.colorScheme
    }

    var locale: Locale {
        language.locale
    }

    func setAutoUpdateEnabled(_ enabled: Bool) {
        guard let updater else {
            autoUpdateEnabled = false
            return
        }

        updater.automaticallyChecksForUpdates = enabled
        autoUpdateEnabled = updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        updater?.checkForUpdates()
    }

    func attachUpdater(_ updater: SPUUpdater?) {
        connectToUpdater(updater)
    }

    private func connectToUpdater(_ updater: SPUUpdater?) {
        self.updater = updater
        canCheckObservation = nil
        automaticChecksObservation = nil

        guard let updater else {
            autoUpdateEnabled = false
            canManageAutoUpdate = false
            canCheckForUpdates = false
            return
        }

        autoUpdateEnabled = updater.automaticallyChecksForUpdates
        canManageAutoUpdate = true
        canCheckForUpdates = updater.canCheckForUpdates

        automaticChecksObservation = updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in
                self?.autoUpdateEnabled = updater.automaticallyChecksForUpdates
            }
        }

        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    private static func applyBundleLanguagePreference(_ language: AppLanguage) {
        if let languages = language.bundleLanguagePreferences {
            UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    private static let themeKey = "app.theme"
    private static let languageKey = "app.language"
}
