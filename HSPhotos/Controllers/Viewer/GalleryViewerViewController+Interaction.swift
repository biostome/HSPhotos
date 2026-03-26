//
//  GalleryViewerViewController+Interaction.swift
//  HSPhotos
//

import UIKit
import Photos

extension GalleryViewerViewController {
    @objc func closeTapped() {
        dismiss(animated: true)
    }

    @objc func toggleChrome() {
        isChromeHidden.toggle()
        let alpha: CGFloat = isChromeHidden ? 0 : 1
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.applyChromeVisibilityAlpha(alpha)
        }
    }

    @objc func editTapped() {
        presentAlert(title: "编辑", message: "调整与编辑功能可在此接入系统编辑流程。")
    }

    @objc func infoTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let vc = PhotoAssetInfoSheetViewController(asset: asset)
        
        vc.onAlbumSelected = { [weak self] collection in
            self?.dismiss(animated: true) {
                if let coll = collection, let nav = self?.navigationController {
                    let photoVC = PhotoGridViewController(collection: coll)
                    nav.pushViewController(photoVC, animated: true)
                }
            }
        }
        
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
            guard let self else { return }
            switch result {
            case .success(let updatedAsset):
                self.assets[self.currentIndex] = updatedAsset
                self.updateVisibleCellIfNeeded(with: updatedAsset)
                self.updateTitleAndFavorite()
                self.thumbnailStripView.assets = self.assets
                self.thumbnailStripView.syncSelection(self.currentIndex, animated: false)
            case .failure(let error):
                let msg = error.localizedDescription.isEmpty ? "无法更新收藏状态" : error.localizedDescription
                self.presentAlert(title: "操作失败", message: msg)
            }
        }
    }

    private func updateVisibleCellIfNeeded(with asset: PHAsset) {
        guard let cell = currentMediaCell else { return }
        cell.configure(with: asset, at: currentIndex)
        cell.isPageActive = true
    }

    private func animateFavoriteButtonTap() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
                self.favoriteButton.transform = .identity
            }
        })
    }

    @objc func deleteTapped() {
        guard currentIndex >= 0, currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let alert = UIAlertController(title: "删除媒体", message: "确定要删除这个媒体文件吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                guard let self else { return }
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
                self.applyStateAfterDelete(newAssets)
            case .failure(let error):
                let message = error.localizedDescription.isEmpty ? "无法删除媒体文件" : error.localizedDescription
                self.presentAlert(title: "删除失败", message: message)
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
        collectionView.reloadData()
        thumbnailStripView.assets = newAssets
        thumbnailStripView.syncSelection(currentIndex, animated: false)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scrollToIndex(self.currentIndex, animated: false)
            self.updateTitleAndFavorite()
            self.updateActivePageState()
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
        let metrics = GalleryViewerChromeMetrics.self
        let symbol = UIImage.SymbolConfiguration(pointSize: metrics.capsuleInnerIconPointSize, weight: metrics.capsuleIconWeight)
        favConfig.image = UIImage(systemName: heartName, withConfiguration: symbol)
        favConfig.baseForegroundColor = .white
        favoriteButton.configuration = favConfig

        pageIndicator.text = "\(currentIndex + 1)/\(assets.count)"
    }

    func applyChromeVisibilityAlpha(_ alpha: CGFloat) {
        topBar.alpha = alpha
        bottomChromeContainer.alpha = alpha
        thumbnailStripView.alpha = alpha
        pageIndicator.alpha = alpha
        navigationController?.navigationBar.alpha = alpha
        let shouldShowInlineControls = alpha > 0.001
        for case let cell as PhotoCellBase in collectionView.visibleCells {
            cell.setInlineControlsVisible(shouldShowInlineControls, animated: false)
        }
    }

    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

extension GalleryViewerViewController {
    @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        switch gesture.state {
        case .began:
            isDismissing = false
        case .changed:
            guard let dismissTargetView = currentDismissTransformView else { return }
            let progress = min(1.0, abs(translation.y) / 300)
            let scale = 1.0 - (progress * 0.3)
            let backgroundAlpha = 1.0 - (progress * 0.95)
            dismissTargetView.transform = CGAffineTransform(translationX: translation.x, y: translation.y).scaledBy(x: scale, y: scale)
            view.backgroundColor = UIColor.black.withAlphaComponent(backgroundAlpha)
            let chromeAlpha = isChromeHidden ? 0 : (1.0 - progress)
            applyChromeVisibilityAlpha(chromeAlpha)
        case .ended, .cancelled:
            guard let dismissTargetView = currentDismissTransformView else { return }
            let shouldDismiss = translation.y > 120 || velocity.y > 800
            if shouldDismiss {
                isDismissing = true
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut, .beginFromCurrentState],
                    animations: {
                        dismissTargetView.transform = CGAffineTransform(translationX: translation.x, y: self.view.bounds.height)
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
                        dismissTargetView.transform = .identity
                        self.view.backgroundColor = .black
                        let chromeAlpha: CGFloat = self.isChromeHidden ? 0 : 1
                        self.applyChromeVisibilityAlpha(chromeAlpha)
                    }
                )
            }
        default:
            break
        }
    }
}

extension GalleryViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === dismissPan {
            guard !isDismissing else { return false }
            let velocity = dismissPan.velocity(in: view)
            guard abs(velocity.y) > abs(velocity.x), velocity.y > 0 else { return false }
            if let cell = currentMediaCell {
                if cell.scrollViewZoomScale > 1 || cell.isPlaybackControlsInteracting {
                    return false
                }
            }
            return true
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current: UIView? = touch.view
        while let view = current {
            if view is UIControl {
                return false
            }
            current = view.superview
        }
        return true
    }

    func finishThumbnailDrivenPagingIfNeeded() {
        if isPagingDrivenByThumbnailStrip {
            isPagingDrivenByThumbnailStrip = false
        }
    }
}
