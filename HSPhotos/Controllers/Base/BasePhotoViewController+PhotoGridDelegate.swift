//
//  BasePhotoViewController extensions
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: PhotoGridViewDelegate {
    @objc(photoGridView:didSelectItemAtIndexPath:) internal func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }

    @objc(photoGridView:didSelectItemAtAsset:) internal func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {
        // 打开图片浏览器
        if selectionMode == .none {
            if let index = self.assets.firstIndex(of: asset) {
                // 获取选中图片的帧和图片
                var sourceFrame: CGRect = .zero
                var sourceImage: UIImage? = nil

                // 尝试获取选中的cell的frame
                if let cellFrame = photoGridView.getCellFrame(for: asset) {
                    sourceFrame = view.convert(cellFrame, from: photoGridView)
                }

                // 尝试获取缩略图
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true

                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { (image, _) in
                    sourceImage = image
                }

                self.gridRouter.presentGalleryViewer(
                    assets: self.assets,
                    initialIndex: index,
                    sourceFrame: sourceFrame,
                    sourceImage: sourceImage
                )
            }
        }
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateOperationMenu()
            self.updateUndoRedoButtons()
            if self.selectionMode == .none {
                self.syncSelectionQuickNavBarButtonsEnabled()
            } else {
                self.updateSelectAllButton()
                self.gridView.syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
            }
        }
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {
        updateOperationMenu()
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset) {
        showTagAssignPicker(for: [asset.localIdentifier])
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didRequestDelete asset: PHAsset) {
        showDeleteConfirmationAlert(for: [asset])
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        guard let index = assets.firstIndex(of: after) else {
            showAlert(title: "粘贴失败", message: "无法找到目标照片")
            return
        }
        let insertIndex = index + 1
        var newAssets = assets
        newAssets.insert(contentsOf: assets, at: insertIndex)
        performPaste(assets: assets, insertIndex: insertIndex, updatedLocalAssets: newAssets)
    }
}

// MARK: - SearchBarViewDelegate
