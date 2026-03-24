import UIKit
import Photos

final class ImageCell: PhotoCellBase, GalleryViewerMediaCell {
    static let imageReuseIdentifier = "ImageCell"
    static var reuseIdentifier: String { imageReuseIdentifier }

    static func supports(_ asset: PHAsset) -> Bool {
        asset.mediaType == .image
    }

    override func configure(with asset: PHAsset, at index: Int) {
        super.configure(with: asset, at: index)
        loadMedia()
    }

    override func loadMedia() {
        guard let asset = asset else { return }

        let targetSize = fullScreenPixelSize()
        let token = assetRequestToken
        let assetIdentifier = asset.localIdentifier

        switch asset.mediaType {
        case .image:
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.progressHandler = { [weak self] progress, _, _, _ in
                guard progress < 1 else { return }
                DispatchQueue.main.async {
                    self?.showLoadingOverlay(message: "正在从 iCloud 获取照片…")
                }
            }
            loadThumbnail(targetSize: CGSize(width: 200, height: 200))
            mediaRequestID = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.assetRequestToken == token, self.asset?.localIdentifier == assetIdentifier else { return }
                    self.hideLoadingOverlay()
                    if let image = image {
                        self.transitionToHighQualityImage(image: image)
                    } else {
                        self.showErrorPlaceholder()
                    }
                }
            }
        default:
            showErrorPlaceholder()
        }
    }
}
