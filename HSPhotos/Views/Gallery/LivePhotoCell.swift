import UIKit
import Photos
import PhotosUI

final class LivePhotoCell: PhotoCellBase, GalleryViewerMediaCell {
    static let livePhotoReuseIdentifier = "LivePhotoCell"
    static var reuseIdentifier: String { livePhotoReuseIdentifier }

    static func supports(_ asset: PHAsset) -> Bool {
        asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
    }

    private var livePhotoView: PHLivePhotoView?
    private var hasRequestedLivePhoto = false
    private var isLongPressPlaybackRequested = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLongPressGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.25
        longPress.allowableMovement = 16
        scrollView.addGestureRecognizer(longPress)
    }

    @discardableResult
    private func makeLivePhotoView() -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        view.isMuted = true
        view.isHidden = true
        playerContainerView.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            view.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
            view.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor)
        ])
        livePhotoView = view
        return view
    }

    override func configure(with asset: PHAsset, at index: Int) {
        super.configure(with: asset, at: index)
        loadMedia()
    }

    override func loadMedia() {
        guard let asset = asset, Self.supports(asset) else { return }

        playerContainerView.isHidden = true
        loadThumbnail(targetSize: posterThumbnailPixelSize(reference: fullScreenPixelSize()))
        if isPageActive {
            requestLivePhotoIfNeeded()
        }
    }

    private func requestLivePhotoIfNeeded() {
        guard !hasRequestedLivePhoto else { return }
        guard let asset = asset, Self.supports(asset), isPageActive else { return }
        let token = assetRequestToken
        let assetIdentifier = asset.localIdentifier
        hasRequestedLivePhoto = true
        teardownLivePhoto()
        playerContainerView.isHidden = false
        let livePhotoView = makeLivePhotoView()
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        mediaRequestID = PHImageManager.default().requestLivePhoto(for: asset, targetSize: fullScreenPixelSize(), contentMode: .aspectFit, options: options) { [weak self] livePhoto, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.assetRequestToken == token, self.asset?.localIdentifier == assetIdentifier else { return }
                guard self.livePhotoView === livePhotoView else { return }
                if let livePhoto {
                    livePhotoView.livePhoto = livePhoto
                    livePhotoView.isHidden = false
                    self.imageView.isHidden = true
                    if self.isLongPressPlaybackRequested {
                        livePhotoView.startPlayback(with: .full)
                    } else if self.isPageActive {
                        livePhotoView.startPlayback(with: .hint)
                    }
                } else {
                    self.showErrorPlaceholder()
                }
            }
        }
    }

    override var isPageActive: Bool {
        didSet {
            guard asset.map(Self.supports) == true else { return }
            if isPageActive {
                requestLivePhotoIfNeeded()
                if let livePhotoView, livePhotoView.livePhoto != nil, !isLongPressPlaybackRequested {
                    livePhotoView.startPlayback(with: .hint)
                }
            } else {
                teardownLivePhoto()
            }
        }
    }

    override func resetForNewAssetConfiguration() {
        teardownLivePhoto()
        super.resetForNewAssetConfiguration()
    }

    override func prepareForReuse() {
        teardownLivePhoto()
        super.prepareForReuse()
    }

    @objc
    private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard asset.map(Self.supports) == true, isPageActive else { return }
        switch gesture.state {
        case .began:
            isLongPressPlaybackRequested = true
            requestLivePhotoIfNeeded()
            if let livePhotoView, livePhotoView.livePhoto != nil {
                livePhotoView.startPlayback(with: .full)
            }
        case .ended, .cancelled, .failed:
            isLongPressPlaybackRequested = false
            livePhotoView?.stopPlayback()
            if let livePhotoView, livePhotoView.livePhoto != nil, isPageActive {
                livePhotoView.startPlayback(with: .hint)
            }
        default:
            break
        }
    }

    private func teardownLivePhoto() {
        isLongPressPlaybackRequested = false
        livePhotoView?.stopPlayback()
        livePhotoView?.livePhoto = nil
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        hasRequestedLivePhoto = false
        playerContainerView.isHidden = true
        imageView.isHidden = false
    }
}
