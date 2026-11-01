import Foundation

enum MusicHandoff {
    static func searchURL(query: String) -> URL? {
        var parts = URLComponents(string: "https://music.youtube.com/search")
        parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        return parts?.url
    }

    static func shortcutURL(name: String, query: String) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var parts = URLComponents()
        parts.scheme = "shortcuts"
        parts.host = "run-shortcut"
        parts.queryItems = [URLQueryItem(name: "name", value: name),
                            URLQueryItem(name: "input", value: "text"),
                            URLQueryItem(name: "text", value: query)]
        return parts.url
    }
}
