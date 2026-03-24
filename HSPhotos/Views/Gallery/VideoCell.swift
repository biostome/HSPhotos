import UIKit
import Photos
import AVFoundation

final class VideoCell: PhotoCellBase, GalleryViewerMediaCell {
    static let videoReuseIdentifier = "VideoCell"
    static var reuseIdentifier: String { videoReuseIdentifier }

    static func supports(_ asset: PHAsset) -> Bool {
        asset.mediaType == .video
    }

    private let videoControlsView = VideoPlaybackControlsView()

    private var isControlsVisible = false
    private var videoControlsHeightConstraint: NSLayoutConstraint?
    private var wasPlayingBeforeDisappear: Bool = false

    override var isPlaybackControlsInteracting: Bool { isScrubbingProgress }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupVideoControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVideoControls() {
        contentView.addSubview(videoControlsView)

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
            videoControlsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoControlsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            {
                let c = videoControlsView.heightAnchor.constraint(equalToConstant: 52)
                videoControlsHeightConstraint = c
                return c
            }(),
            {
                return videoControlsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -154)
            }()
        ])

        videoControlsView.setControlsVisible(false, animated: false)
    }

    override func configure(with asset: PHAsset, at index: Int) {
        super.configure(with: asset, at: index)
        if asset.mediaType == .video {
            scrollView.clipsToBounds = false
        }
        loadMedia()
    }

    override func loadMedia() {
        guard let asset = asset, asset.mediaType == .video else { return }
        let token = assetRequestToken
        let assetIdentifier = asset.localIdentifier

        playerContainerView.isHidden = false
        scheduleVideoLoadingOverlayIfSlow()
        loadThumbnail(targetSize: posterThumbnailPixelSize(reference: fullScreenPixelSize()))

        let videoOptions = PHVideoRequestOptions()
        videoOptions.deliveryMode = .highQualityFormat
        videoOptions.isNetworkAccessAllowed = true

        mediaRequestID = PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { [weak self] avAsset, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.assetRequestToken == token, self.asset?.localIdentifier == assetIdentifier else { return }
                self.hideLoadingOverlay()
                if let avAsset = avAsset {
                    let playerItem = AVPlayerItem(asset: avAsset)
                    let player = AVPlayer(playerItem: playerItem)
                    self.observePlayerItemForProgressUpdates(playerItem)
                    self.setupVideoLooping(for: playerItem)
                    player.actionAtItemEnd = .none
                    player.automaticallyWaitsToMinimizeStalling = false
                    self.player = player
                    self.setupPlayerLayer()

                    let shouldPlayNow = self.isPageActive
                    if shouldPlayNow {
                        self.isPlaying = true
                        self.renderPlaybackControls()
                        player.play()
                        self.updateProgress()
                        self.syncProgressDisplayLink()
                        self.hideVideoThumbnailAnimatedIfNeeded()
                    } else {
                        self.isPlaying = false
                        self.renderPlaybackControls()
                        player.pause()
                        self.imageView.isHidden = false
                        self.imageView.alpha = 1
                    }
                } else {
                    self.showErrorPlaceholder()
                }
            }
        }
    }

    override func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        guard asset?.mediaType == .video else { return }
        super.handleSingleTap(gesture)
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
            updateProgress()
        }
        isPlaying.toggle()
        renderPlaybackControls()
        syncProgressDisplayLink()
    }

    private func toggleMute() {
        guard let player else { return }
        player.isMuted.toggle()
        renderPlaybackControls()
    }

    private func sliderValueChanged(_ slider: UISlider) {
        guard let player = player, let duration = player.currentItem?.duration else { return }
        let seekTime = CMTime(seconds: Double(slider.value) * duration.seconds, preferredTimescale: 600)
        player.seek(to: seekTime) { _ in }
        if isScrubbingProgress {
            let current = Double(slider.value) * duration.seconds
            videoControlsView.setScrubInfo("\(formatDuration(current)) / \(formatDuration(duration.seconds))")
        }
    }

    private func setProgressScrubbingState(_ isTracking: Bool) {
        _isScrubbingProgress = isTracking
        if !isTracking {
            lastSyncedProgressValue = -1
        }
        renderPlaybackControls(animatedScrubInfo: true)
        UIView.animate(withDuration: 0.2) {
            self.contentView.layoutIfNeeded()
        }
    }

    private func observePlayerItemForProgressUpdates(_ playerItem: AVPlayerItem) {
        playerItemDurationObservation?.invalidate()
        playerItemStatusObservation?.invalidate()
        playerItemDurationObservation = playerItem.observe(\.duration, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateProgress() }
        }
        playerItemStatusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self?.updateProgress()
                }
            }
        }
    }

    private func setupVideoLooping(for playerItem: AVPlayerItem) {
        if let videoDidPlayToEndObserver {
            NotificationCenter.default.removeObserver(videoDidPlayToEndObserver)
        }
        videoDidPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleVideoDidPlayToEnd()
        }
    }

    private func handleVideoDidPlayToEnd() {
        guard isPageActive, isPlaying, let player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self, finished, self.isPageActive, self.isPlaying else { return }
            player.play()
            self.lastSyncedProgressValue = -1
            self.updateProgress()
            self.syncProgressDisplayLink()
        }
    }

    override func progressDisplayLinkTick() {
        updateProgress()
    }

    private func updateProgress() {
        guard let player = player, let currentItem = player.currentItem else { return }
        let durationTime = currentItem.duration
        guard durationTime.isValid, !durationTime.isIndefinite else { return }
        let duration = CMTimeGetSeconds(durationTime)
        guard duration.isFinite, duration > 0 else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        guard currentTime.isFinite else { return }
        let ratio = min(max(currentTime / duration, 0), 1)
        if !isScrubbingProgress {
            let v = Float(ratio)
            if abs(v - lastSyncedProgressValue) >= 0.001 {
                videoControlsView.progressSlider.value = v
                lastSyncedProgressValue = v
            }
        }
        if isScrubbingProgress, let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            let current = Double(videoControlsView.progressSlider.value) * duration
            videoControlsView.setScrubInfo("\(formatDuration(current)) / \(formatDuration(duration))")
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

    private func renderPlaybackControls(animatedVisibility: Bool = false, animatedScrubInfo: Bool = false) {
        guard asset?.mediaType == .video else { return }
        videoControlsView.setControlsVisible(isControlsVisible, animated: animatedVisibility)
        videoControlsView.setPlayPauseIcon(isPlaying: isPlaying)
        videoControlsView.setMuteIcon(isMuted: player?.isMuted ?? false)
        videoControlsHeightConstraint?.constant = isScrubbingProgress ? 76 : 52
        if isScrubbingProgress, let player, let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            let current = Double(videoControlsView.progressSlider.value) * duration
            videoControlsView.setScrubInfo("\(formatDuration(current)) / \(formatDuration(duration))")
        }
        videoControlsView.setScrubInfoVisible(isScrubbingProgress, animated: animatedScrubInfo)
    }

    override func setInlineControlsVisible(_ visible: Bool, animated: Bool) {
        isControlsVisible = visible
        renderPlaybackControls(animatedVisibility: animated)
    }

    override func syncProgressDisplayLink() {
        let shouldRun = asset?.mediaType == .video && isPageActive && isPlaying && player != nil
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

    override var isPageActive: Bool {
        didSet {
            guard asset?.mediaType == .video else { return }
            if isPageActive {
                if wasPlayingBeforeDisappear, let player {
                    player.play()
                    isPlaying = true
                    lastSyncedProgressValue = -1
                    updateProgress()
                } else {
                    isPlaying = false
                    lastSyncedProgressValue = -1
                    updateProgress()
                }
                renderPlaybackControls()
                syncProgressDisplayLink()
                if playerLayer != nil, !imageView.isHidden {
                    hideVideoThumbnailAnimatedIfNeeded()
                }
            } else {
                wasPlayingBeforeDisappear = isPlaying
                videoThumbnailHideWorkItem?.cancel()
                videoThumbnailHideWorkItem = nil
                player?.pause()
                isPlaying = false
                renderPlaybackControls()
                progressDisplayLink?.invalidate()
                progressDisplayLink = nil
            }
        }
    }

    override func prepareForReuse() {
        wasPlayingBeforeDisappear = false
        _isScrubbingProgress = false
        isControlsVisible = false
        videoControlsView.setControlsVisible(false, animated: false)
        videoControlsHeightConstraint?.constant = 52
        super.prepareForReuse()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayerLayerFrame()
    }
}
