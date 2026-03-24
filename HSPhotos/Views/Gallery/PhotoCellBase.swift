import UIKit
import Photos
import AVFoundation

protocol GalleryViewerMediaCell where Self: PhotoCellBase {
    static var reuseIdentifier: String { get }
    static func supports(_ asset: PHAsset) -> Bool
}

extension GalleryViewerMediaCell {
    static func register(on collectionView: UICollectionView) {
        collectionView.register(Self.self, forCellWithReuseIdentifier: reuseIdentifier)
    }

    static func dequeue(from collectionView: UICollectionView, for indexPath: IndexPath) -> PhotoCellBase {
        collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCellBase
    }
}

class PhotoCellBase: UICollectionViewCell {
    var onSingleTap: (() -> Void)?
    var dismissTransformView: UIView { scrollView }
    var preferredPlaceholderImage: UIImage?

    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 4
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let playerContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let loadingContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        v.isHidden = true
        return v
    }()

    private let loadingActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()

    private let loadingStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.95)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    var asset: PHAsset?
    var index: Int = 0
    var scrollViewZoomScale: CGFloat { scrollView.zoomScale }
    private(set) var assetRequestToken = UUID()

    var isPlaybackControlsInteracting: Bool { false }

    var isScrubbingProgress: Bool { _isScrubbingProgress }
    var _isScrubbingProgress: Bool = false

    func configure(with asset: PHAsset, at index: Int) {
        resetForNewAssetConfiguration()
        self.asset = asset
        self.index = index
        assetRequestToken = UUID()
    }

    func loadMedia() {
    }

    func setInlineControlsVisible(_ visible: Bool, animated: Bool) {
    }

    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?

    var playerItemDurationObservation: NSKeyValueObservation?
    var playerItemStatusObservation: NSKeyValueObservation?
    var videoDidPlayToEndObserver: NSObjectProtocol?
    var videoThumbnailHideWorkItem: DispatchWorkItem?

    var videoLoadingDelayedWorkItem: DispatchWorkItem?
    var thumbnailRequestID: PHImageRequestID = PHInvalidImageRequestID
    var mediaRequestID: PHImageRequestID = PHInvalidImageRequestID
    var lastSyncedProgressValue: Float = -1

    var isPlaying: Bool = false

    var isPageActive: Bool = false {
        didSet {
            if !isPageActive {
                pauseVideo()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBaseViews()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancelPendingRequests()
        cleanupPlayer()
        videoThumbnailHideWorkItem?.cancel()
        videoLoadingDelayedWorkItem?.cancel()
    }

    func setupBaseViews() {
        contentView.backgroundColor = .clear
        scrollView.delegate = self
        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(playerContainerView)

        contentView.addSubview(loadingContainer)
        loadingContainer.addSubview(loadingActivityIndicator)
        loadingContainer.addSubview(loadingStatusLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            playerContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            playerContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            playerContainerView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            loadingContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            loadingActivityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            loadingActivityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingStatusLabel.topAnchor.constraint(equalTo: loadingActivityIndicator.bottomAnchor, constant: 12),
            loadingStatusLabel.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            loadingStatusLabel.trailingAnchor.constraint(equalTo: loadingContainer.trailingAnchor),
            loadingStatusLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor)
        ])
    }

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        if scrollView.zoomScale == 1 {
            scrollView.zoom(to: CGRect(x: point.x - 100, y: point.y - 100, width: 200, height: 200), animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }

    @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        onSingleTap?()
    }

    func showLoadingOverlay(message: String?) {
        loadingStatusLabel.text = message
        loadingContainer.isHidden = false
        loadingActivityIndicator.startAnimating()
    }

    func hideLoadingOverlay() {
        videoLoadingDelayedWorkItem?.cancel()
        videoLoadingDelayedWorkItem = nil
        loadingActivityIndicator.stopAnimating()
        loadingStatusLabel.text = nil
        loadingContainer.isHidden = true
    }

    func scheduleVideoLoadingOverlayIfSlow() {
        videoLoadingDelayedWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.showLoadingOverlay(message: "正在载入视频…")
        }
        videoLoadingDelayedWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    func fullScreenPixelSize() -> CGSize {
        guard let window = imageView.window ?? window else {
            return .zero
        }
        let size = window.bounds.size
        let scale = window.screen.scale
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func posterThumbnailPixelSize(reference: CGSize) -> CGSize {
        guard reference.width > 0, reference.height > 0 else { return reference }
        let maxEdge: CGFloat = 1280
        let edge = max(reference.width, reference.height)
        guard edge > maxEdge else { return reference }
        let s = maxEdge / edge
        return CGSize(width: reference.width * s, height: reference.height * s)
    }

    func loadThumbnail(targetSize: CGSize) {
        guard let asset = asset else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        let token = assetRequestToken
        let assetIdentifier = asset.localIdentifier
        thumbnailRequestID = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.assetRequestToken == token, self.asset?.localIdentifier == assetIdentifier else { return }
                guard let image else { return }
                if self.imageView.image == nil {
                    self.imageView.alpha = 0
                    self.imageView.image = image
                    UIView.animate(withDuration: 0.12) {
                        self.imageView.alpha = 1
                    }
                } else {
                    self.imageView.image = image
                }
            }
        }
    }

    func transitionToHighQualityImage(image: UIImage) {
        if imageView.image != nil {
            let tempImageView = UIImageView(image: image)
            tempImageView.contentMode = .scaleAspectFit
            tempImageView.frame = imageView.frame
            tempImageView.alpha = 0
            imageView.superview?.addSubview(tempImageView)
            UIView.animate(withDuration: 0.18) {
                tempImageView.alpha = 1
            } completion: { _ in
                self.imageView.image = image
                tempImageView.removeFromSuperview()
            }
        } else {
            imageView.image = image
        }
    }

    func showErrorPlaceholder() {
        hideLoadingOverlay()
        imageView.image = UIImage(systemName: "exclamationmark.triangle")
        imageView.tintColor = .systemRed
        imageView.contentMode = .center
    }

    func setupPlayerLayer() {
        guard let player = player else { return }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = playerContainerView.bounds
        playerContainerView.layer.insertSublayer(layer, at: 0)
        playerLayer = layer
    }

    func updatePlayerLayerFrame() {
        playerLayer?.frame = playerContainerView.bounds
    }

    func pauseVideo() {
        player?.pause()
    }

    func resetForNewAssetConfiguration() {
        assetRequestToken = UUID()
        cancelPendingRequests()
        cleanupPlayer()
        videoThumbnailHideWorkItem?.cancel()
        videoThumbnailHideWorkItem = nil
        hideLoadingOverlay()
        imageView.image = preferredPlaceholderImage
        imageView.isHidden = false
        imageView.alpha = 1
        imageView.contentMode = .scaleAspectFit
        playerContainerView.isHidden = true
        scrollView.zoomScale = 1
        isPlaying = false
        lastSyncedProgressValue = -1
    }

    func cancelPendingRequests() {
        if thumbnailRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(thumbnailRequestID)
            thumbnailRequestID = PHInvalidImageRequestID
        }
        if mediaRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(mediaRequestID)
            mediaRequestID = PHInvalidImageRequestID
        }
    }

    func cleanupPlayer() {
        progressDisplayLink?.invalidate()
        progressDisplayLink = nil
        playerItemDurationObservation?.invalidate()
        playerItemStatusObservation?.invalidate()
        if let videoDidPlayToEndObserver {
            NotificationCenter.default.removeObserver(videoDidPlayToEndObserver)
        }
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        playerItemDurationObservation = nil
        playerItemStatusObservation = nil
        videoDidPlayToEndObserver = nil
    }

    var progressDisplayLink: CADisplayLink?

    func syncProgressDisplayLink() {
        let shouldRun = isPageActive && isPlaying && player != nil
        if shouldRun {
            if progressDisplayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(progressDisplayLinkTick))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                progressDisplayLink = link
            }
        } else {
            progressDisplayLink?.invalidate()
            progressDisplayLink = nil
        }
    }

    @objc func progressDisplayLinkTick() {
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        assetRequestToken = UUID()
        cancelPendingRequests()
        cleanupPlayer()
        onSingleTap = nil
        preferredPlaceholderImage = nil
        asset = nil
        index = 0
        imageView.image = nil
        imageView.contentMode = .scaleAspectFit
        playerContainerView.isHidden = true
        playerContainerView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        hideLoadingOverlay()
        scrollView.zoomScale = 1
        isPageActive = false
        isPlaying = false
        lastSyncedProgressValue = -1
        videoThumbnailHideWorkItem?.cancel()
        videoThumbnailHideWorkItem = nil
        _isScrubbingProgress = false
    }
}

extension PhotoCellBase: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if !playerContainerView.isHidden {
            return playerContainerView
        }
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if !playerContainerView.isHidden {
            updatePlayerLayerFrame()
        }
    }
}
