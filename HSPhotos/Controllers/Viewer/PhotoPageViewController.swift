//
//  PhotoPageViewController.swift
//  HSPhotos
//

import UIKit
import Photos
import AVFoundation

/// 单页大图 / 视频：滚动缩放与播放
final class PhotoPageViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let playerContainerView = UIView()
    private var playerLayer: AVPlayerLayer?
    private(set) var player: AVPlayer?

    private let videoControlsView = VideoPlaybackControlsView()

    private var isControlsVisible = false
    private var isPlaying = false
    private var timeObserver: Any?
    /// 记录离开页面前的播放状态：避免用户滑动切页后回到该页时播放图标/状态错乱。
    private var wasPlayingBeforeDisappear: Bool = false
    /// 当前页是否处于可见/交互状态：用于避免在滑走后异步回调又启动播放。
    private var isPageActive: Bool = false
    private var videoThumbnailHideWorkItem: DispatchWorkItem?

    private let loadingContainer = UIView()
    private let loadingActivityIndicator = UIActivityIndicatorView(style: .large)
    private let loadingStatusLabel = UILabel()
    /// 视频较慢时才显示转圈，本地秒开则取消，避免闪一下
    private var videoLoadingDelayedWorkItem: DispatchWorkItem?

    let asset: PHAsset
    var index: Int = 0
    var scrollViewZoomScale: CGFloat { scrollView.zoomScale }
    private var videoControlsHeightConstraint: NSLayoutConstraint?
    private var isScrubbingProgress = false

    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        // 视频控制条需要“浮层”效果：当我们把进度条/控制条向上挪到缩略条区域时，
        // 若 scrollView 默认裁剪，会导致进度条看不到。
        if asset.mediaType == .video {
            scrollView.clipsToBounds = false
        }
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        playerContainerView.backgroundColor = .clear
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(playerContainerView)

        setupVideoControls()

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
            playerContainerView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        scrollView.addGestureRecognizer(singleTapGesture)

        playerContainerView.isHidden = true
        setupLoadingOverlay()
        loadMedia()
    }

    private func setupLoadingOverlay() {
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.isUserInteractionEnabled = false
        loadingContainer.isHidden = true
        view.addSubview(loadingContainer)

        loadingActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingActivityIndicator.hidesWhenStopped = true
        loadingActivityIndicator.color = .white
        loadingContainer.addSubview(loadingActivityIndicator)

        loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingStatusLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        loadingStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        loadingStatusLabel.textAlignment = .center
        loadingStatusLabel.numberOfLines = 2
        loadingContainer.addSubview(loadingStatusLabel)

        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingActivityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            loadingActivityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingStatusLabel.topAnchor.constraint(equalTo: loadingActivityIndicator.bottomAnchor, constant: 12),
            loadingStatusLabel.leadingAnchor.constraint(equalTo: loadingContainer.leadingAnchor),
            loadingStatusLabel.trailingAnchor.constraint(equalTo: loadingContainer.trailingAnchor),
            loadingStatusLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor)
        ])
    }

    private func showLoadingOverlay(message: String?) {
        loadingStatusLabel.text = message
        loadingContainer.isHidden = false
        loadingActivityIndicator.startAnimating()
    }

    private func hideLoadingOverlay() {
        videoLoadingDelayedWorkItem?.cancel()
        videoLoadingDelayedWorkItem = nil
        loadingActivityIndicator.stopAnimating()
        loadingStatusLabel.text = nil
        loadingContainer.isHidden = true
    }

    private func scheduleVideoLoadingOverlayIfSlow() {
        videoLoadingDelayedWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.showLoadingOverlay(message: "正在载入视频…")
        }
        videoLoadingDelayedWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func setupVideoControls() {
        // 固定屏幕浮层：不随 scrollView zoom 内容缩放移动
        view.addSubview(videoControlsView)

        videoControlsView.onPlayPauseTapped = { [weak self] in
            self?.togglePlayPause()
        }
        videoControlsView.onSliderValueChanged = { [weak self] slider in
            self?.sliderValueChanged(slider)
        }
        videoControlsView.onMuteTapped = { [weak self] in
            self?.toggleMute()
        }
        videoControlsView.onSliderTrackingChanged = { [weak self] isTracking in
            self?.setProgressScrubbingState(isTracking)
        }

        NSLayoutConstraint.activate([
            videoControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            {
                let c = videoControlsView.heightAnchor.constraint(equalToConstant: 60)
                videoControlsHeightConstraint = c
                return c
            }(),
            {
                return videoControlsView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -150)
            }()
        ])

        videoControlsView.setControlsVisible(false, animated: false)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        if scrollView.zoomScale == 1 {
            scrollView.zoom(to: CGRect(x: point.x - 100, y: point.y - 100, width: 200, height: 200), animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        if asset.mediaType == .video {
            toggleControlsVisibility()
        }
    }

    private func toggleControlsVisibility() {
        isControlsVisible.toggle()
        videoControlsView.setControlsVisible(isControlsVisible, animated: true)
    }

    @objc private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            videoControlsView.setPlayPauseIcon(isPlaying: false)
        } else {
            player.play()
            videoControlsView.setPlayPauseIcon(isPlaying: true)
        }
        isPlaying.toggle()
    }

    @objc private func sliderValueChanged(_ slider: UISlider) {
        guard let player = player, let duration = player.currentItem?.duration else { return }
        let seekTime = CMTime(seconds: Double(slider.value) * duration.seconds, preferredTimescale: 600)
        player.seek(to: seekTime) { _ in }
        if isScrubbingProgress {
            let current = Double(slider.value) * duration.seconds
            videoControlsView.setScrubInfo("\(formatDuration(current)) / \(formatDuration(duration.seconds))")
        }
    }

    @objc private func toggleMute() {
        guard let player else { return }
        player.isMuted.toggle()
        videoControlsView.setMuteIcon(isMuted: player.isMuted)
    }

    private func updateProgress() {
        guard let player = player, let currentItem = player.currentItem else { return }
        let duration = currentItem.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        let currentTime = player.currentTime().seconds
        videoControlsView.progressSlider.value = Float(currentTime / duration)
        if isScrubbingProgress {
            videoControlsView.setScrubInfo("\(formatDuration(currentTime)) / \(formatDuration(duration))")
        }
    }

    private func setProgressScrubbingState(_ isTracking: Bool) {
        isScrubbingProgress = isTracking
        videoControlsHeightConstraint?.constant = isTracking ? 84 : 60

        if isTracking, let player, let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            let current = Double(videoControlsView.progressSlider.value) * duration
            videoControlsView.setScrubInfo("\(formatDuration(current)) / \(formatDuration(duration))")
        }
        videoControlsView.setScrubInfoVisible(isTracking, animated: true)

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func loadThumbnail(targetSize: CGSize) {
        let thumbnailOptions = PHImageRequestOptions()
        thumbnailOptions.deliveryMode = .fastFormat
        thumbnailOptions.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: thumbnailOptions) { [weak self] image, _ in
            DispatchQueue.main.async { self?.imageView.image = image }
        }
    }

    private func transitionToHighQualityImage(image: UIImage) {
        if imageView.image != nil {
            let tempImageView = UIImageView(image: image)
            tempImageView.contentMode = .scaleAspectFit
            tempImageView.frame = imageView.frame
            tempImageView.alpha = 0
            imageView.superview?.addSubview(tempImageView)
            UIView.animate(withDuration: 0.3) {
                tempImageView.alpha = 1
            } completion: { _ in
                self.imageView.image = image
                tempImageView.removeFromSuperview()
            }
        } else {
            imageView.image = image
        }
    }

    private func loadMedia() {
        let targetSize = fullScreenPixelSize()
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
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.hideLoadingOverlay()
                    if let image = image {
                        self.transitionToHighQualityImage(image: image)
                    } else {
                        self.showErrorPlaceholder()
                    }
                }
            }
        case .video:
            playerContainerView.isHidden = false
            scheduleVideoLoadingOverlayIfSlow()
            // 封面用较小尺寸，避免全屏像素解码拖慢首帧
            loadThumbnail(targetSize: posterThumbnailPixelSize(reference: targetSize))
            let videoOptions = PHVideoRequestOptions()
            // fastFormat 首帧快但常为低码率变体，全屏观感糊；大图浏览用高质量
            videoOptions.deliveryMode = .highQualityFormat
            videoOptions.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { [weak self] avAsset, _, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.hideLoadingOverlay()
                    if let avAsset = avAsset {
                        let playerItem = AVPlayerItem(asset: avAsset)
                        let player = AVPlayer(playerItem: playerItem)
                        // 更快开始播放，减少「卡住等缓冲」体感（弱网下可能更易卡顿，可接受）
                        player.automaticallyWaitsToMinimizeStalling = false
                        self.player = player
                        let playerLayer = AVPlayerLayer(player: player)
                        playerLayer.videoGravity = .resizeAspect
                        playerLayer.frame = self.playerContainerView.bounds
                        // 作为底层视频图层：插入到最底部，避免被控制条遮挡。
                        self.playerContainerView.layer.insertSublayer(playerLayer, at: 0)
                        self.playerLayer = playerLayer

                        // 如果用户已经滑走，这里不要无条件播放，否则会造成“后台播放/画面错乱”。
                        let shouldShowVideoNow = self.isPageActive
                        if shouldShowVideoNow {
                            self.isPlaying = true
                            self.videoControlsView.setPlayPauseIcon(isPlaying: true)
                            self.videoControlsView.setMuteIcon(isMuted: player.isMuted)
                            player.play()

                            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
                            self.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                                self?.updateProgress()
                            }
                            self.updateProgress()
                            self.hideVideoThumbnailAnimatedIfNeeded()
                        } else {
                            self.isPlaying = false
                            self.videoControlsView.setPlayPauseIcon(isPlaying: false)
                            self.videoControlsView.setMuteIcon(isMuted: player.isMuted)
                            player.pause()

                            // 保持封面可见，避免淡出任务在后台执行导致遮挡/闪烁。
                            self.imageView.isHidden = false
                            self.imageView.alpha = 1
                        }
                    } else {
                        self.showErrorPlaceholder()
                    }
                }
            }
        default:
            showErrorPlaceholder()
        }
    }

    private func showErrorPlaceholder() {
        hideLoadingOverlay()
        imageView.image = UIImage(systemName: "exclamationmark.triangle")
        imageView.tintColor = .systemRed
        imageView.contentMode = .center
        if asset.mediaType == .video {
            playerContainerView.isHidden = true
        }
    }

    private func fullScreenPixelSize() -> CGSize {
        guard let screen = view.window?.windowScene?.screen else {
            return .zero
        }
        let size = screen.bounds.size
        let scale = screen.scale
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// 视频封面图请求尺寸：限制长边，减轻解码与相册回调压力，播放仍用 AVAsset 全质量
    private func posterThumbnailPixelSize(reference: CGSize) -> CGSize {
        guard reference.width > 0, reference.height > 0 else { return reference }
        let maxEdge: CGFloat = 1280
        let edge = max(reference.width, reference.height)
        guard edge > maxEdge else { return reference }
        let s = maxEdge / edge
        return CGSize(width: reference.width * s, height: reference.height * s)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerContainerView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // UIPageViewController 交互式滑动切页时会触发 viewWillDisappear；
        // 若直接移除 playerLayer，切回/继续滑动后就可能出现“画面层消失”。
        wasPlayingBeforeDisappear = isPlaying
        isPageActive = false
        videoThumbnailHideWorkItem?.cancel()
        videoThumbnailHideWorkItem = nil
        player?.pause()
        isPlaying = false
        videoControlsView.setPlayPauseIcon(isPlaying: false)
        videoControlsView.setMuteIcon(isMuted: player?.isMuted ?? false)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard asset.mediaType == .video else { return }
        isPageActive = true

        // 重新挂载进度观察者（离开时已移除），并根据离开前状态决定是否恢复播放。
        if timeObserver == nil, let player {
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                self?.updateProgress()
            }
            updateProgress()
        }

        if wasPlayingBeforeDisappear, let player {
            player.play()
            isPlaying = true
            videoControlsView.setPlayPauseIcon(isPlaying: true)
            videoControlsView.setMuteIcon(isMuted: player.isMuted)
        } else {
            isPlaying = false
            videoControlsView.setPlayPauseIcon(isPlaying: false)
            videoControlsView.setMuteIcon(isMuted: player?.isMuted ?? false)
        }

        // 若视频 layer 已就绪，则把封面图淡出，避免遮挡播放器画面。
        if playerLayer != nil, !imageView.isHidden {
            hideVideoThumbnailAnimatedIfNeeded()
        }
    }

    private func hideVideoThumbnailAnimatedIfNeeded() {
        guard !imageView.isHidden else { return }
        videoThumbnailHideWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isPageActive else { return }
            UIView.animate(withDuration: 0.3) {
                self.imageView.alpha = 0
            } completion: { _ in
                guard self.isPageActive else { return }
                self.imageView.isHidden = true
                self.imageView.alpha = 1
            }
        }
        videoThumbnailHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}

extension PhotoPageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if asset.mediaType == .video && !playerContainerView.isHidden {
            return playerContainerView
        }
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if asset.mediaType == .video, let playerLayer = playerLayer {
            playerLayer.frame = playerContainerView.bounds
        }
    }
}
