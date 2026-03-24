//
//  GalleryViewerViewController+Interaction.swift
//  HSPhotos
//

import UIKit
import Photos

// MARK: - 工具栏与操作

extension GalleryViewerViewController {
    @objc func closeTapped() {
        dismiss(animated: true)
    }

    @objc func toggleChrome() {
        isChromeHidden.toggle()
        let alpha: CGFloat = isChromeHidden ? 0 : 1
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.applyChromeVisibilityAlpha(alpha)
        })
    }

    @objc func editTapped() {
        presentAlert(title: "编辑", message: "调整与编辑功能可在此接入系统编辑流程。")
    }

    @objc func infoTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let vc = PhotoAssetInfoSheetViewController(asset: asset)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    @objc func shareTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        mediaActionService.loadShareItem(for: asset) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let item):
                self.presentShareSheet(item)
            case .failure(let error):
                self.presentAlert(title: "分享失败", message: error.localizedDescription)
            }
        }
    }

    @objc func favoriteTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        animateFavoriteButtonTap()
        mediaActionService.toggleFavorite(asset: asset) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let updatedAsset):
                self.assets[self.currentIndex] = updatedAsset
                self.updateTitleAndFavorite()
            case .failure(let error):
                let msg = error.localizedDescription.isEmpty ? "无法更新收藏状态" : error.localizedDescription
                self.presentAlert(title: "操作失败", message: msg)
            }
        }
    }

    private func animateFavoriteButtonTap() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
                self.favoriteButton.transform = .identity
            })
        })
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
        mediaActionService.delete(asset: asset) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                var newAssets = self.assets
                newAssets.remove(at: self.currentIndex)
                if newAssets.isEmpty {
                    self.dismiss(animated: true)
                    return
                }
                if let currentPage = self.currentPage {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
                        currentPage.view.alpha = 0
                        currentPage.view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    }, completion: { [weak self] _ in
                        guard let self else { return }
                        self.applyStateAfterDelete(newAssets)
                    })
                } else {
                    self.applyStateAfterDelete(newAssets)
                }
            case .failure(let error):
                let errorMessage = error.localizedDescription.isEmpty ? "无法删除媒体文件" : error.localizedDescription
                self.presentAlert(title: "删除失败", message: errorMessage)
            }
        }
    }

    private func presentShareSheet(_ item: GalleryViewerShareItem) {
        let activityItems: [Any]
        switch item {
        case .image(let image):
            activityItems = [image]
        case .videoURL(let url):
            activityItems = [url]
        }

        let activity = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 1, height: 1)
        }
        present(activity, animated: true)
    }

    private func applyStateAfterDelete(_ newAssets: [PHAsset]) {
        currentIndex = min(currentIndex, newAssets.count - 1)
        assets = newAssets
        thumbnailStripView.assets = newAssets
        if let page = pageForIndex(currentIndex) {
            pageViewController.setViewControllers([page], direction: .forward, animated: false)
        }
        updateTitleAndFavorite()
        thumbnailStripView.syncSelection(currentIndex, animated: false)
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

    /// 顶栏：自定义 topBar 或包在 NavigationController 时的系统导航栏
    func applyChromeVisibilityAlpha(_ alpha: CGFloat) {
        topBar.alpha = alpha
        bottomChromeContainer.alpha = alpha
        thumbnailStripView.alpha = alpha
        pageIndicator.alpha = alpha
        navigationController?.navigationBar.alpha = alpha
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
            applyChromeVisibilityAlpha(chromeAlpha)
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
                        self.applyChromeVisibilityAlpha(0)
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
                        self.applyChromeVisibilityAlpha(chromeAlpha)
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
        // 外层 toggleTap 不应抢占视频控件/按钮/slider 的点击，
        // 否则在播放、暂停、拖动进度时会误触发 chrome 隐藏。
        var current: UIView? = touch.view
        while let v = current {
            if v is UIControl {
                return false
            }
            current = v.superview
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
        guard let page = currentPage else {
            finishThumbnailDrivenPagingIfNeeded()
            return
        }
        guard completed else {
            finishThumbnailDrivenPagingIfNeeded()
            return
        }
        currentIndex = page.index
        updateTitleAndFavorite()
        if isPagingDrivenByThumbnailStrip {
            finishThumbnailDrivenPagingIfNeeded()
            return
        }
        thumbnailStripView.syncSelection(currentIndex, animated: true)
    }

    private func finishThumbnailDrivenPagingIfNeeded() {
        if isPagingDrivenByThumbnailStrip {
            isPagingDrivenByThumbnailStrip = false
        }
    }
}
