//
//  Glass.swift
//  ICO-visualizer
//
//  Liquid Glass helpers: real glass on iOS 26 / 27, blur material fallback on older systems.
//

import UIKit

enum Glass {
    enum Shape {
        case capsule
        case rounded(CGFloat)
    }

    /// Creates a glass surface. Add it to a view hierarchy and pin it with constraints or a frame.
    static func make(shape: Shape = .capsule,
                     tint: UIColor? = nil,
                     interactive: Bool = false,
                     fallbackFill: UIColor? = nil) -> UIVisualEffectView {
        let view: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = tint
            glass.isInteractive = interactive
            view = UIVisualEffectView(effect: glass)
            switch shape {
            case .capsule:
                view.cornerConfiguration = .capsule()
            case .rounded(let radius):
                view.cornerConfiguration = .uniformCorners(radius: .fixed(radius))
            }
        } else {
            view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
            view.clipsToBounds = true
            view.layer.cornerCurve = .continuous
            if case .rounded(let radius) = shape { view.layer.cornerRadius = radius }
            view.contentView.backgroundColor = fallbackFill ?? tint?.withAlphaComponent(0.18)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = interactive
        return view
    }

    /// Button configuration: native glass buttons on iOS 26+, tinted gray buttons before.
    static func buttonConfiguration(prominent: Bool = false) -> UIButton.Configuration {
        if #available(iOS 26.0, *) {
            return prominent ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        }
        return prominent ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
    }

    /// Pre-iOS 26 fallback has no glass shape of its own: keep capsules round after layout.
    static func roundCapsuleIfNeeded(_ view: UIVisualEffectView?) {
        guard let view = view, view.effect is UIBlurEffect else { return }
        let radius = view.bounds.height / 2
        if view.layer.cornerRadius != radius { view.layer.cornerRadius = radius }
    }

    /// Pins a glass capsule behind a label/view with padding.
    @discardableResult
    static func attachBadge(behind target: UIView, in container: UIView, insets: UIEdgeInsets = UIEdgeInsets(top: 4, left: 9, bottom: 4, right: 9)) -> UIVisualEffectView {
        let badge = make(shape: .capsule, fallbackFill: UIColor.black.withAlphaComponent(0.25))
        container.insertSubview(badge, belowSubview: target)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: -insets.left),
            badge.trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: insets.right),
            badge.topAnchor.constraint(equalTo: target.topAnchor, constant: -insets.top),
            badge.bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: insets.bottom)
        ])
        return badge
    }
}

/// Applies the app's card look (rounded, subtle fill and hairline border).
extension UIView {
    func applyCardStyle(cornerRadius: CGFloat = 26) {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.shadowOpacity = 0
    }
}
