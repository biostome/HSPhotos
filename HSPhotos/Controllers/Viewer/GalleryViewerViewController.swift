//
//  GalleryViewerViewController.swift
//  HSPhotos
//
//  大图浏览器：分页、顶栏、底部 Liquid Glass 控制条、Hero 转场。
//  布局与操作见 GalleryViewerViewController+Setup / +Interaction；单页见 PhotoPageViewController。
//

import UIKit
import Photos

class GalleryViewerViewController: UIViewController {
    var assets: [PHAsset]
    let mediaActionService: GalleryViewerMediaActionHandling

    let pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: nil
    )

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
        let v = UIVisualEffectView(effect: glass)
        v.cornerConfiguration = .capsule()
        v.clipsToBounds = true
        return v
    }()

    let pageIndicator = UILabel()
    let thumbnailStripView = GalleryViewerThumbnailStripView()

    var currentIndex: Int
    /// 为 true 时表示当前页码由缩略条滑动驱动，delegate 里不再对缩略条做 scrollToItem，避免与用户滑动冲突。
    var isPagingDrivenByThumbnailStrip = false
    var isChromeHidden = false

    let dismissPan = UIPanGestureRecognizer()
    var dismissStartY: CGFloat = 0
    var isDismissing = false

    var heroTransitionDelegate: HeroPhotoTransitionDelegate?

    /// 初始贴满屏底；`setupThumbnailStrip` 后改为贴到缩略条上方，避免分页容器盖住底栏触摸。
    var pageViewBottomConstraint: NSLayoutConstraint!

    var currentPage: PhotoPageViewController? {
        pageViewController.viewControllers?.first as? PhotoPageViewController
    }

    init(
        assets: [PHAsset],
        initialIndex: Int,
        sourceFrame: CGRect = .zero,
        sourceImage: UIImage? = nil,
        mediaActionService: GalleryViewerMediaActionHandling = GalleryViewerMediaActionService()
    ) {
        self.assets = assets
        self.mediaActionService = mediaActionService
        self.currentIndex = min(max(0, initialIndex), max(0, assets.count - 1))
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

    /// 以 `UINavigationController` 包一层再 present，与 App 内其它页一致使用系统导航栏；Hero 转场需赋给外层 `transitioningDelegate`。
    static func makePresentingNavigationContainer(
        assets: [PHAsset],
        initialIndex: Int,
        sourceFrame: CGRect = .zero,
        sourceImage: UIImage? = nil,
        mediaActionService: GalleryViewerMediaActionHandling = GalleryViewerMediaActionService()
    ) -> UINavigationController {
        let viewer = GalleryViewerViewController(
            assets: assets,
            initialIndex: initialIndex,
            sourceFrame: sourceFrame,
            sourceImage: sourceImage,
            mediaActionService: mediaActionService
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

        setupPageViewController()
        setupTopBar()
        setupBottomBar()
        setupThumbnailStrip()
        setupPageIndicator()
        updateTitleAndFavorite()
        setupPageGestures()
    }

    /// 保持 chrome 在最上层；**底栏必须在缩略条之后** `bringSubviewToFront`，否则缩略条会盖住 Liquid Glass 按钮。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bringChromeToFront()
    }
}

private extension GalleryViewerViewController {
    func setupPageGestures() {
        // 点按仅加在分页容器上：避免挂在根 view 上与顶栏/底栏控件抢触摸；根 view 上的全屏手势在 iOS 上常与按钮冲突。
        let toggleTap = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
        toggleTap.cancelsTouchesInView = false
        toggleTap.delegate = self
        pageViewController.view.addGestureRecognizer(toggleTap)

        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        pageViewController.view.addGestureRecognizer(dismissPan)

        guard let pageScrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            return
        }
        pageScrollView.panGestureRecognizer.require(toFail: dismissPan)
    }

    func bringChromeToFront() {
        if !topBar.isHidden {
            view.bringSubviewToFront(topBar)
        }
        view.bringSubviewToFront(thumbnailStripView)
        view.bringSubviewToFront(bottomChromeContainer)
        view.bringSubviewToFront(pageIndicator)
    }
}
