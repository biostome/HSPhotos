//
//  BasePhotoViewController+AlbumWriteback.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController {
        internal func performPaste(assets: [PHAsset], insertIndex: Int, updatedLocalAssets: [PHAsset]) {
            guard !assets.isEmpty else { return }

            let loadingAlert = UIAlertController(title: "粘贴中", message: "正在粘贴照片...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            albumOperations.paste(assets: assets, at: insertIndex) { [weak self] outcome in
                loadingAlert.dismiss(animated: true) {
                    guard let self else { return }
                    if outcome.success {
                        self.assets = updatedLocalAssets
                        self.showAlert(title: "粘贴成功", message: "已成功粘贴 \(assets.count) 张照片")
                    }
                    self.applyAlbumOperationOutcome(outcome, failureTitle: "粘贴失败")
                    self.updateOperationMenu()
                }
            }
        }

        internal func applyCustomSortPreferenceAfterPasteIfNeeded() {
            applyCustomSortAfterWriteback()
        }

        internal func applyCustomSortAfterWriteback() {
            guard sortPreference != .custom else { return }
            sortPreference = .custom
            refreshGridFromSession()
            PhotoSortPreference.custom.set(preference: collection)
            refreshFetchOptionsForCurrentSortPreference()
            refreshSortUIAfterPasteIfNeeded()
        }

        /// 应用写操作结果：自定义排序、撤销、清选、重载与失败提示。
        internal func applyAlbumOperationOutcome(
            _ outcome: PhotoAlbumOperationOutcome,
            failureTitle: String = "操作失败"
        ) {
            if outcome.shouldApplyCustomSort {
                applyCustomSortAfterWriteback()
            }
            if let undoAction = outcome.undoAction {
                addAction(undoAction)
            }
            if outcome.shouldClearSelection {
                gridView.clearSelected()
            }
            if outcome.shouldReloadAssets {
                loadPhoto()
            }
            updateUndoRedoButtons()
            if !outcome.success, let message = outcome.message, !message.isEmpty {
                showAlert(title: failureTitle, message: message)
            }
        }
}
