//
//  TabBarViewController.swift
//  ICO-visualizer
//
//  Created by Anonymous on 21/09/21.
//

import UIKit

class TabBarViewController: UIViewController {
    
    @IBOutlet var tabItems: Array<UIButton>?

    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerHeightConstraing: NSLayoutConstraint!
    private let defaultHeaderHeight: CGFloat = 70
    
    
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var tabBarFiller: UIView!

    // MARK: - Modern (Liquid Glass) chrome
    @IBOutlet weak var tabBarTopConstraint: NSLayoutConstraint!

    private var tabGlassView: UIVisualEffectView?
    private var tabIndicatorView: UIVisualEffectView?
    private var settingsGlassView: UIVisualEffectView?
    private let bottomFadeView = UIView()
    private let bottomFadeLayer = CAGradientLayer()
    private var selectedIndex: Int = 0
    private var previewIndex: Int = 0
    private var isScrubbing = false
    private let selectionHaptics = UISelectionFeedbackGenerator()
    private let liftHaptics = UIImpactFeedbackGenerator(style: .soft)
    private let tabBarHeight: CGFloat = 68

    @IBOutlet weak var headerLogoImageView: UIImageView!
    private var mainNavigationController: BaseNavigationController!

    lazy var controllers = [HomeViewController(), BookmarksViewController(), StarsViewController(), ReelsViewController()]

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(onDidEnterFakePin(_:)), name: .didEnterFakePin, object: nil)
        setupModernChrome()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Content flows under the floating glass bar (except on Reels, which is full-screen video above the bar).
        let overlap = selectedIndex == 3 ? 0 : tabBarHeight + view.safeAreaInsets.bottom
        tabBarTopConstraint?.constant = -overlap
        bottomFadeLayer.frame = bottomFadeView.bounds
        if !isScrubbing { layoutTabIndicator(animated: false) }
        Glass.roundCapsuleIfNeeded(tabGlassView)
        Glass.roundCapsuleIfNeeded(tabIndicatorView)
        Glass.roundCapsuleIfNeeded(settingsGlassView)
    }

    /// Visual order of the tabs from left to right (the storyboard order differs from the tab indexes).
    private var orderedItems: [UIButton] {
        return (tabItems ?? []).sorted { $0.convert($0.bounds, to: tabBarContainer).midX < $1.convert($1.bounds, to: tabBarContainer).midX }
    }

    private func setupModernChrome() {
        // Seamless chrome: let the app background show through instead of flat bars.
        headerView.backgroundColor = ColorLayout.default_background
        tabBarFiller.isHidden = true
        tabBarContainer.backgroundColor = .clear

        // Soft fade so content slides gently under the glass bar
        bottomFadeLayer.colors = [UIColor.clear.cgColor, ColorLayout.default_background.withAlphaComponent(0.92).cgColor]
        bottomFadeView.layer.addSublayer(bottomFadeLayer)
        bottomFadeView.isUserInteractionEnabled = false
        bottomFadeView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bottomFadeView, belowSubview: tabBarContainer)
        NSLayoutConstraint.activate([
            bottomFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeView.heightAnchor.constraint(equalToConstant: 150)
        ])

        // Floating glass tab bar
        let pill = Glass.make(shape: .capsule)
        tabBarContainer.insertSubview(pill, at: 0)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -16),
            pill.centerYAnchor.constraint(equalTo: tabBarContainer.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 62)
        ])
        tabGlassView = pill

        // Selection "droplet": glass that slides, stretches and follows the finger
        let indicator = Glass.make(shape: .capsule,
                                   tint: UIColor.white.withAlphaComponent(0.20),
                                   fallbackFill: UIColor.white.withAlphaComponent(0.16))
        indicator.translatesAutoresizingMaskIntoConstraints = true
        indicator.isUserInteractionEnabled = false
        tabBarContainer.insertSubview(indicator, aboveSubview: pill)
        tabIndicatorView = indicator

        // Whole bar is a scrub surface: tap a tab or drag across them
        let scrub = UILongPressGestureRecognizer(target: self, action: #selector(handleScrub(_:)))
        scrub.minimumPressDuration = 0
        scrub.allowableMovement = .greatestFiniteMagnitude
        tabBarContainer.addGestureRecognizer(scrub)
        (tabItems ?? []).first?.superview?.isUserInteractionEnabled = false

        // Modern SF Symbols instead of the old flat PNG icons
        let symbols = ["house.fill", "bookmark.fill", "star.fill", "play.square.stack.fill"]
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        for (i, item) in (tabItems ?? []).enumerated() where i < symbols.count {
            var cfg = item.configuration ?? UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: symbols[i], withConfiguration: symbolConfig)
            item.configuration = cfg
        }
        var settingsCfg = settingsButton.configuration ?? UIButton.Configuration.plain()
        settingsCfg.image = UIImage(systemName: "gearshape.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        settingsButton.configuration = settingsCfg
        settingsButton.tintColor = UIColor.white.withAlphaComponent(0.85)

        // Glass settings button
        let settingsGlass = Glass.make(shape: .capsule, interactive: false)
        headerView.insertSubview(settingsGlass, belowSubview: settingsButton)
        NSLayoutConstraint.activate([
            settingsGlass.centerXAnchor.constraint(equalTo: settingsButton.centerXAnchor),
            settingsGlass.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            settingsGlass.widthAnchor.constraint(equalToConstant: 44),
            settingsGlass.heightAnchor.constraint(equalToConstant: 44)
        ])
        settingsGlassView = settingsGlass

        layoutTabIndicator(animated: false)
    }

    private func indicatorFrame(forCenterX centerX: CGFloat, lifted: Bool) -> CGRect {
        let items = orderedItems
        let itemWidth = items.first.map { $0.convert($0.bounds, to: tabBarContainer).width } ?? 80
        let width = itemWidth - 4 + (lifted ? 18 : 0)
        let height: CGFloat = lifted ? 58 : 50
        return CGRect(x: centerX - width / 2, y: tabBarContainer.bounds.midY - height / 2, width: width, height: height)
    }

    private func centerX(ofTab index: Int) -> CGFloat {
        guard let items = tabItems, index < items.count else { return 0 }
        return items[index].convert(items[index].bounds, to: tabBarContainer).midX
    }

    private func layoutTabIndicator(animated: Bool) {
        guard let indicator = tabIndicatorView, selectedIndex < (tabItems?.count ?? 0) else { return }
        tabBarContainer.layoutIfNeeded()
        let frame = indicatorFrame(forCenterX: centerX(ofTab: selectedIndex), lifted: false)
        guard indicator.frame != frame else { return }
        if animated {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.6, options: [.allowUserInteraction, .beginFromCurrentState]) {
                indicator.frame = frame
            }
        } else {
            indicator.frame = frame
        }
    }

    private func tint(forIndex index: Int) {
        for (i, item) in (tabItems ?? []).enumerated() {
            let selected = i == index
            UIView.animate(withDuration: 0.2) {
                item.tintColor = selected ? ColorLayout.default_orange : UIColor.white.withAlphaComponent(0.6)
                item.transform = selected ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
            }
        }
    }

    private func nearestTabIndex(toX x: CGFloat) -> Int {
        guard let items = tabItems, !items.isEmpty else { return 0 }
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for i in 0..<items.count {
            let d = abs(centerX(ofTab: i) - x)
            if d < bestDistance { bestDistance = d; best = i }
        }
        return best
    }

    @objc private func handleScrub(_ gesture: UILongPressGestureRecognizer) {
        guard let indicator = tabIndicatorView, let items = tabItems, !items.isEmpty else { return }
        let x = gesture.location(in: tabBarContainer).x
        let xs = orderedItems.map { $0.convert($0.bounds, to: tabBarContainer).midX }
        let clampedX = min(max(x, xs.first ?? x), xs.last ?? x)

        switch gesture.state {
        case .began:
            isScrubbing = true
            previewIndex = nearestTabIndex(toX: clampedX)
            liftHaptics.impactOccurred()
            UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.8, options: [.allowUserInteraction, .beginFromCurrentState]) {
                indicator.frame = self.indicatorFrame(forCenterX: clampedX, lifted: true)
            }
            tint(forIndex: previewIndex)
        case .changed:
            let target = indicatorFrame(forCenterX: clampedX, lifted: true)
            UIView.animate(withDuration: 0.16, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]) {
                indicator.frame = target
            }
            let nearest = nearestTabIndex(toX: clampedX)
            if nearest != previewIndex {
                previewIndex = nearest
                selectionHaptics.selectionChanged()
                tint(forIndex: nearest)
            }
        case .ended, .cancelled, .failed:
            isScrubbing = false
            let final = gesture.state == .ended ? nearestTabIndex(toX: clampedX) : selectedIndex
            if final != selectedIndex {
                setViewController(index: final)
            }
            tint(forIndex: selectedIndex)
            layoutTabIndicator(animated: true)
        default:
            break
        }
    }

    @objc func onDidEnterFakePin(_ notification: Notification)
    {
        DispatchQueue.main.async {
            let vc = FakeViewController()
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? BaseNavigationController,
                    segue.identifier == "mainSegue" {
            self.mainNavigationController = vc
            self.mainNavigationController.setNavigationBarHidden(true, animated: false)
            self.setViewController(index: 0)
        }
    }
    
    private func setViewController(index: Int){
        self.headerHeightConstraing.constant = index == 3 ? 0 : self.defaultHeaderHeight + UIScreen.main.topSafeAreaHeight
        self.headerView.isHidden = index == 3
        let vc = controllers[index]
        vc.tabDelegate = self
        self.mainNavigationController.setViewControllers([vc], animated: false)
        
        settingsButton.setTitle("", for: .normal)
        for item in tabItems! { item.setTitle("", for: .normal) }
        if selectedIndex != index { selectionHaptics.selectionChanged() }
        selectedIndex = index
        tint(forIndex: index)
        view.setNeedsLayout()
        layoutTabIndicator(animated: tabIndicatorView?.window != nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vc.viewDidSet()
        }
        
    }
    @IBAction func onItemSelect(_ sender: UIButton) {
        self.setViewController(index: sender.tag)
    }
    
    @IBAction func onSettingsButtonTap(_ sender: UIButton) {
        if mainNavigationController.topViewController is SettingsViewController {
            return
        }
        let vc = SettingsViewController()
        self.mainNavigationController.pushViewController(vc, animated: true)
    }
    
    func pauseReelsIfNeeded(){
        if let vc = mainNavigationController.topViewController as? ReelsViewController {
            vc.pauseVideoIfNeeded()
        }
    }
    
    func playReelsIfNeeded(){
        if let vc = mainNavigationController.topViewController as? ReelsViewController {
            vc.playVideoIfNeeded()
        }
    }
}

extension TabBarViewController: TabBarViewControllerDelegate {
    func setPage(index: Int) {
        self.setViewController(index: index)
    }
    
    func searchForCategory(category: String) {
        if let vc = self.controllers[0] as? HomeViewController {
            vc.searchForCategory(category: category)
        }
    }
    
    func setHeader() {
        self.headerLogoImageView.image = UIImage(named: "header_logo")
    }
}
