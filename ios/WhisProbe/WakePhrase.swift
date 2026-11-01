import Foundation

enum WakePhrase {
    struct Match: Equatable {
        let heardName: String
        let command: String
    }

    // Experimental speech-to-text aliases, not a trained wake-word model.
    // Keep short/common words such as "we" and "wish" out to reduce false wakes.
    static func match(_ transcript: String) -> Match? {
        let tokens = transcript.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        let offset = ["hey", "okay", "ok"].contains(tokens.first ?? "") ? 1 : 0
        guard tokens.indices.contains(offset),
              ["whis", "whees", "whiz", "wheeze", "weiss"].contains(tokens[offset]) else {
            return nil
        }
        return Match(heardName: tokens[offset], command: tokens.dropFirst(offset + 1).joined(separator: " "))
    }

    static func musicQuery(_ command: String) -> String? {
        guard command.hasPrefix("play ") else { return nil }
        var query = String(command.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if ["on youtube music", "using youtube music"].contains(query) { return nil }
        for suffix in [" on youtube music", " using youtube music"] where query.hasSuffix(suffix) {
            query = String(query.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }
        return query.isEmpty ? nil : query
    }
}
