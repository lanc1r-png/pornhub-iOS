//
//  VideoScraper.swift
//  ICO-visualizer
//
//  Playable stream list, uploader (channel) info and the uploader's video list.
//

import Foundation

struct StreamOption: Equatable {
    let height: Int          // 0 = adaptive "Auto"
    let url: URL
    let isHLS: Bool
    var label: String { height > 0 ? "\(height)p" : "Auto".localized }
}

struct VideoOwner {
    let kind: String         // channels | model | pornstar | users
    let slug: String
    let name: String
    let subscribers: String?
    let videosCount: String?
    var path: String { "/\(kind)/\(slug)" }
    var siteURL: URL? { URL(string: "https://www.pornhub.com" + path) }
}

struct OwnerVideo {
    let key: String
    let title: String
    let thumb: URL?
    let duration: String
    let views: String

    /// Minimal model so the regular video screen can open it.
    var asVideo: Video? {
        var json: [String: Any] = ["video_id": key, "title": title, "duration": duration]
        if let thumb = thumb { json["thumb"] = thumb.absoluteString; json["default_thumb"] = thumb.absoluteString }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? JSONDecoder().decode(Video.self, from: data)
    }
}

enum OwnerSort: Int, CaseIterable {
    case popular, newest, rated

    var title: String {
        switch self {
        case .popular: return "Popular".localized
        case .newest: return "New".localized
        case .rated: return "Top Rated".localized
        }
    }

    func code(for kind: String) -> String {
        let channelLike = kind == "channels" || kind == "users"
        switch self {
        case .popular: return channelLike ? "vi" : "mv"
        case .newest: return "mr"
        case .rated: return channelLike ? "ra" : "tr"
        }
    }
}

enum VideoScraper {

    private static let site = "https://www.pornhub.com"

    // MARK: Streams

    /// The watch page carries every quality (240p…1080p); the lightweight embed page only has 480p.
    static func loadMedia(viewKey: String, completion: @escaping ([StreamOption]) -> Void) {
        fetchWatch(viewKey: viewKey) { html in
            if let html = html {
                let parsed = streams(in: html)
                var all = parsed.found.sorted { $0.height > $1.height }
                if all.isEmpty, let master = parsed.auto { all = [StreamOption(height: 0, url: master, isHLS: true)] }
                if !all.isEmpty { completion(all); return }
            }
            loadMediaFromEmbed(viewKey: viewKey, completion: completion)
        }
    }

    // One watch-page download is shared by the stream list and the uploader lookup.
    private static var watchCache: [String: String] = [:]
    private static var watchWaiters: [String: [(String?) -> Void]] = [:]

    private static func fetchWatch(viewKey: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            if let cached = watchCache[viewKey] { completion(cached); return }
            if watchWaiters[viewKey] != nil { watchWaiters[viewKey]?.append(completion); return }
            watchWaiters[viewKey] = [completion]
            VideoExtras.fetch("\(site)/view_video.php?viewkey=\(viewKey)") { html in
                DispatchQueue.main.async {
                    if let html = html {
                        if watchCache.count > 6 { watchCache.removeAll() }
                        watchCache[viewKey] = html
                    }
                    let waiting = watchWaiters.removeValue(forKey: viewKey) ?? []
                    waiting.forEach { $0(html) }
                }
            }
        }
    }

    /// Reads the `mediaDefinitions` list out of a page.
    private static func streams(in html: String) -> (found: [StreamOption], auto: URL?, remote: URL?) {
        guard let key = html.range(of: "\"mediaDefinitions\""),
              let open = html[key.upperBound...].firstIndex(of: "["),
              let json = bracketed(html[open...]),
              let list = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] else { return ([], nil, nil) }
        var found: [StreamOption] = []
        var auto: URL?
        var remote: URL?
        for entry in list {
            guard let raw = entry["videoUrl"] as? String, !raw.isEmpty else { continue }
            let format = (entry["format"] as? String) ?? ""
            guard let url = URL(string: raw.hasPrefix("/") ? site + raw : raw) else { continue }
            if truthy(entry["remote"]) {
                if remote == nil { remote = url }
                continue
            }
            if let h = height(of: entry) {
                if let index = found.firstIndex(where: { $0.height == h }) {
                    // Prefer HLS (starts faster, seeks cheaper) over progressive files of the same height
                    if format == "hls" && !found[index].isHLS { found[index] = StreamOption(height: h, url: url, isHLS: true) }
                } else {
                    found.append(StreamOption(height: h, url: url, isHLS: format == "hls"))
                }
            } else if format == "hls", auto == nil {
                auto = url
            }
        }
        return (found, auto, remote)
    }

    private static func loadMediaFromEmbed(viewKey: String, completion: @escaping ([StreamOption]) -> Void) {
        func done(_ options: [StreamOption]) { DispatchQueue.main.async { completion(options) } }
        VideoExtras.fetch("\(site)/embed/\(viewKey)") { html in
            guard let html = html else { done([]); return }
            let parsed = streams(in: html)
            func finish(extra: [StreamOption]) {
                var all = parsed.found
                for option in extra where !all.contains(where: { $0.height == option.height }) { all.append(option) }
                all.sort { $0.height > $1.height }
                if all.isEmpty, let master = parsed.auto { all = [StreamOption(height: 0, url: master, isHLS: true)] }
                done(all)
            }
            guard let remoteURL = parsed.remote else { finish(extra: []); return }
            VideoExtras.fetch(remoteURL.absoluteString) { body in
                var extra: [StreamOption] = []
                if let body = body,
                   let array = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [[String: Any]] {
                    for entry in array {
                        guard let raw = entry["videoUrl"] as? String, let url = URL(string: raw), let h = height(of: entry) else { continue }
                        extra.append(StreamOption(height: h, url: url, isHLS: (entry["format"] as? String) == "hls"))
                    }
                }
                finish(extra: extra)
            }
        }
    }

    private static func truthy(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        return false
    }

    private static func height(of entry: [String: Any]) -> Int? {
        if let q = entry["quality"] as? String, let h = Int(q), h > 0 { return h }
        if let q = entry["quality"] as? Int, q > 0 { return q }
        return nil
    }

    /// Returns the balanced `[...]` text starting at the first character of `text`.
    private static func bracketed(_ text: Substring) -> String? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices {
            let c = text[index]
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                continue
            }
            if c == "\"" { inString = true }
            else if c == "[" { depth += 1 }
            else if c == "]" {
                depth -= 1
                if depth == 0 { return String(text[text.startIndex...index]) }
            }
        }
        return nil
    }

    // MARK: Uploader

    static func loadOwner(viewKey: String, completion: @escaping (VideoOwner?) -> Void) {
        fetchWatch(viewKey: viewKey) { html in
            var owner: VideoOwner?
            if let html = html, let r = html.range(of: "userInfoContainer") {
                let segment = String(html[r.lowerBound...].prefix(4500))
                if let g = captures(#"<a[^>]+href="/(channels|model|pornstar|users)/([^"?#/]+)[^"]*"[^>]*>(.*?)</a>"#, in: segment), g.count >= 3 {
                    var name = VideoExtras.clean(g[2])
                    if name.isEmpty { name = g[1].replacingOccurrences(of: "-", with: " ").capitalized }
                    let subs = captures(#"subscribersCount"[^>]*>(.*?)</span>"#, in: segment).map { VideoExtras.clean($0[0]) }
                    let count = captures(#"videosCount"[^>]*>(.*?)</span>"#, in: segment).map { VideoExtras.clean($0[0]) }
                    owner = VideoOwner(kind: g[0], slug: g[1], name: name,
                                       subscribers: (subs?.isEmpty ?? true) ? nil : subs,
                                       videosCount: (count?.isEmpty ?? true) ? nil : count)
                }
            }
            completion(owner)
        }
    }

    // MARK: Uploader videos

    static func loadOwnerVideos(owner: VideoOwner, sort: OwnerSort, page: Int, completion: @escaping ([OwnerVideo]) -> Void) {
        func url(sorted: Bool) -> String {
            var query = "page=\(page)"
            if sorted { query = "o=\(sort.code(for: owner.kind))&" + query }
            return "\(site)\(owner.path)/videos?\(query)"
        }
        VideoExtras.fetch(url(sorted: true)) { html in
            var videos = html.map { parseVideos($0) } ?? []
            if videos.isEmpty && page == 1 {
                // The sort code may not be supported for this kind of page: retry with the site's default order
                VideoExtras.fetch(url(sorted: false)) { retry in
                    videos = retry.map { parseVideos($0) } ?? []
                    DispatchQueue.main.async { completion(videos) }
                }
                return
            }
            DispatchQueue.main.async { completion(videos) }
        }
    }

    static func parseVideos(_ html: String) -> [OwnerVideo] {
        var result: [OwnerVideo] = []
        var seen = Set<String>()
        let blocks = html.components(separatedBy: "data-video-vkey=\"").dropFirst()
        for block in blocks {
            guard let end = block.firstIndex(of: "\"") else { continue }
            let key = String(block[block.startIndex..<end])
            guard key.count > 5, !seen.contains(key) else { continue }
            let chunk = String(block.prefix(7000))

            var title = captures(#"<a[^>]*viewkey=[^>]*?title="([^"]*)""#, in: chunk)?.first
                ?? captures(#"<a[^>]*title="([^"]*)"[^>]*viewkey="#, in: chunk)?.first
                ?? captures(#"<img[^>]*alt="([^"]*)""#, in: chunk)?.first
                ?? ""
            title = VideoExtras.clean(title)
            if title.isEmpty { continue }

            var thumb: URL?
            if let tag = captures(#"(<img[^>]*videoThumb[^>]*>)"#, in: chunk)?.first {
                for name in ["data-mediumthumb", "data-thumb_url", "data-src", "src", "data-path"] {
                    guard var value = attribute(name, in: tag), !value.hasPrefix("data:"), !value.isEmpty else { continue }
                    value = value.replacingOccurrences(of: "{index}", with: "1").replacingOccurrences(of: "&amp;", with: "&")
                    if let u = URL(string: value) { thumb = u; break }
                }
            }
            let duration = VideoExtras.clean(captures(#"class="time">([^<]+)<"#, in: chunk)?.first
                ?? captures(#"class="duration">([^<]+)<"#, in: chunk)?.first ?? "")
            let views = VideoExtras.clean(captures(#"class="views">\s*<var>([^<]+)</var>"#, in: chunk)?.first ?? "")
            seen.insert(key)
            result.append(OwnerVideo(key: key, title: title, thumb: thumb, duration: duration, views: views))
        }
        return result
    }

    // MARK: Regex helpers

    private static func attribute(_ name: String, in tag: String) -> String? {
        captures("(?:^|[\\s<])" + NSRegularExpression.escapedPattern(for: name) + "=\"([^\"]*)\"", in: tag)?.first
    }

    /// All capture groups of the first match.
    static func captures(_ pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let m = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              m.numberOfRanges > 1 else { return nil }
        var groups: [String] = []
        for i in 1..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: string) { groups.append(String(string[r])) } else { groups.append("") }
        }
        return groups
    }
}
