//
//  BasePhotoViewController+Undo.swift
//  HSPhotos
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController {

    internal func setupUndoManager() {}

    internal func updateUndoRedoButtons() {
        undoBarButton.isEnabled = canUndo
        redoBarButton.isEnabled = canRedo
    }

    @objc internal func undoAction() {
        guard let action = UndoManagerService.shared.undo() else { return }

        let loadingAlert = UIAlertController(title: "撤销中", message: "正在撤销操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        PhotoChangesService.undo(action) { [weak self] success, _ in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    self.loadPhoto()
                }
                self.updateUndoRedoButtons()
            }
        }
    }

    @objc internal func redoAction() {
        guard let action = UndoManagerService.shared.redo() else { return }

        let loadingAlert = UIAlertController(title: "重做中", message: "正在重做操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        PhotoChangesService.redo(action) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    self.loadPhoto()
                } else {
                    self.showAlert(title: "重做失败", message: error ?? "无法重做操作")
                }
                self.updateUndoRedoButtons()
            }
        }
    }

    internal func addAction(_ action: UndoAction) {
        UndoManagerService.shared.addUndoAction(action)
    }

    internal var canUndo: Bool {
        UndoManagerService.shared.canUndo
    }

    internal var canRedo: Bool {
        UndoManagerService.shared.canRedo
    }
}
