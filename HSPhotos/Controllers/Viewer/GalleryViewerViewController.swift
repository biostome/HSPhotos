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

    init(assets: [PHAsset], initialIndex: Int, sourceFrame: CGRect = .zero, sourceImage: UIImage? = nil) {
        self.assets = assets
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
        sourceImage: UIImage? = nil
    ) -> UINavigationController {
        let viewer = GalleryViewerViewController(assets: assets, initialIndex: initialIndex, sourceFrame: sourceFrame, sourceImage: sourceImage)
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

        let toggleTap = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
        toggleTap.cancelsTouchesInView = false
        toggleTap.delegate = self
        view.addGestureRecognizer(toggleTap)

        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        pageViewController.view.addGestureRecognizer(dismissPan)

        for subview in pageViewController.view.subviews {
            if let sv = subview as? UIScrollView {
                sv.panGestureRecognizer.require(toFail: dismissPan)
                break
            }
        }
    }
}
