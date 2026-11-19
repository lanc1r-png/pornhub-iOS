//
//  ReelOverlayView.swift
//  ICO-visualizer
//
//  TikTok-style overlay for the reels feed: action rail, author block, gradients.
//

import UIKit
import SDWebImage

final class ReelOverlayView: UIView {

    // Callbacks
    var onProfile: (() -> Void)?
    var onShare: (() -> Void)?
    var onMute: (() -> Void)?

    private let bottomGradient = CAGradientLayer()
    private let topGradient = CAGradientLayer()

    private let avatarView = UIImageView()
    private let usernameLabel = UILabel()
    private let verifiedView = UIImageView()
    private let tagsLabel = UILabel()
    private let sourceLabel = UILabel()
    private var sourceGlass: UIVisualEffectView?

    private let rail = UIStackView()
    private var glassViews: [UIVisualEffectView] = []
    private let likeIcon = UIImageView()
    private let likeCountLabel = UILabel()
    private let viewsCountLabel = UILabel()
    private let muteIcon = UIImageView()
    private let playGlass = Glass.make(shape: .capsule)
    private let playIcon = UIImageView()

    private(set) var isLiked = false
    private var likeCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Let touches pass through to the video unless they hit a control.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bottomGradient.frame = CGRect(x: 0, y: bounds.height - 400, width: bounds.width, height: 400)
        topGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 160)
        avatarView.layer.cornerRadius = avatarView.bounds.width / 2
        for glass in glassViews + [playGlass] { Glass.roundCapsuleIfNeeded(glass) }
        if let sourceGlass = sourceGlass { Glass.roundCapsuleIfNeeded(sourceGlass) }
    }

    // MARK: Build

    private func build() {
        backgroundColor = .clear
        bottomGradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.72).cgColor]
        topGradient.colors = [UIColor.black.withAlphaComponent(0.45).cgColor, UIColor.clear.cgColor]
        layer.addSublayer(topGradient)
        layer.addSublayer(bottomGradient)

        // Source chip (top-left)
        let glass = Glass.make(shape: .capsule, fallbackFill: UIColor.black.withAlphaComponent(0.25))
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        sourceLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sourceLabel.textColor = .white
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sourceLabel)
        sourceGlass = glass
        NSLayoutConstraint.activate([
            sourceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            sourceLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 18),
            glass.leadingAnchor.constraint(equalTo: sourceLabel.leadingAnchor, constant: -12),
            glass.trailingAnchor.constraint(equalTo: sourceLabel.trailingAnchor, constant: 12),
            glass.topAnchor.constraint(equalTo: sourceLabel.topAnchor, constant: -7),
            glass.bottomAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 7)
        ])

        // Author block (bottom-left)
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.borderWidth = 2
        avatarView.layer.borderColor = UIColor.white.cgColor
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTapped)))

        usernameLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        usernameLabel.textColor = .white
        usernameLabel.numberOfLines = 2
        usernameLabel.isUserInteractionEnabled = true
        usernameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTapped)))

        verifiedView.image = UIImage(systemName: "checkmark.seal.fill")
        verifiedView.tintColor = ColorLayout.default_orange
        verifiedView.setContentHuggingPriority(.required, for: .horizontal)

        let nameRow = UIStackView(arrangedSubviews: [avatarView, usernameLabel, verifiedView, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 10
        nameRow.alignment = .center

        tagsLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        tagsLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        tagsLabel.numberOfLines = 2

        let info = UIStackView(arrangedSubviews: [nameRow, tagsLabel])
        info.axis = .vertical
        info.spacing = 10
        info.translatesAutoresizingMaskIntoConstraints = false
        addSubview(info)

        // Action rail (right)
        rail.axis = .vertical
        rail.spacing = 12
        rail.alignment = .center
        rail.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rail)

        rail.addArrangedSubview(makeRailButton(icon: likeIcon, symbol: "heart.fill", countLabel: likeCountLabel, action: #selector(likeTapped)))
        rail.addArrangedSubview(makeRailButton(icon: UIImageView(), symbol: "eye.fill", countLabel: viewsCountLabel, action: nil))
        rail.addArrangedSubview(makeRailButton(icon: UIImageView(), symbol: "arrowshape.turn.up.right.fill", countLabel: nil, action: #selector(shareTapped)))
        rail.addArrangedSubview(makeRailButton(icon: muteIcon, symbol: "speaker.slash.fill", countLabel: nil, action: #selector(muteTapped)))

        // Pause indicator
        playGlass.translatesAutoresizingMaskIntoConstraints = false
        playGlass.isUserInteractionEnabled = false
        playIcon.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .bold))
        playIcon.tintColor = .white
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playGlass.alpha = 0
        playIcon.alpha = 0
        addSubview(playGlass)
        addSubview(playIcon)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),
            info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            info.trailingAnchor.constraint(equalTo: rail.leadingAnchor, constant: -10),
            info.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -118),
            rail.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -118),
            playGlass.centerXAnchor.constraint(equalTo: centerXAnchor),
            playGlass.centerYAnchor.constraint(equalTo: centerYAnchor),
            playGlass.widthAnchor.constraint(equalToConstant: 88),
            playGlass.heightAnchor.constraint(equalToConstant: 88),
            playIcon.centerXAnchor.constraint(equalTo: playGlass.centerXAnchor, constant: 3),
            playIcon.centerYAnchor.constraint(equalTo: playGlass.centerYAnchor)
        ])
    }

    private func makeRailButton(icon: UIImageView, symbol: String, countLabel: UILabel?, action: Selector?) -> UIView {
        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        let glass = Glass.make(shape: .capsule, fallbackFill: UIColor.black.withAlphaComponent(0.28))
        glass.isUserInteractionEnabled = false
        glassViews.append(glass)
        circle.addSubview(glass)
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(icon)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 44),
            circle.heightAnchor.constraint(equalToConstant: 44),
            glass.leadingAnchor.constraint(equalTo: circle.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: circle.trailingAnchor),
            glass.topAnchor.constraint(equalTo: circle.topAnchor),
            glass.bottomAnchor.constraint(equalTo: circle.bottomAnchor),
            icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        if let action = action {
            let tap = UITapGestureRecognizer(target: self, action: action)
            circle.addGestureRecognizer(tap)
            circle.isUserInteractionEnabled = true
        }
        let column = UIStackView(arrangedSubviews: [circle])
        column.axis = .vertical
        column.spacing = 4
        column.alignment = .center
        if let countLabel = countLabel {
            countLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            countLabel.textColor = .white
            countLabel.textAlignment = .center
            column.addArrangedSubview(countLabel)
        }
        return column
    }

    // MARK: Configure

    func configure(username: String?, avatarURL: URL?, verified: Bool, tags: [String]?, likes: Int?, views: Int?, source: String, isAudioOn: Bool) {
        usernameLabel.text = username
        verifiedView.isHidden = !verified
        tagsLabel.text = (tags?.isEmpty ?? true) ? "" : "#" + (tags ?? []).prefix(6).joined(separator: " #")
        sourceLabel.text = source
        let placeholder = UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = UIColor.white.withAlphaComponent(0.6)
        if let avatarURL = avatarURL {
            avatarView.sd_setImage(with: avatarURL, placeholderImage: placeholder)
        } else {
            avatarView.image = placeholder
        }
        isLiked = false
        likeCount = likes ?? 0
        likeIcon.tintColor = .white
        likeCountLabel.text = likes == nil ? "" : Double(likeCount).shortStringRepresentation
        likeCountLabel.superview?.isHidden = false
        viewsCountLabel.text = views.map { Double($0).shortStringRepresentation } ?? ""
        viewsCountLabel.superview?.isHidden = views == nil
        updateAudio(isOn: isAudioOn)
        setPaused(false)
    }

    func updateAudio(isOn: Bool) {
        let name = isOn ? "speaker.wave.2.fill" : "speaker.slash.fill"
        muteIcon.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
    }

    func setPaused(_ paused: Bool) {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.beginFromCurrentState]) {
            self.playGlass.alpha = paused ? 1 : 0
            self.playIcon.alpha = paused ? 1 : 0
            self.playGlass.transform = paused ? .identity : CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }

    // MARK: Actions

    @objc private func profileTapped() { onProfile?() }
    @objc private func shareTapped() { onShare?() }
    @objc private func muteTapped() { onMute?() }

    @objc private func likeTapped() { setLiked(!isLiked, animated: true) }

    func setLiked(_ liked: Bool, animated: Bool) {
        guard liked != isLiked else { return }
        isLiked = liked
        likeCount += liked ? 1 : -1
        likeCountLabel.text = Double(max(likeCount, 0)).shortStringRepresentation
        likeIcon.tintColor = liked ? UIColor(red: 1, green: 0.23, blue: 0.36, alpha: 1) : .white
        if animated {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            likeIcon.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.9, options: []) {
                self.likeIcon.transform = .identity
            }
        }
    }

    /// Big heart that pops where the user double-tapped.
    func showHeartBurst(at point: CGPoint) {
        setLiked(true, animated: true)
        let heart = UIImageView(image: UIImage(systemName: "heart.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 96, weight: .bold)))
        heart.tintColor = UIColor(red: 1, green: 0.23, blue: 0.36, alpha: 1)
        heart.sizeToFit()
        heart.center = point
        heart.transform = CGAffineTransform(scaleX: 0.3, y: 0.3).rotated(by: CGFloat.random(in: -0.35...0.35))
        heart.alpha = 0
        addSubview(heart)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8, options: []) {
            heart.alpha = 1
            heart.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0.25, options: [.curveEaseIn]) {
                heart.alpha = 0
                heart.transform = CGAffineTransform(scaleX: 1.5, y: 1.5).translatedBy(x: 0, y: -40)
            } completion: { _ in heart.removeFromSuperview() }
        }
    }
}
