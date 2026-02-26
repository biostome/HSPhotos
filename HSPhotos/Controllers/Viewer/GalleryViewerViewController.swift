//
//  GalleryViewerViewController.swift
//  HSPhotos
//
//  Created by Hans on 2026/02/26.
//

import UIKit
import Photos
import AVFoundation

class GalleryViewerViewController: UIViewController {
    private var assets: [PHAsset]
    private let initialIndex: Int
    
    // 页面控制器
    private let pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: nil
    )
    
    // 工具栏
    private let closeButton = UIButton(type: .system)
    private let titleButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let favoriteButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let topBar = UIView()
    private let bottomBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    
    // 状态
    private var currentIndex: Int
    private var isChromeHidden = false
    
    // 手势
    private let dismissPan = UIPanGestureRecognizer()
    private var dismissStartY: CGFloat = 0
    private var isDismissing = false
    
    /// 持有 Hero 转场 delegate，避免提前释放
    var heroTransitionDelegate: HeroPhotoTransitionDelegate?
    
    init(assets: [PHAsset], initialIndex: Int, sourceFrame: CGRect = .zero, sourceImage: UIImage? = nil) {
        self.assets = assets
        self.initialIndex = min(max(0, initialIndex), max(0, assets.count - 1))
        self.currentIndex = self.initialIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        
        // 设置转场动画
        if sourceFrame != .zero {
            heroTransitionDelegate = HeroPhotoTransitionDelegate()
            heroTransitionDelegate?.sourceFrame = sourceFrame
            heroTransitionDelegate?.sourceImage = sourceImage
            transitioningDelegate = heroTransitionDelegate
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // 重新获取所有资产的最新信息，确保收藏状态正确
        updateAssetsWithLatestInfo()
        
        setupPageViewController()
        setupTopBar()
        setupBottomBar()
        updateTitleAndFavorite()
        
        // 添加点击手势，用于显示/隐藏工具栏
        let toggleTap = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
        toggleTap.cancelsTouchesInView = false
        toggleTap.delegate = self
        view.addGestureRecognizer(toggleTap)
        
        // 添加拖动手势，用于关闭浏览器
        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        pageViewController.view.addGestureRecognizer(dismissPan)
        
        // 确保拖动手势在页面滚动之前触发
        for subview in pageViewController.view.subviews {
            if let sv = subview as? UIScrollView {
                sv.panGestureRecognizer.require(toFail: dismissPan)
                break
            }
        }
    }
    
    // MARK: - 页面控制器设置
    private func setupPageViewController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置背景为透明
        pageViewController.view.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        pageViewController.didMove(toParent: self)
        
        // 显示初始页面
        if let first = pageForIndex(currentIndex) {
            pageViewController.setViewControllers([first], direction: .forward, animated: false)
        }
    }
    
    private func pageForIndex(_ index: Int) -> PhotoPageViewController? {
        guard index >= 0, index < assets.count else { return nil }
        let page = PhotoPageViewController(asset: assets[index])
        page.index = index
        return page
    }
    
    // MARK: - 工具栏设置
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        // 关闭按钮
        closeButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        closeButton.tintColor = .label
        closeButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        // 标题按钮
        titleButton.titleLabel?.numberOfLines = 2
        titleButton.titleLabel?.textAlignment = .center
        titleButton.setTitleColor(.label, for: .normal)
        titleButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        titleButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        
        // 编辑按钮
        editButton.setTitle("编辑", for: .normal)
        editButton.setTitleColor(.label, for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        editButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        editButton.layer.cornerRadius = 16
        editButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        
        // 添加按钮到顶部栏
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(closeButton)
        topBar.addSubview(editButton)
        topBar.addSubview(titleButton)
        
        // 设置约束
        closeButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        editButton.setContentHuggingPriority(.required, for: .horizontal)
        
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.heightAnchor.constraint(equalToConstant: 44),
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -4),
            editButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleButton.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleButton.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            titleButton.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -8)
        ])
    }
    
    private func setupBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.layer.cornerRadius = 16
        bottomBar.clipsToBounds = true
        view.addSubview(bottomBar)
        
        // 配置底部按钮
        configureBottomButton(shareButton, icon: "square.and.arrow.up", title: "分享")
        configureBottomButton(favoriteButton, icon: "heart", title: "收藏")
        configureBottomButton(deleteButton, icon: "trash", title: "删除")
        
        // 添加按钮点击事件
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        
        // 创建底部按钮堆栈
        let bottomStack = UIStackView(arrangedSubviews: [shareButton, favoriteButton, deleteButton])
        bottomStack.axis = .horizontal
        bottomStack.distribution = .equalSpacing
        bottomStack.spacing = 32
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.contentView.addSubview(bottomStack)
        
        // 设置约束
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottomBar.heightAnchor.constraint(equalToConstant: 72),
            bottomStack.centerXAnchor.constraint(equalTo: bottomBar.contentView.centerXAnchor),
            bottomStack.centerYAnchor.constraint(equalTo: bottomBar.contentView.centerYAnchor)
        ])
    }
    
    private func configureBottomButton(_ button: UIButton, icon: String, title: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 6
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { _ in
            var attr = AttributeContainer()
            attr.font = .systemFont(ofSize: 12, weight: .medium)
            return attr
        }
        button.configuration = config
        button.tintColor = .label
    }
    
    // MARK: - 工具栏操作
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func toggleChrome() {
        isChromeHidden.toggle()
        let alpha: CGFloat = isChromeHidden ? 0 : 1
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.topBar.alpha = alpha
            self.bottomBar.alpha = alpha
        })
    }
    
    @objc private func infoTapped() {
        // 显示图片信息
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        let alert = UIAlertController(title: "图片信息", message: getAssetInfo(asset), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func editTapped() {
        // 编辑操作
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        let alert = UIAlertController(title: "编辑", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 1, height: 1)
        }
        
        present(alert, animated: true)
    }
    
    @objc private func shareTapped() {
        // 分享操作
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        // 获取图片
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
            DispatchQueue.main.async {
                guard let image = image else {
                    self.presentAlert(title: "分享失败", message: "无法获取图片")
                    return
                }
                
                let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                if let popover = activity.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 1, height: 1)
                }
                self.present(activity, animated: true)
            }
        }
    }
    
    @objc private func favoriteTapped() {
        // 收藏操作
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        // 使用PhotoChangesService处理收藏操作
        PhotoChangesService.toggleFavorite(asset: asset) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                // 重新获取最新的资产信息
                let fetchOptions = PHFetchOptions()
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: fetchOptions)
                if let updatedAsset = fetchResult.firstObject {
                    // 更新assets数组中的资产
                    self.assets[self.currentIndex] = updatedAsset
                }
                // 更新UI
                self.updateTitleAndFavorite()
            } else {
                self.presentAlert(title: "操作失败", message: error ?? "无法更新收藏状态")
            }
        }
    }
    
    @objc private func deleteTapped() {
        // 删除操作
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        let alert = UIAlertController(title: "删除照片", message: "确定要删除这张照片吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // 删除照片
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        // 从数组中移除
                        var newAssets = self.assets
                        newAssets.remove(at: self.currentIndex)
                        
                        if newAssets.isEmpty {
                            self.dismiss(animated: true)
                            return
                        }
                        
                        // 更新当前索引
                        self.currentIndex = min(self.currentIndex, newAssets.count - 1)
                        
                        // 更新页面
                        if let page = self.pageForIndex(self.currentIndex) {
                            self.pageViewController.setViewControllers([page], direction: .forward, animated: false)
                        }
                        
                        self.updateTitleAndFavorite()
                    } else {
                        self.presentAlert(title: "删除失败", message: "无法删除照片")
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - 辅助方法
    private func updateTitleAndFavorite() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        
        // 更新标题
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        let dateText = asset.creationDate.map { dateFormatter.string(from: $0) } ?? ""
        let title = dateText.isEmpty ? " " : dateText
        titleButton.setTitle(title, for: .normal)
        
        // 更新收藏按钮
        if var config = favoriteButton.configuration {
            config.image = UIImage(systemName: asset.isFavorite ? "heart.fill" : "heart")
            favoriteButton.configuration = config
        }
    }
    
    private func getAssetInfo(_ asset: PHAsset) -> String {
        var info = [String]()
        
        // 媒体类型
        let mediaType: String
        switch asset.mediaType {
        case .image:
            mediaType = "图片"
        case .video:
            mediaType = "视频"
        default:
            mediaType = "未知"
        }
        info.append("类型: \(mediaType)")
        
        // 创建日期
        if let creationDate = asset.creationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
            info.append("创建日期: \(dateFormatter.string(from: creationDate))")
        }
        
        // 尺寸
        info.append("尺寸: \(asset.pixelWidth) × \(asset.pixelHeight)")
        
        // 收藏状态
        info.append("收藏: \(asset.isFavorite ? "是" : "否")")
        
        return info.joined(separator: "\n")
    }
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
    
    /// 重新获取所有资产的最新信息，确保收藏状态正确
    private func updateAssetsWithLatestInfo() {
        // 获取所有资产的本地标识符
        let localIdentifiers = assets.map { $0.localIdentifier }
        
        // 根据本地标识符获取最新的资产信息
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: fetchOptions)
        
        // 更新assets数组
        var updatedAssets = [PHAsset]()
        fetchResult.enumerateObjects { asset, _, _ in
            updatedAssets.append(asset)
        }
        
        // 确保更新后的数组与原数组顺序一致
        if updatedAssets.count == assets.count {
            // 按原顺序重新排列资产
            var orderedAssets = [PHAsset]()
            for localIdentifier in localIdentifiers {
                if let asset = updatedAssets.first(where: { $0.localIdentifier == localIdentifier }) {
                    orderedAssets.append(asset)
                }
            }
            if orderedAssets.count == assets.count {
                assets = orderedAssets
            }
        }
    }
    
    // MARK: - 拖动手势处理
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            dismissStartY = pageViewController.view.frame.origin.y
            isDismissing = false
            
        case .changed:
            let ty = translation.y
            
            // 只处理向下拖动
            if ty < 0 {
                return
            }
            
            // 计算缩放比例和透明度
            let maxDistance: CGFloat = 300
            let progress = min(1.0, ty / maxDistance)
            
            // 缩放：从 1.0 缩小到 0.7
            let scale = 1.0 - (progress * 0.3)
            
            // 黑色背景透明度：从 1.0 渐变到 0
            let backgroundAlpha = 1.0 - (progress * 0.95)
            
            // 应用变换
            pageViewController.view.transform = CGAffineTransform(translationX: 0, y: ty)
                .scaledBy(x: scale, y: scale)
            
            // 控制整个视图的背景透明度
            view.backgroundColor = UIColor.black.withAlphaComponent(backgroundAlpha)
            
            // 顶部、底部栏跟随渐隐
            let chromeAlpha = isChromeHidden ? 0 : (1.0 - progress)
            topBar.alpha = chromeAlpha
            bottomBar.alpha = chromeAlpha
            
        case .ended, .cancelled:
            let ty = translation.y
            
            // 判断是否应该关闭
            let distanceThreshold: CGFloat = 120
            let velocityThreshold: CGFloat = 800
            
            let shouldDismiss = ty > distanceThreshold || velocity.y > velocityThreshold
            
            if shouldDismiss {
                // 执行关闭动画
                isDismissing = true
                
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        // 继续移动并缩小
                        self.pageViewController.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                            .scaledBy(x: 0.3, y: 0.3)
                        // 背景变透明
                        self.view.backgroundColor = .clear
                        self.topBar.alpha = 0
                        self.bottomBar.alpha = 0
                    },
                    completion: { _ in
                        // 关闭
                        self.dismiss(animated: false)
                    }
                )
            } else {
                // 弹回原位
                UIView.animate(
                    withDuration: 0.4,
                    delay: 0,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: {
                        self.pageViewController.view.transform = .identity
                        self.view.backgroundColor = .black
                        
                        let chromeAlpha: CGFloat = self.isChromeHidden ? 0 : 1
                        self.topBar.alpha = chromeAlpha
                        self.bottomBar.alpha = chromeAlpha
                    },
                    completion: nil
                )
            }
            
        default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension GalleryViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === dismissPan {
            // 防止在关闭动画进行中触发新的手势
            guard !isDismissing else { return false }
            
            let vel = dismissPan.velocity(in: view)
            
            // 必须是垂直方向的手势（Y 方向速度大于 X 方向）
            guard abs(vel.y) > abs(vel.x) else { return false }
            
            // 必须是向下的手势
            guard vel.y > 0 else { return false }
            
            // 如果当前页面正在缩放，不允许关闭手势
            if let page = pageViewController.viewControllers?.first as? PhotoPageViewController {
                if page.scrollViewZoomScale > 1 {
                    return false
                }
            }
            
            return true
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击在底部工具栏上，不触发 toggleChrome
        let location = touch.location(in: view)
        
        // 检查是否点击在底部工具栏上
        if bottomBar.frame.contains(location) {
            return false
        }
        
        return true
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate

extension GalleryViewerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PhotoPageViewController else { return nil }
        return pageForIndex(page.index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PhotoPageViewController else { return nil }
        return pageForIndex(page.index + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let page = pageViewController.viewControllers?.first as? PhotoPageViewController else { return }
        currentIndex = page.index
        updateTitleAndFavorite()
    }
}

// MARK: - PhotoPageViewController

private class PhotoPageViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let playerContainerView = UIView()
    private var playerLayer: AVPlayerLayer?
    private(set) var player: AVPlayer?
    
    let asset: PHAsset
    var index: Int = 0
    var scrollViewZoomScale: CGFloat { scrollView.zoomScale }
    
    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 设置为透明，让黑色背景层显示出来
        view.backgroundColor = .clear
        
        // 设置滚动视图
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 设置图片视图
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        // 设置视频容器
        playerContainerView.backgroundColor = .clear
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(playerContainerView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            playerContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            playerContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            playerContainerView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        // 添加双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // 默认只显示 imageView
        playerContainerView.isHidden = true
        
        // 加载媒体
        loadMedia()
    }
    
    /// 处理双击手势
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        
        if scrollView.zoomScale == 1 {
            // 当前是原始大小，双击放大到2倍
            let zoomInScale: CGFloat = 2
            scrollView.zoom(to: CGRect(x: point.x - 100, y: point.y - 100, width: 200, height: 200), animated: true)
        } else {
            // 当前已经放大，双击恢复原始大小
            scrollView.setZoomScale(1, animated: true)
        }
    }
    
    private func loadMedia() {
        let targetSize = fullScreenPixelSize()
        
        switch asset.mediaType {
        case .image:
            // 加载图片
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            // 先加载缩略图
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: options) { [weak self] image, info in
                DispatchQueue.main.async { self?.imageView.image = image }
            }
            
            // 再加载高质量图片
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, info in
                DispatchQueue.main.async {
                    guard let self, let image = image else { return }
                    
                    // 渐变过渡到高质量图片
                    if self.imageView.image != nil {
                        let tempImageView = UIImageView(image: image)
                        tempImageView.contentMode = .scaleAspectFit
                        tempImageView.frame = self.imageView.frame
                        tempImageView.alpha = 0
                        self.imageView.superview?.addSubview(tempImageView)
                        
                        UIView.animate(withDuration: 0.3) {
                            tempImageView.alpha = 1
                        } completion: { _ in
                            self.imageView.image = image
                            tempImageView.removeFromSuperview()
                        }
                    } else {
                        self.imageView.image = image
                    }
                }
            }
            
        case .video:
            // 加载视频
            playerContainerView.isHidden = false
            
            // 先加载缩略图
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, info in
                DispatchQueue.main.async { self?.imageView.image = image }
            }
            
            // 加载视频
            let videoOptions = PHVideoRequestOptions()
            videoOptions.deliveryMode = .highQualityFormat
            videoOptions.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { [weak self] avAsset, audioMix, info in
                DispatchQueue.main.async {
                    guard let self, let avAsset else { return }
                    
                    let playerItem = AVPlayerItem(asset: avAsset)
                    let player = AVPlayer(playerItem: playerItem)
                    self.player = player
                    
                    let playerLayer = AVPlayerLayer(player: player)
                    playerLayer.videoGravity = .resizeAspect
                    playerLayer.frame = self.playerContainerView.bounds
                    self.playerContainerView.layer.addSublayer(playerLayer)
                    self.playerLayer = playerLayer
                    
                    // 开始播放
                    player.play()
                    
                    // 延迟后渐变过渡到视频
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        UIView.animate(withDuration: 0.3) {
                            self?.imageView.alpha = 0
                        } completion: { _ in
                            self?.imageView.isHidden = true
                            self?.imageView.alpha = 1
                        }
                    }
                }
            }
            
        default:
            break
        }
    }
    
    private func fullScreenPixelSize() -> CGSize {
        let size = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainerView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoPageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if asset.mediaType == .video && !playerContainerView.isHidden {
            return playerContainerView
        } else {
            return imageView
        }
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 视频缩放时，更新 playerLayer 的 frame
        if asset.mediaType == .video, let playerLayer = playerLayer {
            playerLayer.frame = playerContainerView.bounds
        }
    }
}
