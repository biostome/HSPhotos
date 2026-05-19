//
//  BasePhotoViewController extensions
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            self?.addPickedPhotosToCurrentAlbum(results)
        }
    }

    private func addPickedPhotosToCurrentAlbum(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }

        let loadingAlert = UIAlertController(title: "添加中", message: "正在将照片添加到相簿...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        var finished = false
        let finish: (PhotoAlbumOperationOutcome) -> Void = { [weak self] outcome in
            guard let self, !finished else { return }
            finished = true
            loadingAlert.dismiss(animated: true) {
                if outcome.message == "请允许照片读写权限后重试" {
                    self.showAlert(title: "权限不足", message: outcome.message ?? "")
                    return
                }
                if outcome.message == "所选照片已在该相簿中" {
                    self.showAlert(title: "提示", message: outcome.message ?? "")
                    return
                }
                if outcome.success {
                    self.loadPhoto()
                } else if let message = outcome.message {
                    self.showAlert(title: "添加失败", message: message)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, !finished else { return }
            finish(PhotoAlbumOperationOutcome(success: false, message: "操作超时，请稍后重试"))
        }

        albumOperations.addPickerResults(results, completion: finish)
    }
}
