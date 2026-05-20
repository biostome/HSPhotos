//
//  BasePhotoViewController+Operations.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController {
        internal func refreshFetchOptionsForCurrentSortPreference() {
            let options = PHFetchOptions()
            options.sortDescriptors = sortDescriptors(for: sortPreference)
            fetchOptions = options
        }

        internal func loadPhoto() {
            // 在后台线程执行耗时操作，避免阻塞主线程造成卡顿
            let collection = self.collection
            let options = self.fetchOptions

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                let assets = PHAsset.fetchAssets(in: collection, options: options)
                var newAssets: [PHAsset] = []
                assets.enumerateObjects { asset, _, _ in
                    newAssets.append(asset)
                }

                let validAssetIDs = Set(newAssets.map { $0.localIdentifier })
                viewModel.cleanupNumbering(validAssetIDs: validAssetIDs)

                DispatchQueue.main.async {
                    self.assets = newAssets
                }
            }
        }

        internal func onOrder() {
            do {
                let originalAssets = assets
                let sortedAssets = try gridView.sort()
                assets = sortedAssets

                let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
                present(loadingAlert, animated: true)

                albumOperations.syncCustomOrder(sortedAssets: sortedAssets, originalAssets: originalAssets) { [weak self] outcome in
                    guard let self else { return }
                    loadingAlert.dismiss(animated: true) {
                        self.applyAlbumOperationOutcome(outcome)
                        if outcome.shouldApplyCustomSort {
                            self.updateOperationMenu()
                        }
                    }
                }
            } catch {
                gridView.clearSelected()
                showAlert(title: "排序失败", message: error.localizedDescription)
            }
        }

        internal func onCopy() {
            AssetPasteboard.copyAssets(gridView.selectedAssets) { [weak self] success, message in
                guard let self = self else { return }
                if !success {
                    let alertMessage = message ?? "无法复制到剪切板"
                    self.showAlert(title: "复制失败", message: alertMessage)
                }
            }
        }

        internal func onDuplicate() {
            let selectedAssets = gridView.selectedAssets
            guard !selectedAssets.isEmpty else {
                showAlert(title: "复制失败", message: "请先选择要复制的照片")
                return
            }

            let loadingAlert = UIAlertController(title: "复制中", message: "正在创建照片副本...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            albumOperations.duplicate(assets: selectedAssets) { [weak self] outcome in
                loadingAlert.dismiss(animated: true) {
                    self?.applyAlbumOperationOutcome(outcome, failureTitle: "复制失败")
                }
            }
        }

        internal func onPaste() {
            guard let assets = AssetPasteboard.assetsFromPasteboard() else {
                showAlert(title: "粘贴失败", message: "剪切板里没有资源")
                return
            }
            albumOperations.add(assets: assets, to: collection) { [weak self] outcome in
                guard let self else { return }
                if outcome.shouldReloadAssets {
                    self.loadPhoto()
                    self.updateUndoRedoButtons()
                }
            }
        }

        internal func onDelete() {
            let selectedAssets = gridView.selectedAssets
            guard !selectedAssets.isEmpty else {
                showAlert(title: "删除失败", message: "请先选择要删除的照片")
                return
            }

            showDeleteConfirmationAlert(for: selectedAssets)
        }

        internal func onMove() {
            let selectedAssets = gridView.selectedAssets
            guard !selectedAssets.isEmpty else {
                showAlert(title: "移动失败", message: "请先选择要移动的照片")
                return
            }

            // 显示相册选择器
            showAlbumPicker(for: selectedAssets)
        }

        internal func showAddToAlbumPicker(for assets: [PHAsset]) {
            guard !assets.isEmpty else {
                showAlert(title: "添加失败", message: "请先选择要添加的照片")
                return
            }

            gridRouter.presentAddToAlbumPicker { [weak self] destinationAlbum in
                self?.performAdd(assets: assets, to: destinationAlbum)
            }
        }

        internal func performAdd(assets: [PHAsset], to destinationCollection: PHAssetCollection) {
            let loadingAlert = UIAlertController(title: "添加中", message: "正在添加到相簿...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            let operations = PhotoAlbumOperations(collection: destinationCollection)
            operations.add(assets: assets, to: destinationCollection) { [weak self] outcome in
                loadingAlert.dismiss(animated: true) {
                    guard let self else { return }
                    if outcome.message == "所选照片已在目标相簿中" {
                        self.showAlert(title: "提示", message: outcome.message ?? "")
                        return
                    }
                    self.applyAlbumOperationOutcome(outcome, failureTitle: "添加失败")
                }
            }
        }

        internal func showAlbumPicker(for assets: [PHAsset]) {
            // 获取所有用户创建的相册
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
            var albumList: [PHAssetCollection] = []

            collections.enumerateObjects { collection, _, _ in
                // 排除当前相册
                if collection.localIdentifier != self.collection.localIdentifier {
                    albumList.append(collection)
                }
            }

            guard !albumList.isEmpty else {
                showAlert(title: "移动失败", message: "没有找到其他相册")
                return
            }

            gridRouter.presentAlbumPickerActionSheet(albums: albumList) { [weak self] collection in
                self?.performMove(assets: assets, to: collection)
            }
        }

        internal func performMove(assets: [PHAsset], to destinationCollection: PHAssetCollection) {
            let loadingAlert = UIAlertController(title: "移动中", message: "正在将照片移动到其他相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            albumOperations.move(assets: assets, to: destinationCollection) { [weak self] outcome in
                loadingAlert.dismiss(animated: true) {
                    self?.applyAlbumOperationOutcome(outcome, failureTitle: "移动失败")
                }
            }
        }

        internal func showDeleteConfirmationAlert(for assets: [PHAsset]) {
            gridRouter.presentDeleteConfirmation(assetCount: assets.count) { [weak self] in
                self?.performDelete(assets: assets)
            }
        }

        internal func performDelete(assets: [PHAsset]) {
            let loadingAlert = UIAlertController(title: "删除中", message: "正在从相册中删除照片...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            albumOperations.delete(assets: assets) { [weak self] outcome in
                loadingAlert.dismiss(animated: true) {
                    self?.applyAlbumOperationOutcome(outcome, failureTitle: "删除失败")
                }
            }
        }

}
