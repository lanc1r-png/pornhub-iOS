//
//  VideoPreviewViewController.swift
//  ICO-visualizer
//
//  Created by Anonymous on 03/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import UIKit
import WebKit

/// Blocks the player's pre-roll ad requests (ad config endpoint + ad network hosts).
enum PlayerAdBlock {
    private static let identifier = "ico-player-adblock"
    private static var cached: WKContentRuleList?

    private static let hosts = [
        "trafficjunky\\.net", "trafficjunky\\.com", "exoclick\\.com", "exosrv\\.com", "juicyads\\.com",
        "realsrv\\.com", "magsrv\\.com", "tsyndicate\\.com", "popads\\.net", "adsterra", "clickadu\\.com",
        "doubleclick\\.net", "googlesyndication\\.com", "adnxs\\.com"
    ]
    private static let paths = ["pornhub\\.com/_xa/ads", "pornhub\\.com/_xa/ad_", "/ads\\?.*preroll"]

    private static var json: String {
        let filters = hosts + paths
        let rules = filters.map { filter -> String in
            // Regex backslashes must be escaped once more inside the JSON string
            let escaped = filter.replacingOccurrences(of: "\\", with: "\\\\")
            return #"{"trigger":{"url-filter":"\#(escaped)"},"action":{"type":"block"}}"#
        }
        // Hide leftover ad overlays inside the player
        let css = #"{"trigger":{"url-filter":".*"},"action":{"type":"css-display-none","selector":".mgp_adContainer, .mgp_adVideo, .mgp_adOverlay, [class*='adContainer'], [id*='preroll']"}}"#
        return "[" + (rules + [css]).joined(separator: ",") + "]"
    }

    static func install(on webView: WKWebView, completion: @escaping () -> Void) {
        if let list = cached {
            webView.configuration.userContentController.add(list)
            completion()
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { list, error in
            DispatchQueue.main.async {
                if let list = list {
                    cached = list
                    webView.configuration.userContentController.add(list)
                } else if let error = error {
                    print("Ad block rules failed: \(error)")
                }
                completion()
            }
        }
    }
}

/// Entry point used by the lists; the real screen is `VideoDetailViewController`.
enum VideoPreviewViewController {
    static func present(fromView: UIViewController, video: Video, delegate: TabBarViewControllerDelegate?) {
        VideoDetailViewController.present(from: fromView, video: video, delegate: delegate)
    }
}

extension RangeExpression where Bound == String.Index  {
    func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}

