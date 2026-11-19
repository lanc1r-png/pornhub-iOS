//
//  VideoDetailViewController.swift
//  ICO-visualizer
//
//  Modern video screen: player, actions, details, related videos and comments.
//

import UIKit
import WebKit
import AVKit
import SDWebImage
import SafariServices

// MARK: - Extra data (comments)

struct VideoComment {
    let user: String
    let avatarURL: URL?
    let date: String
    let text: String
}

enum VideoExtras {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    static let cookie = "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=mobile; hasVisited=1"

    /// Completion is called on a background queue.
    static func fetch(_ urlString: String, ajax: Bool = false, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.httpShouldHandleCookies = false
        if ajax { request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With") }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            completion(data.flatMap { String(data: $0, encoding: .utf8) })
        }.resume()
    }

    static func loadComments(viewKey: String, popular: Bool, limit: Int = 40, completion: @escaping (Result<[VideoComment], Error>) -> Void) {
        func fail(_ message: String) {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "ICO", code: 0, userInfo: [NSLocalizedDescriptionKey: message])))
            }
        }
        // The numeric video id is needed for the comments endpoint; the small embed page contains it.
        fetch("https://www.pornhub.com/embed/\(viewKey)") { html in
            guard let html = html, let id = match(#""video_id"\s*:\s*(\d+)"#, in: html) else {
                fail("Could not load comments")
                return
            }
            let url = "https://www.pornhub.com/comment/show?id=\(id)&popular=\(popular ? 1 : 0)&what=video&page=1"
            fetch(url, ajax: true) { body in
                guard let body = body else { fail("Could not load comments"); return }
                let comments = parse(body, limit: limit)
                DispatchQueue.main.async { completion(.success(comments)) }
            }
        }
    }

    static func parse(_ html: String, limit: Int) -> [VideoComment] {
        var result: [VideoComment] = []
        let blocks = html.components(separatedBy: "<div class=\"commentBlock")
        for block in blocks.dropFirst() {
            if result.count >= limit { break }
            guard let rawText = match(#"<div class="commentMessage">\s*<span>(.*?)</span>"#, in: block) else { continue }
            let text = clean(rawText)
            if text.isEmpty { continue }
            let user = clean(match(#"usernameLink"[^>]*>([^<]+)</a>"#, in: block) ?? "")
            let date = clean(match(#"<div class="date floatRight">([^<]+)</div>"#, in: block) ?? "")
            let avatar = match(#"<img class="" src="([^"]+)""#, in: block).flatMap { URL(string: $0) }
            result.append(VideoComment(user: user.isEmpty ? "—" : user, avatarURL: avatar, date: date, text: text))
        }
        return result
    }

    static func clean(_ html: String) -> String {
        var s = html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&nbsp;": " "]
        for (key, value) in entities { s = s.replacingOccurrences(of: key, with: value) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func match(_ pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let m = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              m.numberOfRanges > 1,
              let range = Range(m.range(at: 1), in: string) else { return nil }
        return String(string[range])
    }
}

// MARK: - Wrapping chips layout

final class WrapView: UIView {
    var spacing: CGFloat = 8
    private var heightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.frame = CGRect(x: x, y: y, width: min(size.width, maxWidth), height: size.height)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let total = y + rowHeight
        if heightConstraint?.constant != total {
            heightConstraint?.constant = total
        }
    }
}

// MARK: - Small building blocks

private final class ChipControl: UIControl {
    private let label = UILabel()

    init(text: String, highlighted: Bool) {
        super.init(frame: .zero)
        layer.cornerCurve = .continuous
        layer.cornerRadius = 15
        backgroundColor = highlighted ? ColorLayout.default_orange.withAlphaComponent(0.18) : UIColor.white.withAlphaComponent(0.08)
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = highlighted ? ColorLayout.default_orange : UIColor.white.withAlphaComponent(0.85)
        label.isUserInteractionEnabled = false
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: ceil(fitted.width) + 28, height: ceil(fitted.height) + 14)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 14, dy: 7)
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}

private func makeChip(_ text: String, highlighted: Bool = false) -> ChipControl {
    return ChipControl(text: text, highlighted: highlighted)
}

private func makeSectionLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
    label.textColor = UIColor.white.withAlphaComponent(0.5)
    return label
}

private final class StatTile: UIView {
    init(value: String, caption: String) {
        super.init(frame: .zero)
        applyCardStyle(cornerRadius: 18)
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class RelatedCard: UIControl {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    var onTap: (() -> Void)?

    init(video: Video) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle(cornerRadius: 20)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        imageView.isUserInteractionEnabled = false
        if let thumb = video.thumb, let url = URL(string: thumb) { imageView.sd_setImage(with: url, completed: nil) }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = video.title
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.isUserInteractionEnabled = false

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.text = video.duration
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        durationLabel.textColor = .white
        durationLabel.isUserInteractionEnabled = false

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(durationLabel)
        let badge = Glass.attachBadge(behind: durationLabel, in: self, insets: UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7))
        badge.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 9.0 / 16.0),
            durationLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -14),
            durationLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
        // Keep the titles a uniform height
        titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: ceil(UIFont.systemFont(ofSize: 13, weight: .semibold).lineHeight * 2)).isActive = true
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

private final class CommentView: UIView {
    init(comment: VideoComment) {
        super.init(frame: .zero)
        applyCardStyle(cornerRadius: 20)

        let avatar = UIImageView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer.cornerRadius = 18
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        avatar.image = UIImage(systemName: "person.fill")
        avatar.tintColor = UIColor.white.withAlphaComponent(0.3)
        if let url = comment.avatarURL {
            avatar.sd_setImage(with: url, placeholderImage: UIImage(systemName: "person.fill"), options: [], completed: nil)
        }

        let name = UILabel()
        name.text = comment.user
        name.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        name.textColor = ColorLayout.default_orange

        let date = UILabel()
        date.text = comment.date
        date.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        date.textColor = UIColor.white.withAlphaComponent(0.45)

        let header = UIStackView(arrangedSubviews: [name, UIView(), date])
        header.axis = .horizontal
        header.alignment = .center

        let text = UILabel()
        text.text = comment.text
        text.numberOfLines = 0
        text.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        text.textColor = UIColor.white.withAlphaComponent(0.92)

        let column = UIStackView(arrangedSubviews: [header, text])
        column.axis = .vertical
        column.spacing = 6
        column.translatesAutoresizingMaskIntoConstraints = false

        addSubview(avatar)
        addSubview(column)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            avatar.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36),
            column.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Screen

private final class OwnerChip: UIControl {
    var onTap: (() -> Void)?

    init(owner: VideoOwner) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle(cornerRadius: 24)

        let avatar = UIView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.backgroundColor = ColorLayout.default_orange.withAlphaComponent(0.2)
        avatar.layer.cornerRadius = 20
        avatar.layer.borderWidth = 1.5
        avatar.layer.borderColor = ColorLayout.default_orange.cgColor
        avatar.isUserInteractionEnabled = false
        let initial = UILabel()
        initial.translatesAutoresizingMaskIntoConstraints = false
        initial.text = String(owner.name.prefix(1)).uppercased()
        initial.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        initial.textColor = ColorLayout.default_orange
        avatar.addSubview(initial)

        let name = UILabel()
        name.text = owner.name
        name.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        name.textColor = .white
        let caption = UILabel()
        let info = [owner.subscribers, owner.videosCount].compactMap { $0 }.joined(separator: " · ")
        caption.text = info.isEmpty ? "Channel".localized : info
        caption.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        caption.textColor = UIColor.white.withAlphaComponent(0.6)
        let texts = UIStackView(arrangedSubviews: [name, caption])
        texts.axis = .vertical
        texts.spacing = 2
        texts.translatesAutoresizingMaskIntoConstraints = false
        texts.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.5)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.isUserInteractionEnabled = false

        addSubview(avatar)
        addSubview(texts)
        addSubview(chevron)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            initial.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initial.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            texts.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            texts.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 64)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}

final class VideoDetailViewController: UIViewController {

    static func present(from presenter: UIViewController, video: Video, delegate: TabBarViewControllerDelegate?) {
        let controller = VideoDetailViewController(video: video, delegate: delegate)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            if #available(iOS 16.0, *) { sheet.preferredCornerRadius = 32 }
        }
        presenter.present(controller, animated: true)
    }

    private var video: Video
    private let tabDelegate: TabBarViewControllerDelegate?

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let playerContainer = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var webView: WKWebView?
    private var didAppear = false
    private var playerController: AVPlayerViewController?
    private var nativePlayer: AVPlayer?
    private var mediaOptions: [StreamOption] = []
    private var currentOption: StreamOption?
    private var statusObservation: NSKeyValueObservation?
    private var controlObservation: NSKeyValueObservation?
    private let qualityButton = UIButton(type: .system)
    private var playerGeneration = 0
    private var ownerChip: OwnerChip?
    private var currentOwner: VideoOwner?

    private let titleLabel = UILabel()
    private let statsStack = UIStackView()
    private var bookmarkButton = UIButton(type: .system)
    private let segmented = UISegmentedControl(items: ["Details".localized, "Related".localized, "Comments".localized])
    private let detailsStack = UIStackView()
    private let relatedStack = UIStackView()
    private let commentsStack = UIStackView()
    private var relatedLoaded = false
    private var commentsLoaded = false
    private var generation = 0

    init(video: Video, delegate: TabBarViewControllerDelegate?) {
        self.video = video
        self.tabDelegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorLayout.default_background
        buildLayout()
        configure()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didAppear {
            didAppear = true
            // Start the heavy web player only after the sheet animation has finished (keeps presentation smooth)
            loadPlayer()
            loadOwner()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent { teardownPlayers() }
    }

    // MARK: Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        content.axis = .vertical
        content.spacing = 16
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 28, left: 16, bottom: 40, right: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Player
        playerContainer.translatesAutoresizingMaskIntoConstraints = false
        playerContainer.backgroundColor = .black
        playerContainer.layer.cornerRadius = 24
        playerContainer.layer.cornerCurve = .continuous
        playerContainer.clipsToBounds = true
        playerContainer.heightAnchor.constraint(equalTo: playerContainer.widthAnchor, multiplier: 9.0 / 16.0).isActive = true
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        playerContainer.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: playerContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerContainer.centerYAnchor)
        ])
        content.addArrangedSubview(playerContainer)

        // Title
        titleLabel.numberOfLines = 0
        let base = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 22) } ?? base
        titleLabel.textColor = .white
        content.addArrangedSubview(titleLabel)

        // Actions
        let actions = UIStackView()
        actions.axis = .horizontal
        actions.spacing = 10
        actions.distribution = .fillEqually
        bookmarkButton = makeActionButton(title: "Bookmark".localized, symbol: "bookmark", action: #selector(onBookmark))
        actions.addArrangedSubview(bookmarkButton)
        actions.addArrangedSubview(makeActionButton(title: "Share".localized, symbol: "square.and.arrow.up", action: #selector(onShare(_:))))
        actions.addArrangedSubview(makeActionButton(title: "Open on Site".localized, symbol: "safari", action: #selector(onOpenSite)))
        content.addArrangedSubview(actions)

        // Stats
        statsStack.axis = .horizontal
        statsStack.spacing = 10
        statsStack.distribution = .fillEqually
        content.addArrangedSubview(statsStack)

        // Tabs
        segmented.selectedSegmentIndex = 0
        segmented.selectedSegmentTintColor = ColorLayout.default_orange
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.65), .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .bold)], for: .selected)
        segmented.addTarget(self, action: #selector(onTabChange), for: .valueChanged)
        segmented.heightAnchor.constraint(equalToConstant: 38).isActive = true
        content.addArrangedSubview(segmented)

        for stack in [detailsStack, relatedStack, commentsStack] {
            stack.axis = .vertical
            stack.spacing = 12
            content.addArrangedSubview(stack)
        }
        showTab(0)
    }

    private func makeActionButton(title: String, symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = Glass.buttonConfiguration()
        config.title = title
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        config.imagePadding = 4
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 6, bottom: 11, trailing: 6)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return out
        }
        config.titleLineBreakMode = .byTruncatingTail
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: Content

    private func configure() {
        generation += 1
        relatedLoaded = false
        commentsLoaded = false
        titleLabel.text = video.title
        ownerChip?.removeFromSuperview()
        ownerChip = nil
        currentOwner = nil
        refreshBookmark()

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let views = video.views.map { Double($0).shortStringRepresentation } ?? "—"
        var rating = "—"
        if let ratingString = video.rating?.ratingString, let value = Double(ratingString) { rating = String(format: "%.0f%%", value) }
        statsStack.addArrangedSubview(StatTile(value: views, caption: "Views".localized))
        statsStack.addArrangedSubview(StatTile(value: rating, caption: "Rating".localized))
        statsStack.addArrangedSubview(StatTile(value: video.duration ?? "—", caption: "Duration".localized))

        buildDetails()
        relatedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if segmented.selectedSegmentIndex == 1 { loadRelated() }
        if segmented.selectedSegmentIndex == 2 { loadComments() }
    }

    private func buildDetails() {
        detailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Published date
        if let date = video.publishDate?.toDate() {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            let label = UILabel()
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            label.textColor = UIColor.white.withAlphaComponent(0.75)
            var text = String(format: "Published %@".localized, formatter.string(from: date))
            if let votes = video.ratings { text += " · " + String(format: "%d votes".localized, votes) }
            label.text = text
            detailsStack.addArrangedSubview(label)
        }

        // Stars
        let stars = (video.pornstars ?? []).compactMap { $0.pornstarName }
        if !stars.isEmpty {
            detailsStack.addArrangedSubview(makeSectionLabel("Pornstars".localized.uppercased()))
            let wrap = WrapView()
            for name in stars {
                let chip = makeChip(name, highlighted: true)
                chip.addAction(UIAction { [weak self] _ in self?.openStar(name) }, for: .touchUpInside)
                wrap.addSubview(chip)
            }
            detailsStack.addArrangedSubview(wrap)
        }

        // Categories
        let categories = (video.categories ?? []).compactMap { $0.category }
        if !categories.isEmpty {
            detailsStack.addArrangedSubview(makeSectionLabel("Categories".localized.uppercased()))
            let wrap = WrapView()
            for name in categories { wrap.addSubview(makeChip(name.replacingOccurrences(of: "-", with: " "))) }
            detailsStack.addArrangedSubview(wrap)
        }

        // Tags
        let tags = (video.tags ?? []).compactMap { $0.tagName }
        if !tags.isEmpty {
            detailsStack.addArrangedSubview(makeSectionLabel("Tags".localized.uppercased()))
            let wrap = WrapView()
            for name in tags.prefix(30) { wrap.addSubview(makeChip("#" + name.replacingOccurrences(of: " ", with: ""))) }
            detailsStack.addArrangedSubview(wrap)
        }
    }

    private func refreshBookmark() {
        let saved = UserBookmakrs.shared.checkVideoBookmarksCointain(video)
        var config = bookmarkButton.configuration
        config?.image = UIImage(systemName: saved ? "bookmark.fill" : "bookmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        bookmarkButton.configuration = config
        bookmarkButton.tintColor = saved ? ColorLayout.default_orange : .white
    }

    // MARK: Player

    private func loadPlayer() {
        guard let key = video.videoID else { spinner.stopAnimating(); return }
        teardownPlayers()
        playerGeneration += 1
        let gen = playerGeneration
        spinner.startAnimating()
        VideoScraper.loadMedia(viewKey: key) { [weak self] options in
            guard let self = self, gen == self.playerGeneration else { return }
            if options.isEmpty { self.loadWebPlayer() } else { self.startNative(options) }
        }
    }

    private func pick(from options: [StreamOption], preferred: Int) -> StreamOption {
        let real = options.filter { $0.height > 0 }
        guard !real.isEmpty else { return options[0] }
        let fitting = real.filter { $0.height <= preferred }
        return fitting.max(by: { $0.height < $1.height }) ?? real.min(by: { $0.height < $1.height })!
    }

    private func makeItem(_ url: URL) -> AVPlayerItem {
        let headers = ["User-Agent": VideoExtras.userAgent, "Referer": "https://www.pornhub.com/"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        return AVPlayerItem(asset: asset)
    }

    private func startNative(_ options: [StreamOption]) {
        mediaOptions = options
        let saved = UserDefaults.standard.integer(forKey: "preferredQuality")
        let option = pick(from: options, preferred: saved > 0 ? saved : 720)
        currentOption = option
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = makeItem(option.url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        nativePlayer = player

        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.view.backgroundColor = .black
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(controller)
        playerContainer.insertSubview(controller.view, at: 0)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor)
        ])
        controller.didMove(toParent: self)
        playerController = controller
        installQualityButton(on: controller)

        observe(item: item)
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            DispatchQueue.main.async {
                switch p.timeControlStatus {
                case .playing: self?.spinner.stopAnimating()
                case .waitingToPlayAtSpecifiedRate: self?.spinner.startAnimating()
                default: break
                }
            }
        }
        player.play()
    }

    private func observe(item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .failed { self?.loadWebPlayer() }
            }
        }
    }

    private func installQualityButton(on controller: AVPlayerViewController) {
        guard let overlay = controller.contentOverlayView else { return }
        qualityButton.removeFromSuperview()
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        qualityButton.showsMenuAsPrimaryAction = true
        overlay.addSubview(qualityButton)
        NSLayoutConstraint.activate([
            qualityButton.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 10),
            qualityButton.trailingAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.trailingAnchor, constant: -10)
        ])
        refreshQualityMenu()
    }

    private func refreshQualityMenu() {
        var config = Glass.buttonConfiguration()
        config.title = currentOption?.label ?? "Quality".localized
        config.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            return out
        }
        qualityButton.configuration = config
        let actions = mediaOptions.map { option in
            UIAction(title: option.label, state: option == currentOption ? .on : .off) { [weak self] _ in self?.select(option) }
        }
        qualityButton.menu = UIMenu(title: "Quality".localized, children: actions)
    }

    private func select(_ option: StreamOption) {
        guard option != currentOption, let player = nativePlayer else { return }
        let time = player.currentTime()
        let wasPlaying = player.timeControlStatus != .paused
        currentOption = option
        if option.height > 0 { UserDefaults.standard.set(option.height, forKey: "preferredQuality") }
        let item = makeItem(option.url)
        player.replaceCurrentItem(with: item)
        observe(item: item)
        if time.isValid && time.seconds > 0.5 {
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if wasPlaying { player.play() }
        spinner.startAnimating()
        refreshQualityMenu()
    }

    private func teardownNative() {
        statusObservation = nil
        controlObservation = nil
        nativePlayer?.pause()
        nativePlayer?.replaceCurrentItem(with: nil)
        nativePlayer = nil
        qualityButton.removeFromSuperview()
        if let controller = playerController {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }
        playerController = nil
    }

    private func teardownPlayers() {
        teardownNative()
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
    }

    /// Fallback: the site's own embedded player (with ad blocking).
    private func loadWebPlayer() {
        guard let videoId = video.videoID else { spinner.stopAnimating(); return }
        teardownNative()
        let web: WKWebView
        if let existing = webView {
            web = existing
        } else {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            web = WKWebView(frame: .zero, configuration: config)
            web.translatesAutoresizingMaskIntoConstraints = false
            web.isOpaque = false
            web.backgroundColor = .black
            web.scrollView.isScrollEnabled = false
            web.navigationDelegate = self
            web.alpha = 0
            playerContainer.insertSubview(web, at: 0)
            NSLayoutConstraint.activate([
                web.topAnchor.constraint(equalTo: playerContainer.topAnchor),
                web.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor),
                web.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
                web.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor)
            ])
            webView = web
        }
        spinner.startAnimating()
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"></head>
        <body style="margin:0;background:#000;overflow:hidden">
        <iframe src="https://www.pornhub.com/embed/\(videoId)" frameborder="0" scrolling="no" allowfullscreen allow="autoplay; fullscreen; picture-in-picture" style="position:absolute;top:0;left:0;width:100%;height:100%;border:0"></iframe>
        </body></html>
        """
        PlayerAdBlock.install(on: web) { [weak web] in
            web?.loadHTMLString(html, baseURL: URL(string: "https://www.pornhub.com"))
        }
    }

    // MARK: Tabs

    private func showTab(_ index: Int) {
        detailsStack.isHidden = index != 0
        relatedStack.isHidden = index != 1
        commentsStack.isHidden = index != 2
    }

    @objc private func onTabChange() {
        let index = segmented.selectedSegmentIndex
        showTab(index)
        if index == 1 && !relatedLoaded { loadRelated() }
        if index == 2 && !commentsLoaded { loadComments() }
    }

    private func makeStatusLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.55)
        return label
    }

    private func makeLoader() -> UIView {
        let box = UIView()
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        box.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: box.topAnchor, constant: 24),
            indicator.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -24)
        ])
        return box
    }

    // MARK: Related

    private func loadRelated() {
        relatedLoaded = true
        relatedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        relatedStack.addArrangedSubview(makeLoader())
        let query = video.pornstars?.first?.pornstarName ?? video.tags?.first?.tagName ?? video.categories?.first?.category
        let gen = generation
        let current = video.videoID
        APIService.shared.sendSearchRequest(searchText: query, category: nil, page: 1, ordering: "mostviewed", period: nil) { [weak self] result in
            guard let self = self, gen == self.generation else { return }
            self.relatedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            switch result {
            case .success(let response):
                let items = response.videos.filter { $0.videoID != current }.prefix(12)
                if items.isEmpty {
                    self.relatedStack.addArrangedSubview(self.makeStatusLabel("No data found".localized))
                    return
                }
                var row: UIStackView?
                for (index, item) in items.enumerated() {
                    if index % 2 == 0 {
                        let newRow = UIStackView()
                        newRow.axis = .horizontal
                        newRow.spacing = 10
                        newRow.distribution = .fillEqually
                        newRow.alignment = .top
                        self.relatedStack.addArrangedSubview(newRow)
                        row = newRow
                    }
                    let card = RelatedCard(video: item)
                    card.onTap = { [weak self] in self?.open(video: item) }
                    row?.addArrangedSubview(card)
                }
                if items.count % 2 == 1 { row?.addArrangedSubview(UIView()) }
            case .failure(let error):
                self.relatedStack.addArrangedSubview(self.makeStatusLabel(error.localizedDescription))
            }
        }
    }

    private func open(video newVideo: Video) {
        video = newVideo
        segmented.selectedSegmentIndex = 0
        showTab(0)
        configure()
        scrollView.setContentOffset(.zero, animated: true)
        loadPlayer()
        loadOwner()
    }

    // MARK: Comments

    private func loadComments() {
        commentsLoaded = true
        commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commentsStack.addArrangedSubview(makeLoader())
        guard let key = video.videoID else { return }
        let gen = generation
        VideoExtras.loadComments(viewKey: key, popular: true) { [weak self] result in
            guard let self = self, gen == self.generation else { return }
            self.commentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            switch result {
            case .success(let comments):
                if comments.isEmpty {
                    self.commentsStack.addArrangedSubview(self.makeStatusLabel("No comments yet".localized))
                } else {
                    comments.forEach { self.commentsStack.addArrangedSubview(CommentView(comment: $0)) }
                }
            case .failure:
                self.commentsStack.addArrangedSubview(self.makeStatusLabel("Could not load comments".localized))
                self.commentsLoaded = false
            }
        }
    }

    // MARK: Owner

    private func loadOwner() {
        guard let key = video.videoID else { return }
        let gen = generation
        VideoScraper.loadOwner(viewKey: key) { [weak self] owner in
            guard let self = self, gen == self.generation, let owner = owner else { return }
            self.currentOwner = owner
            let chip = OwnerChip(owner: owner)
            chip.onTap = { [weak self] in self?.openOwner() }
            chip.alpha = 0
            self.ownerChip?.removeFromSuperview()
            if let index = self.content.arrangedSubviews.firstIndex(of: self.titleLabel) {
                self.content.insertArrangedSubview(chip, at: index + 1)
            }
            self.ownerChip = chip
            UIView.animate(withDuration: 0.25) { chip.alpha = 1 }
        }
    }

    private func openOwner() {
        guard let owner = currentOwner else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        nativePlayer?.pause()
        ChannelViewController.present(from: self, owner: owner, delegate: tabDelegate)
    }

    // MARK: Actions

    @objc private func onBookmark() {
        if UserBookmakrs.shared.checkVideoBookmarksCointain(video) {
            UserBookmakrs.shared.removeVideoBookmark(video: video)
        } else {
            UserBookmakrs.shared.saveVideoToBookmark(video: video)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        refreshBookmark()
    }

    private var siteURL: URL? {
        guard let key = video.videoID else { return nil }
        return URL(string: "https://www.pornhub.com/view_video.php?viewkey=\(key)")
    }

    @objc private func onShare(_ sender: UIButton) {
        guard let url = siteURL else { return }
        let controller = UIActivityViewController(activityItems: [video.title ?? "", url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = sender
        present(controller, animated: true)
    }

    @objc private func onOpenSite() {
        guard let url = siteURL else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func openStar(_ name: String) {
        let delegate = tabDelegate
        dismiss(animated: true) {
            UserPreferences.shared.starToFind = name
            delegate?.setPage(index: 2)
        }
    }
}

extension VideoDetailViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        UIView.animate(withDuration: 0.25) { webView.alpha = 1 }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
        webView.alpha = 1
    }
}
