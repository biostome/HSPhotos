//
//  BasePhotoViewController+Menu.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController {

    internal func gridMenuState() -> AlbumGridMenuState {
        var hierarchy: AlbumGridHierarchyMenuContext?
        let selected = orderedSelectedAssets()
        if supportsHierarchyNumbering, let firstAsset = selected.first {
            let prevLv = session.levelBeforeInMembers(firstAsset)
            let firstLv = session.level(for: firstAsset)
            hierarchy = AlbumGridHierarchyMenuContext(
                prevLevel: prevLv,
                firstLevel: firstLv,
                anyInHierarchy: selected.contains { session.level(for: $0) > 0 },
                anyCanPromote: selected.contains { session.level(for: $0) > 1 },
                canDemote: firstLv < prevLv + 1
            )
        }
        return AlbumGridMenuState(
            sortPreference: sortPreference,
            hasSelection: gridView.hasSelectedAssets,
            canUndo: canUndo,
            canRedo: canRedo,
            supportsHierarchyNumbering: supportsHierarchyNumbering,
            hierarchy: hierarchy
        )
    }

    internal func gridMenuActions() -> AlbumGridMenuActions {
        AlbumGridMenuActions(
            onSort: { [weak self] preference in self?.onChanged(sort: preference) },
            onUndo: { [weak self] in self?.undoAction() },
            onRedo: { [weak self] in self?.redoAction() },
            onAddToAlbum: { [weak self] in self?.onAddToAlbumSelectedAssets() },
            onTag: { [weak self] in self?.onTagSelectedAssets() },
            onDelete: { [weak self] in self?.onDelete() },
            onMove: { [weak self] in self?.onMove() },
            onPaste: { [weak self] in self?.onPaste() },
            onCopy: { [weak self] in self?.onCopy() },
            onDuplicate: { [weak self] in self?.onDuplicate() },
            onReorder: { [weak self] in self?.onOrder() },
            onBatchSetMainLevel: { [weak self] in self?.onBatchSetLevel(to: 1) },
            onBatchPromote: { [weak self] in self?.onBatchPromoteLevel() },
            onBatchDemote: { [weak self] in self?.onBatchDemoteLevel() },
            onBatchSetSameLevel: { [weak self] in
                guard let self, let first = self.orderedSelectedAssets().first else { return }
                self.onBatchSetLevel(to: self.session.levelBeforeInMembers(first))
            },
            onBatchSetSubLevel: { [weak self] in
                guard let self, let first = self.orderedSelectedAssets().first else { return }
                let prev = self.session.levelBeforeInMembers(first)
                self.onBatchSetLevel(to: prev + 1)
            },
            onBatchClearLevel: { [weak self] in self?.onBatchClearLevel() }
        )
    }

    internal func onAddPhotos() {
        gridRouter.presentPhotoLibraryPicker(delegate: self)
    }

    internal func onAddToAlbumSelectedAssets() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "添加失败", message: "请先选择要添加的照片")
            return
        }
        showAddToAlbumPicker(for: selectedAssets)
    }

    internal func onTagSelectedAssets() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else { return }
        showTagAssignPicker(for: selectedAssets.map { $0.localIdentifier })
    }

    internal func showTagAssignPicker(for assetIdentifiers: [String]) {
        gridRouter.presentTagAssign(assetIdentifiers: assetIdentifiers)
    }

    private func onBatchSetLevel(to level: Int) {
        session.applyBatchSetLevel(level, to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchPromoteLevel() {
        session.applyBatchPromote(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchDemoteLevel() {
        session.applyBatchDemote(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchClearLevel() {
        session.applyBatchClear(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func orderedSelectedAssets() -> [PHAsset] {
        let selectedIDs = gridView.selectedMembershipIdentifiers
        guard !selectedIDs.isEmpty else { return [] }
        return assets.filter { selectedIDs.contains($0.localIdentifier) }
    }

    internal func syncSuccess(message: String) {
        showAlert(title: "同步成功", message: message)
    }

    internal func syncFailed(message: String) {
        showAlert(title: "同步失败", message: message)
    }

    internal func showAlert(title: String, message: String) {
        gridRouter.presentAlert(title: title, message: message)
    }
}
