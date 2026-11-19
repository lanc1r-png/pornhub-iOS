//
//  ChannelViewController.swift
//  ICO-visualizer
//
//  Uploader (channel / model / user) page: header, sorting and an endless two-column video grid.
//

import UIKit
import SDWebImage
import SafariServices

private final class OwnerVideoCell: UICollectionViewCell {
    static let reuseId = "OwnerVideoCell"

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let viewsLabel = UILabel()
    private let durationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.applyCardStyle(cornerRadius: 20)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.05)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        viewsLabel.translatesAutoresizingMaskIntoConstraints = false
        viewsLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        viewsLabel.textColor = UIColor.white.withAlphaComponent(0.6)

        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        durationLabel.textColor = .white

        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(viewsLabel)
        contentView.addSubview(durationLabel)
        let badge = Glass.attachBadge(behind: durationLabel, in: contentView, insets: UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7))
        badge.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 9.0 / 16.0),
            durationLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -14),
            durationLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            viewsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            viewsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            viewsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static let rowHeight: CGFloat = 6 + 8 + 36 + 4 + 15 + 10

    func configure(_ video: OwnerVideo) {
        titleLabel.text = video.title
        viewsLabel.text = video.views.isEmpty ? "" : "\(video.views) " + "Views".localized
        durationLabel.text = video.duration
        durationLabel.superview?.isHidden = false
        if let thumb = video.thumb {
            imageView.sd_setImage(with: thumb, placeholderImage: nil, options: [.retryFailed, .scaleDownLargeImages, .highPriority], completed: nil)
        } else {
            imageView.sd_cancelCurrentImageLoad()
            imageView.image = nil
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

final class ChannelViewController: UIViewController {

    private let owner: VideoOwner
    private let tabDelegate: TabBarViewControllerDelegate?

    private var items: [OwnerVideo] = []
    private var sort: OwnerSort = .popular
    private var page = 1
    private var loading = false
    private var ended = false
    private var generation = 0
    private var opening = false

    private let segmented = UISegmentedControl(items: OwnerSort.allCases.map { $0.title })
    private let spinner = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 4, left: 16, bottom: 40, right: 16)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.register(OwnerVideoCell.self, forCellWithReuseIdentifier: OwnerVideoCell.reuseId)
        view.dataSource = self
        view.delegate = self
        return view
    }()

    init(owner: VideoOwner, delegate: TabBarViewControllerDelegate?) {
        self.owner = owner
        self.tabDelegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(from presenter: UIViewController, owner: VideoOwner, delegate: TabBarViewControllerDelegate?) {
        let controller = ChannelViewController(owner: owner, delegate: delegate)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            if #available(iOS 16.0, *) { sheet.preferredCornerRadius = 32 }
        }
        presenter.present(controller, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorLayout.default_background
        buildLayout()
        load(reset: true)
    }

    private func buildLayout() {
        // Avatar
        let avatar = UIView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.backgroundColor = ColorLayout.default_orange.withAlphaComponent(0.2)
        avatar.layer.cornerRadius = 32
        avatar.layer.borderWidth = 2
        avatar.layer.borderColor = ColorLayout.default_orange.cgColor
        let initial = UILabel()
        initial.translatesAutoresizingMaskIntoConstraints = false
        initial.text = String(owner.name.prefix(1)).uppercased()
        initial.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        initial.textColor = ColorLayout.default_orange
        avatar.addSubview(initial)
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 64),
            avatar.heightAnchor.constraint(equalToConstant: 64),
            initial.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initial.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)
        ])

        // Name + counters
        let name = UILabel()
        name.text = owner.name
        name.numberOfLines = 2
        let base = UIFont.systemFont(ofSize: 24, weight: .bold)
        name.font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 24) } ?? base
        name.textColor = .white
        let caption = UILabel()
        caption.text = [owner.subscribers, owner.videosCount].compactMap { $0 }.joined(separator: " · ")
        caption.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        caption.textColor = UIColor.white.withAlphaComponent(0.6)
        caption.numberOfLines = 2
        caption.isHidden = (caption.text ?? "").isEmpty
        let text = UIStackView(arrangedSubviews: [name, caption])
        text.axis = .vertical
        text.spacing = 4

        // Open on site
        let siteButton = UIButton(type: .system)
        var config = Glass.buttonConfiguration()
        config.image = UIImage(systemName: "safari", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        siteButton.configuration = config
        siteButton.addAction(UIAction { [weak self] _ in
            guard let self = self, let url = self.owner.siteURL else { return }
            self.present(SFSafariViewController(url: url), animated: true)
        }, for: .touchUpInside)
        siteButton.setContentHuggingPriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [avatar, text, siteButton])
        header.axis = .horizontal
        header.spacing = 14
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        // Sort
        segmented.selectedSegmentIndex = 0
        segmented.selectedSegmentTintColor = ColorLayout.default_orange
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.65), .font: UIFont.systemFont(ofSize: 14, weight: .semibold)], for: .normal)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .bold)], for: .selected)
        segmented.addTarget(self, action: #selector(onSortChange), for: .valueChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No data found".localized
        emptyLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        emptyLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        emptyLabel.isHidden = true

        view.addSubview(header)
        view.addSubview(segmented)
        view.addSubview(collectionView)
        view.addSubview(spinner)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmented.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmented.heightAnchor.constraint(equalToConstant: 38),
            collectionView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 60),
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 60)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: Loading

    @objc private func onSortChange() {
        sort = OwnerSort(rawValue: segmented.selectedSegmentIndex) ?? .popular
        load(reset: true)
    }

    private func load(reset: Bool) {
        if reset {
            generation += 1
            items = []
            page = 1
            ended = false
            loading = false
            collectionView.reloadData()
            collectionView.setContentOffset(.zero, animated: false)
            emptyLabel.isHidden = true
            spinner.startAnimating()
        }
        guard !loading, !ended else { return }
        loading = true
        let gen = generation
        VideoScraper.loadOwnerVideos(owner: owner, sort: sort, page: page) { [weak self] videos in
            guard let self = self, gen == self.generation else { return }
            self.loading = false
            self.spinner.stopAnimating()
            let known = Set(self.items.map { $0.key })
            let fresh = videos.filter { !known.contains($0.key) }
            if fresh.isEmpty {
                self.ended = true
                self.emptyLabel.isHidden = !self.items.isEmpty
                return
            }
            let start = self.items.count
            self.items.append(contentsOf: fresh)
            self.page += 1
            if start == 0 {
                self.collectionView.reloadData()
            } else {
                let paths = (start..<self.items.count).map { IndexPath(item: $0, section: 0) }
                self.collectionView.insertItems(at: paths)
            }
        }
    }
}

extension ChannelViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OwnerVideoCell.reuseId, for: indexPath) as! OwnerVideoCell
        cell.configure(items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 16
        let width = floor((collectionView.bounds.width - inset * 2 - 10) / 2)
        let imageWidth = width - 12
        return CGSize(width: max(width, 1), height: ceil(imageWidth * 9.0 / 16.0) + OwnerVideoCell.rowHeight)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item >= items.count - 4 { load(reset: false) }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !opening else { return }
        let item = items[indexPath.item]
        opening = true
        APIService.shared.getVideoById(id: item.key) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.opening = false
                var video: Video? = item.asVideo
                if case .success(let full) = result { video = full }
                guard let video = video else { return }
                VideoDetailViewController.present(from: self, video: video, delegate: self.tabDelegate)
            }
        }
    }
}
