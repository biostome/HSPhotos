//
//  PhotoGridRouter.swift
//  HSPhotos
//
//  相簿网格页导航（Coordinator）：集中 present / push，Controller 只负责业务回调。
//

import Photos
import PhotosUI
import UIKit

final class PhotoGridRouter {

    weak var host: UIViewController?

    // MARK: - Picker

    func presentPhotoLibraryPicker(
        delegate: PHPickerViewControllerDelegate,
        selectionLimit: Int = 0
    ) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        configuration.selection = .ordered
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = delegate
        host?.present(picker, animated: true)
    }

    func presentAddToAlbumPicker(onAlbumPicked: @escaping (PHAssetCollection) -> Void) {
        let pickerVC = AlbumListViewController(isPickerMode: true, onAlbumPicked: onAlbumPicked)
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.modalPresentationStyle = .formSheet
        host?.present(nav, animated: true)
    }

    // MARK: - 标签

    func presentTagAssign(assetIdentifiers: [String]) {
        let vc = TagAssignViewController(assetIdentifiers: assetIdentifiers)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        host?.present(vc, animated: true)
    }

    func presentTagFilterPanel(_ panel: TagFilterPanelViewController) {
        if let sheet = panel.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        host?.present(panel, animated: true)
    }

    // MARK: - Push

    func pushOverlaySettings() {
        host?.navigationController?.pushViewController(OverlaySettingsViewController(), animated: true)
    }

    func presentShareSheet(
        activityItems: [Any],
        applicationActivities: [UIActivity]?,
        sourceView: UIView,
        sourceRect: CGRect
    ) {
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceRect
        }
        host?.present(activityVC, animated: true)
    }

    // MARK: - 浏览

    func presentGalleryViewer(
        assets: [PHAsset],
        initialIndex: Int,
        sourceFrame: CGRect,
        sourceImage: UIImage?
    ) {
        let nav = GalleryViewerViewController.makePresentingNavigationContainer(
            assets: assets,
            initialIndex: initialIndex,
            sourceFrame: sourceFrame,
            sourceImage: sourceImage
        )
        host?.present(nav, animated: true)
    }

    // MARK: - 相册选择（移动）

    func presentAlbumPickerActionSheet(
        albums: [PHAssetCollection],
        onSelect: @escaping (PHAssetCollection) -> Void
    ) {
        guard let host else { return }
        let alert = UIAlertController(title: "选择目标相册", message: nil, preferredStyle: .actionSheet)
        for collection in albums {
            let title = collection.localizedTitle ?? "未命名相册"
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                onSelect(collection)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(
                x: host.view.bounds.midX,
                y: host.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        host.present(alert, animated: true)
    }

    // MARK: - 通用 UI

    func present(_ viewController: UIViewController, animated: Bool = true) {
        host?.present(viewController, animated: animated)
    }

    func makeLoadingAlert(title: String, message: String) -> UIAlertController {
        UIAlertController(title: title, message: message, preferredStyle: .alert)
    }

    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        host?.present(alert, animated: true)
    }

    func presentDeleteConfirmation(
        assetCount: Int,
        onConfirm: @escaping () -> Void
    ) {
        let message = assetCount == 1
            ? "确定要从相册中删除这张照片吗？"
            : "确定要从相册中删除这\(assetCount)张照片吗？"
        let alert = UIAlertController(title: "删除照片", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in onConfirm() })
        host?.present(alert, animated: true)
    }
}
