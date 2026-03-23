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

    private let playPauseButton = UIButton(type: .system)
    private let progressSlider = UISlider()
    private let timeLabel = UILabel()
    private let videoControlView = UIView()

    private var isControlsVisible = false
    private var isPlaying = false
    private var timeObserver: Any?

    private let loadingContainer = UIView()
    private let loadingActivityIndicator = UIActivityIndicatorView(style: .large)
    private let loadingStatusLabel = UILabel()
    /// 视频较慢时才显示转圈，本地秒开则取消，避免闪一下
    private var videoLoadingDelayedWorkItem: DispatchWorkItem?

    let asset: PHAsset
    var index: Int = 0
    var scrollViewZoomScale: CGFloat { scrollView.zoomScale }

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
        videoControlView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        videoControlView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.addSubview(videoControlView)

        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        videoControlView.addSubview(playPauseButton)

        progressSlider.minimumTrackTintColor = .white
        progressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.5)
        progressSlider.thumbTintColor = .white
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        videoControlView.addSubview(progressSlider)

        timeLabel.textColor = .white
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        videoControlView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            videoControlView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            videoControlView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            videoControlView.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor),
            videoControlView.heightAnchor.constraint(equalToConstant: 60),

            playPauseButton.leadingAnchor.constraint(equalTo: videoControlView.leadingAnchor, constant: 16),
            playPauseButton.centerYAnchor.constraint(equalTo: videoControlView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 30),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),

            timeLabel.trailingAnchor.constraint(equalTo: videoControlView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: videoControlView.centerYAnchor),

            progressSlider.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 16),
            progressSlider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -16),
            progressSlider.centerYAnchor.constraint(equalTo: videoControlView.centerYAnchor),
            progressSlider.heightAnchor.constraint(equalToConstant: 40)
        ])

        videoControlView.alpha = 0
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
        UIView.animate(withDuration: 0.3) {
            self.videoControlView.alpha = self.isControlsVisible ? 1 : 0
        }
    }

    @objc private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
        isPlaying.toggle()
    }

    @objc private func sliderValueChanged(_ slider: UISlider) {
        guard let player = player, let duration = player.currentItem?.duration else { return }
        let seekTime = CMTime(seconds: Double(slider.value) * duration.seconds, preferredTimescale: 600)
        player.seek(to: seekTime) { _ in }
    }

    private func updateProgress() {
        guard let player = player, let currentItem = player.currentItem else { return }
        let duration = currentItem.duration.seconds
        let currentTime = player.currentTime().seconds
        progressSlider.value = Float(currentTime / duration)
        timeLabel.text = formatTime(currentTime) + " / " + formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
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
                        self.isPlaying = true
                        let playerLayer = AVPlayerLayer(player: player)
                        playerLayer.videoGravity = .resizeAspect
                        playerLayer.frame = self.playerContainerView.bounds
                        self.playerContainerView.layer.addSublayer(playerLayer)
                        self.playerLayer = playerLayer
                        player.play()
                        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
                        self.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                            self?.updateProgress()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            UIView.animate(withDuration: 0.3) {
                                self?.imageView.alpha = 0
                            } completion: { _ in
                                self?.imageView.isHidden = true
                                self?.imageView.alpha = 1
                            }
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
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
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
