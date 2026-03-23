//
//  GalleryViewerViewController+Interaction.swift
//  HSPhotos
//

import UIKit
import Photos
import AVFoundation

// MARK: - 工具栏与操作

extension GalleryViewerViewController {
    @objc func closeTapped() {
        dismiss(animated: true)
    }

    @objc func toggleChrome() {
        isChromeHidden.toggle()
        let alpha: CGFloat = isChromeHidden ? 0 : 1
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.topBar.alpha = alpha
            self.bottomChromeContainer.alpha = alpha
            self.thumbnailStripView.alpha = alpha
            self.pageIndicator.alpha = alpha
        })
    }

    @objc func editTapped() {
        presentAlert(title: "编辑", message: "调整与编辑功能可在此接入系统编辑流程。")
    }

    @objc func infoTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let infoView = createInfoView(asset: asset)
        view.addSubview(infoView)
        infoView.alpha = 0
        infoView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            infoView.alpha = 1
            infoView.transform = .identity
        })
    }

    private func createInfoView(asset: PHAsset) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "照片信息"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        let infoLabel = UILabel()
        infoLabel.text = getAssetInfo(asset)
        infoLabel.font = .systemFont(ofSize: 14)
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .left
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(infoLabel)

        let closeBtn = UIButton(type: .system)
        let attributedTitle = NSAttributedString(
            string: "关闭",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.systemBlue
            ]
        )
        closeBtn.setAttributedTitle(attributedTitle, for: .normal)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeInfoView(_:)), for: .touchUpInside)
        containerView.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.6),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            closeBtn.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            closeBtn.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            closeBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            closeBtn.widthAnchor.constraint(equalToConstant: 80),
            closeBtn.heightAnchor.constraint(equalToConstant: 40)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeInfoView(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        return containerView
    }

    @objc func closeInfoView(_ sender: Any) {
        for subview in view.subviews {
            if subview.backgroundColor == UIColor.systemBackground.withAlphaComponent(0.95) && subview.layer.cornerRadius == 16 {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
                    subview.alpha = 0
                    subview.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                }, completion: { _ in
                    subview.removeFromSuperview()
                })
            }
        }
    }

    @objc func shareTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        if asset.mediaType == .image {
            shareImage(asset: asset)
        } else if asset.mediaType == .video {
            shareVideo(asset: asset)
        }
    }

    private func shareImage(asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
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

    private func shareVideo(asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard let avAsset = avAsset else {
                    self.presentAlert(title: "分享失败", message: "无法获取视频")
                    return
                }
                if let urlAsset = avAsset as? AVURLAsset {
                    let activity = UIActivityViewController(activityItems: [urlAsset.url], applicationActivities: nil)
                    if let popover = activity.popoverPresentationController {
                        popover.sourceView = self.view
                        popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 1, height: 1)
                    }
                    self.present(activity, animated: true)
                } else {
                    self.presentAlert(title: "分享失败", message: "无法处理视频资产")
                }
            }
        }
    }

    @objc func favoriteTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
                self.favoriteButton.transform = .identity
            })
        })
        PhotoChangesService.toggleFavorite(asset: asset) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
                if let updatedAsset = fetchResult.firstObject {
                    self.assets[self.currentIndex] = updatedAsset
                }
                self.updateTitleAndFavorite()
            } else {
                self.presentAlert(title: "操作失败", message: error ?? "无法更新收藏状态")
            }
        }
    }

    @objc func deleteTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let alert = UIAlertController(title: "删除媒体", message: "确定要删除这个媒体文件吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                guard let self = self else { return }
                if status == .authorized {
                    self.performDelete(asset: asset)
                } else {
                    DispatchQueue.main.async {
                        self.presentAlert(title: "权限不足", message: "需要相册权限才能删除媒体文件")
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func performDelete(asset: PHAsset) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        } completionHandler: { [weak self] success, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if success {
                    var newAssets = self.assets
                    newAssets.remove(at: self.currentIndex)
                    if newAssets.isEmpty {
                        self.dismiss(animated: true)
                        return
                    }
                    if let currentPage = self.pageViewController.viewControllers?.first as? PhotoPageViewController {
                        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
                            currentPage.view.alpha = 0
                            currentPage.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                        }, completion: { [weak self] _ in
                            guard let self = self else { return }
                            self.currentIndex = min(self.currentIndex, newAssets.count - 1)
                            self.assets = newAssets
                            self.thumbnailStripView.assets = newAssets
                            if let page = self.pageForIndex(self.currentIndex) {
                                self.pageViewController.setViewControllers([page], direction: .forward, animated: false)
                            }
                            self.updateTitleAndFavorite()
                            self.thumbnailStripView.syncSelection(self.currentIndex, animated: false)
                        })
                    } else {
                        self.assets = newAssets
                        self.thumbnailStripView.assets = newAssets
                        self.currentIndex = min(self.currentIndex, newAssets.count - 1)
                        if let page = self.pageForIndex(self.currentIndex) {
                            self.pageViewController.setViewControllers([page], direction: .forward, animated: false)
                        }
                        self.updateTitleAndFavorite()
                        self.thumbnailStripView.syncSelection(self.currentIndex, animated: false)
                    }
                } else {
                    let errorMessage = error?.localizedDescription ?? "无法删除媒体文件"
                    self.presentAlert(title: "删除失败", message: errorMessage)
                }
            }
        }
    }

    func updateTitleAndFavorite() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        let dateText = asset.creationDate.map { dateFormatter.string(from: $0) } ?? ""
        titleButton.setTitle(dateText.isEmpty ? " " : dateText, for: .normal)

        let heartName = asset.isFavorite ? "heart.fill" : "heart"
        var favConfig = favoriteButton.configuration ?? UIButton.Configuration.borderless()
        let m = GalleryViewerChromeMetrics.self
        let sym = UIImage.SymbolConfiguration(pointSize: m.capsuleInnerIconPointSize, weight: m.capsuleIconWeight)
        favConfig.image = UIImage(systemName: heartName, withConfiguration: sym)
        favConfig.baseForegroundColor = .white
        favoriteButton.configuration = favConfig

        pageIndicator.text = "\(currentIndex + 1)/\(assets.count)"
    }

    private func getAssetInfo(_ asset: PHAsset) -> String {
        var info = [String]()
        let mediaType: String
        switch asset.mediaType {
        case .image: mediaType = "图片"
        case .video: mediaType = "视频"
        default: mediaType = "未知"
        }
        info.append("类型: \(mediaType)")
        if let creationDate = asset.creationDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy年M月d日 HH:mm:ss"
            info.append("创建日期: \(df.string(from: creationDate))")
        }
        info.append("尺寸: \(asset.pixelWidth) × \(asset.pixelHeight)")
        info.append("收藏: \(asset.isFavorite ? "是" : "否")")
        return info.joined(separator: "\n")
    }

    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - 下滑关闭

extension GalleryViewerViewController {
    @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        switch gesture.state {
        case .began:
            dismissStartY = pageViewController.view.frame.origin.y
            isDismissing = false
        case .changed:
            let ty = translation.y
            let tx = translation.x
            let maxDistance: CGFloat = 300
            let progress = min(1.0, abs(ty) / maxDistance)
            let scale = 1.0 - (progress * 0.3)
            let backgroundAlpha = 1.0 - (progress * 0.95)
            pageViewController.view.transform = CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)
            view.backgroundColor = UIColor.black.withAlphaComponent(backgroundAlpha)
            let chromeAlpha = isChromeHidden ? 0 : (1.0 - progress)
            topBar.alpha = chromeAlpha
            bottomChromeContainer.alpha = chromeAlpha
            thumbnailStripView.alpha = chromeAlpha
            pageIndicator.alpha = chromeAlpha
        case .ended, .cancelled:
            let ty = translation.y
            let tx = translation.x
            let distanceThreshold: CGFloat = 120
            let velocityThreshold: CGFloat = 800
            let shouldDismiss = ty > distanceThreshold || velocity.y > velocityThreshold
            if shouldDismiss {
                isDismissing = true
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        self.pageViewController.view.transform = CGAffineTransform(translationX: tx, y: self.view.bounds.height)
                            .scaledBy(x: 0.3, y: 0.3)
                        self.view.backgroundColor = .clear
                        self.topBar.alpha = 0
                        self.bottomChromeContainer.alpha = 0
                        self.thumbnailStripView.alpha = 0
                        self.pageIndicator.alpha = 0
                    },
                    completion: { _ in
                        self.dismiss(animated: false)
                    }
                )
            } else {
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
                        self.bottomChromeContainer.alpha = chromeAlpha
                        self.thumbnailStripView.alpha = chromeAlpha
                        self.pageIndicator.alpha = chromeAlpha
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
            guard !isDismissing else { return false }
            let vel = dismissPan.velocity(in: view)
            guard abs(vel.y) > abs(vel.x) else { return false }
            guard vel.y > 0 else { return false }
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
        let location = touch.location(in: view)
        if bottomChromeContainer.frame.contains(location) {
            return false
        }
        if thumbnailStripView.frame.contains(location) {
            return false
        }
        for subview in view.subviews {
            if subview.backgroundColor == UIColor.systemBackground.withAlphaComponent(0.95) && subview.layer.cornerRadius == 16 {
                if subview.frame.contains(location) {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - UIPageViewController

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
        guard let page = pageViewController.viewControllers?.first as? PhotoPageViewController else {
            if isPagingDrivenByThumbnailStrip { isPagingDrivenByThumbnailStrip = false }
            return
        }
        guard completed else {
            if isPagingDrivenByThumbnailStrip { isPagingDrivenByThumbnailStrip = false }
            return
        }
        currentIndex = page.index
        updateTitleAndFavorite()
        if isPagingDrivenByThumbnailStrip {
            isPagingDrivenByThumbnailStrip = false
            return
        }
        thumbnailStripView.syncSelection(currentIndex, animated: true)
    }
}
