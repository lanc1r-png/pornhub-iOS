//
//  HomeViewController.swift
//  ICO-visualizer
//
//  Created by Anonymous on 03/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import UIKit
import CCBottomRefreshControl

class HomeViewController: BaseViewController {
    
    private var coordinator: HomeViewCoordinator!
    private var loadingData = false
    private var searchGlass: UIVisualEffectView?

    // Sorting (like the original site)
    private let sortOptions: [(title: String, key: String, hasPeriod: Bool)] = [
        ("Popular", "mostviewed", true), ("New", "newest", false), ("Top Rated", "rating", true), ("Featured", "featured", false)
    ]
    private let periodOptions: [(title: String, key: String?)] = [("All Time", nil), ("This Week", "weekly"), ("This Month", "monthly")]
    private var currentOrdering = "mostviewed"
    private var currentPeriod: String? = nil
    private var sortButtons: [UIButton] = []
    private let periodButton = UIButton(type: .system)
    private let sortScroll = UIScrollView()
    private let sortStack = UIStackView()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Glass.roundCapsuleIfNeeded(searchGlass)
    }
    
    let searchView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = ColorLayout.default_background
        return view
    }()
    
    let searchField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.returnKeyType = .search
        field.keyboardType = .default
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.placeholder = " " + "Search...".localized
        field.textColor = ColorLayout.default_text
        field.attributedPlaceholder = NSAttributedString(
            string: " " + "Search...".localized,
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.55)]
        )
        var imageView = UIImageView();
        var image = UIImage(named: "search_icon")
        imageView.image = image;
        imageView.tintColor = .lightGray
        field.leftView = imageView
        field.leftViewMode = UITextField.ViewMode.always
        field.leftViewMode = .always
        return field
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(onEnterPin(_:)), name: .didEnterCorrectPin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateBookmarks(_:)), name: .didUpdateBookmarks, object: nil)
        
        #if targetEnvironment(simulator)
        self.load()
        return
        #endif
        
        let vc = PinSetupViewController()
        vc.pinType = UserPreferences.shared.userPin == nil ? .newPin : .auth
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }

    func showKillAlert(){
        let alert = UIAlertController(title: "Error".localized, message: "Autentication failed, the app will be killed".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { action in
            exit(-1)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Sort bar
    private func buildSortBar() {
        sortScroll.translatesAutoresizingMaskIntoConstraints = false
        sortScroll.showsHorizontalScrollIndicator = false
        sortScroll.alwaysBounceHorizontal = true
        searchView.addSubview(sortScroll)
        sortStack.axis = .horizontal
        sortStack.spacing = 8
        sortStack.translatesAutoresizingMaskIntoConstraints = false
        sortScroll.addSubview(sortStack)
        NSLayoutConstraint.activate([
            sortScroll.leadingAnchor.constraint(equalTo: searchView.leadingAnchor),
            sortScroll.trailingAnchor.constraint(equalTo: searchView.trailingAnchor),
            sortScroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            sortScroll.heightAnchor.constraint(equalToConstant: 40),
            sortStack.leadingAnchor.constraint(equalTo: sortScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            sortStack.trailingAnchor.constraint(equalTo: sortScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            sortStack.topAnchor.constraint(equalTo: sortScroll.contentLayoutGuide.topAnchor),
            sortStack.bottomAnchor.constraint(equalTo: sortScroll.contentLayoutGuide.bottomAnchor),
            sortStack.heightAnchor.constraint(equalTo: sortScroll.frameLayoutGuide.heightAnchor)
        ])
        for (i, _) in sortOptions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = i
            button.addTarget(self, action: #selector(onSortTap(_:)), for: .touchUpInside)
            sortButtons.append(button)
            sortStack.addArrangedSubview(button)
        }
        sortStack.addArrangedSubview(periodButton)
        refreshSortBar()
    }

    private func styleChip(_ button: UIButton, title: String, selected: Bool, showsChevron: Bool = false) {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = selected ? UIButton.Configuration.prominentGlass() : UIButton.Configuration.glass()
        } else {
            config = selected ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
        }
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.baseForegroundColor = .white
        if showsChevron {
            config.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
            config.imagePlacement = .trailing
            config.imagePadding = 6
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return out
        }
        button.tintColor = ColorLayout.default_orange
        if selected { config.baseBackgroundColor = ColorLayout.default_orange }
        button.configuration = config
    }

    private func refreshSortBar() {
        for (i, option) in sortOptions.enumerated() {
            styleChip(sortButtons[i], title: option.title.localized, selected: option.key == currentOrdering)
        }
        let hasPeriod = sortOptions.first(where: { $0.key == currentOrdering })?.hasPeriod ?? false
        periodButton.isHidden = !hasPeriod
        let currentTitle = periodOptions.first(where: { $0.key == currentPeriod })?.title ?? "All Time"
        styleChip(periodButton, title: currentTitle.localized, selected: false, showsChevron: true)
        let actions = periodOptions.map { option in
            UIAction(title: option.title.localized, state: option.key == currentPeriod ? .on : .off) { [weak self] _ in
                self?.currentPeriod = option.key
                self?.applySort()
            }
        }
        periodButton.menu = UIMenu(children: actions)
        periodButton.showsMenuAsPrimaryAction = true
    }

    @objc private func onSortTap(_ sender: UIButton) {
        let option = sortOptions[sender.tag]
        guard option.key != currentOrdering else { return }
        currentOrdering = option.key
        if !option.hasPeriod { currentPeriod = nil }
        UISelectionFeedbackGenerator().selectionChanged()
        applySort()
    }

    private func applySort() {
        refreshSortBar()
        errorTextLabel.isHidden = true
        loadingData = true
        coordinator.videos = []
        collectionView.reloadData()
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
        collectionView.refreshControl?.beginRefreshing()
        coordinator.applySort(ordering: currentOrdering, period: currentPeriod)
    }

    func load(){
        self.collectionView.setupView(self)
        self.tabDelegate?.setHeader()
        
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 15, right: 8)
            flowLayout.minimumInteritemSpacing = 0
            flowLayout.minimumLineSpacing = 0
            flowLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 150)
            flowLayout.estimatedItemSize = CGSize(
                width: UIScreen.main.bounds.width - 2,
                height: 200
            )
            flowLayout.invalidateLayout()
        }
        
        self.view.addSubview(self.searchView)
        searchView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        searchView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        searchView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        searchView.heightAnchor.constraint(equalToConstant: 104).isActive = true
        
        self.searchView.addSubview(searchField)
        searchField.trailingAnchor.constraint(equalTo: self.searchView.trailingAnchor, constant: -30).isActive = true
        searchField.leadingAnchor.constraint(equalTo: self.searchView.leadingAnchor, constant: 30).isActive = true
        searchField.topAnchor.constraint(equalTo: self.searchView.topAnchor, constant: 8).isActive = true
        searchField.delegate = self
        searchField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        searchField.leftView?.frame = CGRect(x: 0, y: 0, width: 36, height: 20)
        searchField.leftView?.contentMode = .scaleAspectFit
        searchField.tintColor = ColorLayout.default_orange
        let searchGlass = Glass.make(shape: .capsule, fallbackFill: UIColor.white.withAlphaComponent(0.08))
        searchGlass.isUserInteractionEnabled = false
        self.searchView.insertSubview(searchGlass, belowSubview: searchField)
        NSLayoutConstraint.activate([
            searchGlass.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            searchGlass.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            searchGlass.topAnchor.constraint(equalTo: searchField.topAnchor),
            searchGlass.bottomAnchor.constraint(equalTo: searchField.bottomAnchor)
        ])
        self.searchGlass = searchGlass
        buildSortBar()
        
        let bottomRefreshController = UIRefreshControl()
        bottomRefreshController.tintColor = ColorLayout.default_text
        collectionView.bottomRefreshControl = bottomRefreshController
        coordinator = HomeViewCoordinator(self)
        self.loadingData = true
        collectionView.bottomRefreshControl?.beginRefreshing()
        coordinator.loadData()
        collectionView.keyboardDismissMode = .onDrag
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)

        collectionView.refreshControl = refreshControl
        collectionView.refreshControl?.bounds = CGRect(x: refreshControl.bounds.origin.x,
                                       y: -50,
                                       width: refreshControl.bounds.size.width,
                                       height: refreshControl.bounds.size.height)
        self.collectionView.refreshControl?.beginRefreshing()
    }
    
    @objc func onEnterPin(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.load()
        }
    }
    
    @objc func refresh(_ sender: Any) {
        DispatchQueue.main.async {
            self.coordinator.videos = []
            self.collectionView.reloadData()
            self.coordinator.loadData()
            self.collectionView.refreshControl?.beginRefreshing()
        }
    }
    
    func searchForCategory(category: String){
        self.searchField.text = ""
        self.loadingData = true
        self.coordinator.videos = []
        self.collectionView.reloadData()
        self.collectionView.refreshControl?.beginRefreshing()
        self.collectionView.bottomRefreshControl?.beginRefreshing()
        self.coordinator.searchForCategory(category: category)
    }
    
    @objc func onDidUpdateBookmarks(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension HomeViewController: UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.searchField.resignFirstResponder()
        DispatchQueue.main.async {
            self.loadingData = true
            self.coordinator.videos = []
            self.collectionView.reloadData()
            self.collectionView.refreshControl?.beginRefreshing()
            self.collectionView.bottomRefreshControl?.beginRefreshing()
            self.coordinator.search(searchText: textField.text.nilOrEmpty ? nil : textField.text)
        }
        return true
    }
}

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:

            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleSectionHeaderReusableView.className, for: indexPath) as! TitleSectionHeaderReusableView
            var titleText = "Home".localized
            if !self.coordinator.searchText.nilOrEmpty {
                titleText = String(format: "%@ Videos".localized, self.coordinator.searchText!)
            }
            else if !self.coordinator.category.nilOrEmpty {
                titleText = String(format: "%@ Videos".localized, self.coordinator.category!.capitalizingFirstLetter().replacingOccurrences(of: "-", with: " ").localized)
            }
            headerView.setupTitle(title: titleText)
            
            return headerView

        case UICollectionView.elementKindSectionFooter:
            return UICollectionReusableView()

        default:
            fatalError("Unexpected element kind")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.coordinator.videos.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row == 0 {
            let cat = collectionView.dequeueReusableCell(withReuseIdentifier: NavigationButtonCollectionViewCell.className, for: indexPath) as! NavigationButtonCollectionViewCell
            cat.setup(title: "Categories".localized) {
                let vc = CategoriesViewController()
                vc.tabDelegate = self.tabDelegate
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cat
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoCollectionViewCell.className, for: indexPath) as! VideoCollectionViewCell
        cell.setup(video: self.coordinator.videos[indexPath.row - 1])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let lastElement = (self.coordinator.videos.count + 1) - 1
        if !loadingData && indexPath.row == lastElement {
            collectionView.bottomRefreshControl?.beginRefreshing()
            loadingData = true
            self.coordinator.fetchNext()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            return
        }
        VideoPreviewViewController.present(fromView: self, video: self.coordinator.videos[indexPath.row - 1], delegate: self.tabDelegate)
    }
}

extension HomeViewController: HomeViewDelegate {
    func reloadView() {
        DispatchQueue.main.async {
            self.errorTextLabel.isHidden = true
            self.collectionView.bottomRefreshControl?.endRefreshing()
            self.collectionView.refreshControl?.endRefreshing()
            self.collectionView.reloadData()
            self.loadingData = false
        }
    }
    
    func showError(message: String){
        DispatchQueue.main.async {
            self.collectionView.bottomRefreshControl?.endRefreshing()
            self.collectionView.refreshControl?.endRefreshing()
            self.collectionView.reloadData()
            self.errorTextLabel.isHidden = false
            self.errorTextLabel.text = message
        }

    }
}

// MARK: - Two-column grid
extension HomeViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = collectionView.bounds.width - 16
        if indexPath.row == 0 {
            return CGSize(width: available, height: 66)
        }
        return CGSize(width: floor(available / 2), height: 250)
    }
}
