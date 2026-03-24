import UIKit

final class VideoPlaybackControlsView: UIView {
    let playPauseButton = UIButton(type: .system)
    let progressSlider = UISlider()
    let muteButton = UIButton(type: .system)
    private let scrubInfoLabel = UILabel()
    private let glassView: UIVisualEffectView = {
        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = true
        let v = UIVisualEffectView(effect: glass)
        v.cornerConfiguration = .capsule()
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    var onPlayPauseTapped: (() -> Void)?
    var onSliderValueChanged: ((UISlider) -> Void)?
    var onMuteTapped: (() -> Void)?
    var onSliderTrackingChanged: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        setupSubviews()
        configureProgressSliderAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(glassView)

        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(handlePlayPauseTapped), for: .touchUpInside)
        glassView.contentView.addSubview(playPauseButton)

        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        progressSlider.addTarget(self, action: #selector(handleSliderValueChanged(_:)), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(handleSliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(handleSliderTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        glassView.contentView.addSubview(progressSlider)

        muteButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        muteButton.tintColor = .white
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.addTarget(self, action: #selector(handleMuteTapped), for: .touchUpInside)
        glassView.contentView.addSubview(muteButton)

        scrubInfoLabel.textColor = .white
        scrubInfoLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        scrubInfoLabel.textAlignment = .center
        scrubInfoLabel.numberOfLines = 1
        scrubInfoLabel.alpha = 0
        scrubInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrubInfoLabel)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            playPauseButton.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 16),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 30),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),

            muteButton.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -16),
            muteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 30),
            muteButton.heightAnchor.constraint(equalToConstant: 30),

            progressSlider.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 16),
            progressSlider.trailingAnchor.constraint(equalTo: muteButton.leadingAnchor, constant: -16),
            progressSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            // 触摸区域高度，轨道视觉高度由 track image 决定
            progressSlider.heightAnchor.constraint(equalToConstant: 22),

            scrubInfoLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scrubInfoLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6)
        ])
    }

    func setControlsVisible(_ visible: Bool, animated: Bool) {
        let animations = {
            self.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: animations)
        } else {
            animations()
        }
    }

    func setPlayPauseIcon(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    func setMuteIcon(isMuted: Bool) {
        let imageName = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    func setScrubInfo(_ text: String) {
        scrubInfoLabel.text = text
    }

    func setScrubInfoVisible(_ visible: Bool, animated: Bool) {
        let animations = {
            self.scrubInfoLabel.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: animations)
        } else {
            animations()
        }
    }

    @objc private func handlePlayPauseTapped() {
        onPlayPauseTapped?()
    }

    @objc private func handleSliderValueChanged(_ slider: UISlider) {
        onSliderValueChanged?(slider)
    }

    @objc private func handleSliderTouchDown() {
        onSliderTrackingChanged?(true)
    }

    @objc private func handleSliderTouchUp() {
        onSliderTrackingChanged?(false)
    }

    @objc private func handleMuteTapped() {
        onMuteTapped?()
    }

    private func configureProgressSliderAppearance() {
        // 细圆角轨道 + 填充（拇指尽量不明显）
//        let trackHeight: CGFloat = 4
//        let baseWidth: CGFloat = 120
//
//        let maxColor = UIColor.white.withAlphaComponent(0.35)
//        let minColor = UIColor.white.withAlphaComponent(0.75)
//
//        func makeRoundedTrack(color: UIColor) -> UIImage {
//            let size = CGSize(width: baseWidth, height: trackHeight)
//            let renderer = UIGraphicsImageRenderer(size: size)
//            return renderer.image { ctx in
//                let rect = CGRect(origin: .zero, size: size)
//                let path = UIBezierPath(roundedRect: rect, cornerRadius: trackHeight / 2)
//                ctx.cgContext.setFillColor(color.cgColor)
//                path.fill()
//            }.resizableImage(
//                withCapInsets: UIEdgeInsets(top: 0, left: baseWidth / 2, bottom: 0, right: baseWidth / 2),
//                resizingMode: .stretch
//            )
//        }
//
//        let thumbImg = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
//            ctx.cgContext.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
//        }
//
//        let maxImg = makeRoundedTrack(color: maxColor)
//        let minImg = makeRoundedTrack(color: minColor)
//
//        progressSlider.setMaximumTrackImage(maxImg, for: .normal)
//        progressSlider.setMinimumTrackImage(minImg, for: .normal)
//        progressSlider.setThumbImage(thumbImg, for: .normal)
//        progressSlider.setThumbImage(thumbImg, for: .highlighted)
//        progressSlider.setThumbImage(thumbImg, for: .selected)
        progressSlider.thumbTintColor = UIColor.white.withAlphaComponent(0.5);
    }
}
