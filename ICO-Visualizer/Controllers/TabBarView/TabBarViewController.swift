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
    private var tabGlassView: UIVisualEffectView?
    private var tabIndicatorView: UIVisualEffectView?
    private var settingsGlassView: UIVisualEffectView?
    private var selectedIndex: Int = 0
    private let selectionHaptics = UISelectionFeedbackGenerator()
    
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
        layoutTabIndicator(animated: false)
        for glass in [tabGlassView, tabIndicatorView, settingsGlassView] {
            // Pre-iOS 26 fallback has no glass shape of its own, so round it manually.
            if let glass = glass, glass.layer.cornerRadius != glass.bounds.height / 2, glass.effect is UIBlurEffect {
                glass.layer.cornerRadius = glass.bounds.height / 2
            }
        }
    }

    /// Builds a glass surface: real Liquid Glass on iOS 26+/27, a blur material on older systems.
    private func makeGlassView(tint: UIColor? = nil, interactive: Bool = false, fallbackFill: UIColor? = nil) -> UIVisualEffectView {
        let view: UIVisualEffectView
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = tint
            glass.isInteractive = interactive
            view = UIVisualEffectView(effect: glass)
            view.cornerConfiguration = .capsule()
        } else {
            view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
            view.clipsToBounds = true
            view.layer.cornerCurve = .continuous
            view.contentView.backgroundColor = fallbackFill ?? tint?.withAlphaComponent(0.18)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }

    private func setupModernChrome() {
        // Seamless chrome: let the app background show through instead of flat bars.
        headerView.backgroundColor = ColorLayout.default_background
        tabBarFiller.isHidden = true
        tabBarContainer.backgroundColor = .clear

        // Floating glass tab bar
        let pill = makeGlassView()
        tabBarContainer.insertSubview(pill, at: 0)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -16),
            pill.centerYAnchor.constraint(equalTo: tabBarContainer.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 62)
        ])
        tabGlassView = pill

        // Selection highlight (orange-tinted glass) that slides between tabs
        let indicator = makeGlassView(fallbackFill: UIColor.white.withAlphaComponent(0.14))
        indicator.frame = .zero
        indicator.translatesAutoresizingMaskIntoConstraints = true
        tabBarContainer.insertSubview(indicator, aboveSubview: pill)
        tabIndicatorView = indicator

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
        let settingsGlass = makeGlassView(interactive: true)
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

    private func layoutTabIndicator(animated: Bool) {
        guard let indicator = tabIndicatorView,
              let items = tabItems, selectedIndex < items.count else { return }
        tabBarContainer.layoutIfNeeded()
        let target = items[selectedIndex].convert(items[selectedIndex].bounds, to: tabBarContainer)
            .insetBy(dx: 2, dy: 0)
        let frame = CGRect(x: target.minX, y: tabBarContainer.bounds.midY - 25, width: target.width, height: 50)
        guard indicator.frame != frame else { return }
        if animated {
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4, options: [.allowUserInteraction, .beginFromCurrentState]) {
                indicator.frame = frame
            }
        } else {
            indicator.frame = frame
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
        
        for item in tabItems! {
            item.setTitle("", for: .normal)
            item.tintColor = UIColor.white.withAlphaComponent(0.6)
        }
        self.tabItems![index].tintColor = ColorLayout.default_orange
        settingsButton.setTitle("", for: .normal)
        if selectedIndex != index { selectionHaptics.selectionChanged() }
        selectedIndex = index
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
