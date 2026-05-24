import Foundation
import SwiftUI

enum L10n {
    private static let languageKey = "app.language"

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: bundle, comment: "")
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "Localizable", bundle: bundle)
    }

    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }

    private static var bundle: Bundle {
        guard
            let localization = selectedLocalization,
            let path = Bundle.module.path(forResource: localization, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .module
        }

        return bundle
    }

    private static var locale: Locale {
        guard let localization = selectedLocalization else {
            return .autoupdatingCurrent
        }

        return Locale(identifier: localization)
    }

    private static var selectedLocalization: String? {
        let language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .system
        return language.resourceLocalizationIdentifier
    }
}
