import Foundation

/// The language hint supplied to on-device recognisers. Automatic detection is the
/// default; choosing a language improves short utterances and similarly sounding names.
public enum TranscriptionLanguage: String, CaseIterable, Sendable, Codable {
    case automatic = "auto"
    case english = "en"
    case portuguese = "pt"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case dutch = "nl"
    case danish = "da"
    case swedish = "sv"
    case finnish = "fi"
    case polish = "pl"
    case czech = "cs"
    case slovak = "sk"
    case slovenian = "sl"
    case croatian = "hr"
    case bosnian = "bs"
    case romanian = "ro"
    case hungarian = "hu"
    case estonian = "et"
    case latvian = "lv"
    case lithuanian = "lt"
    case maltese = "mt"
    case russian = "ru"
    case ukrainian = "uk"
    case belarusian = "be"
    case bulgarian = "bg"
    case serbian = "sr"
    case greek = "el"

    public var code: String? { self == .automatic ? nil : rawValue }

    public var displayName: String {
        guard self != .automatic else { return "Automatic" }
        return Locale.current.localizedString(forLanguageCode: rawValue)?.capitalized ?? rawValue
    }
}
