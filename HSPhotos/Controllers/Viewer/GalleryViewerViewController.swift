//
//  GalleryViewerViewController.swift
//  HSPhotos
//
//  大图浏览器：UICollectionView 横向分页、顶栏、底部 Liquid Glass 控制条、Hero 转场。
//

import UIKit
import Photos

final class GalleryViewerViewController: UIViewController {
    var assets: [PHAsset]
    let mediaActionService: GalleryViewerMediaActionHandling
    let mediaCellTypes: [any GalleryViewerMediaCell.Type]
    let initialPlaceholderIndex: Int
    let initialPlaceholderImage: UIImage?

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.decelerationRate = .fast
        view.contentInsetAdjustmentBehavior = .never
        view.translatesAutoresizingMaskIntoConstraints = false
        view.dataSource = self
        view.delegate = self
        mediaCellTypes.forEach { $0.register(on: view) }
        return view
    }()

    let closeButton = UIButton(type: .system)
    let titleButton = UIButton(type: .system)
    let shareButton = UIButton(type: .system)
    let favoriteButton = UIButton(type: .system)
    let infoButton = UIButton(type: .system)
    let editButton = UIButton(type: .system)
    let deleteButton = UIButton(type: .system)
    let topBar = UIView()
    let bottomChromeContainer = UIView()
    let centerCapsule: UIVisualEffectView = {
        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = true
        let view = UIVisualEffectView(effect: glass)
        view.cornerConfiguration = .capsule()
        view.clipsToBounds = true
        return view
    }()

    let pageIndicator = UILabel()
    let thumbnailStripView = GalleryViewerThumbnailStripView()

    var currentIndex: Int
    var isPagingDrivenByThumbnailStrip = false
    var isChromeHidden = false

    let dismissPan = UIPanGestureRecognizer()
    var isDismissing = false

    var heroTransitionDelegate: HeroPhotoTransitionDelegate?

    private var hasAppliedInitialScrollPosition = false

    var currentMediaCell: PhotoCellBase? {
        let indexPath = IndexPath(item: currentIndex, section: 0)
        return collectionView.cellForItem(at: indexPath) as? PhotoCellBase
    }

    init(
        assets: [PHAsset],
        initialIndex: Int,
        sourceFrame: CGRect = .zero,
        sourceImage: UIImage? = nil,
        mediaActionService: GalleryViewerMediaActionHandling = GalleryViewerMediaActionService(),
        mediaCellTypes: [any GalleryViewerMediaCell.Type] = [ImageCell.self, VideoCell.self]
    ) {
        self.assets = assets
        self.mediaActionService = mediaActionService
        self.mediaCellTypes = mediaCellTypes
        self.currentIndex = min(max(0, initialIndex), max(0, assets.count - 1))
        self.initialPlaceholderIndex = self.currentIndex
        self.initialPlaceholderImage = sourceImage
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen

        if sourceFrame != .zero {
            heroTransitionDelegate = HeroPhotoTransitionDelegate()
            heroTransitionDelegate?.sourceFrame = sourceFrame
            heroTransitionDelegate?.sourceImage = sourceImage
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func makePresentingNavigationContainer(
        assets: [PHAsset],
        initialIndex: Int,
        sourceFrame: CGRect = .zero,
        sourceImage: UIImage? = nil,
        mediaActionService: GalleryViewerMediaActionHandling = GalleryViewerMediaActionService(),
        mediaCellTypes: [any GalleryViewerMediaCell.Type] = [ImageCell.self, VideoCell.self]
    ) -> UINavigationController {
        let viewer = GalleryViewerViewController(
            assets: assets,
            initialIndex: initialIndex,
            sourceFrame: sourceFrame,
            sourceImage: sourceImage,
            mediaActionService: mediaActionService,
            mediaCellTypes: mediaCellTypes
        )
        let nav = UINavigationController(rootViewController: viewer)
        nav.modalPresentationStyle = .overFullScreen
        if let hero = viewer.heroTransitionDelegate {
            nav.transitioningDelegate = hero
        }
        return nav
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCollectionView()
        setupTopBar()
        setupBottomBar()
        setupThumbnailStrip()
        setupPageIndicator()
        updateTitleAndFavorite()
        setupPageGestures()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionViewItemSizeIfNeeded()
        applyInitialScrollPositionIfNeeded()
        bringChromeToFront()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateActivePageState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setVisibleMediaCellsActive(false)
    }
}

extension GalleryViewerViewController {
    func setupPageGestures() {
        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        collectionView.addGestureRecognizer(dismissPan)
        collectionView.panGestureRecognizer.require(toFail: dismissPan)
    }

    func bringChromeToFront() {
        if !topBar.isHidden {
            view.bringSubviewToFront(topBar)
        }
        view.bringSubviewToFront(thumbnailStripView)
        view.bringSubviewToFront(bottomChromeContainer)
        view.bringSubviewToFront(pageIndicator)
    }

    func updateCollectionViewItemSizeIfNeeded() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let size = collectionView.bounds.size
        guard size.width > 0, size.height > 0, layout.itemSize != size else { return }
        layout.itemSize = size
        layout.invalidateLayout()
        if hasAppliedInitialScrollPosition {
            scrollToIndex(currentIndex, animated: false)
        }
    }

    func applyInitialScrollPositionIfNeeded() {
        guard !hasAppliedInitialScrollPosition, collectionView.bounds.width > 0 else { return }
        hasAppliedInitialScrollPosition = true
        collectionView.layoutIfNeeded()
        scrollToIndex(currentIndex, animated: false)
        updateActivePageState()
    }

    func scrollToIndex(_ index: Int, animated: Bool) {
        guard index >= 0, index < assets.count else { return }
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: animated)
    }

    func updateActivePageState() {
        for case let cell as PhotoCellBase in collectionView.visibleCells {
            if let indexPath = collectionView.indexPath(for: cell) {
                cell.isPageActive = indexPath.item == currentIndex
            } else {
                cell.isPageActive = false
            }
        }
    }

    func setVisibleMediaCellsActive(_ isActive: Bool) {
        for case let cell as PhotoCellBase in collectionView.visibleCells {
            cell.isPageActive = isActive && collectionView.indexPath(for: cell)?.item == currentIndex
        }
    }

    var currentDismissTransformView: UIView? {
        currentMediaCell?.dismissTransformView
    }
}
