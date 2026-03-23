//
//  GalleryViewerThumbnailStripView.swift
//  HSPhotos
//
//  大图浏览器底部缩略图条：横向滚动，当前项略高并带描边，与分页同步。
//

import Photos
import UIKit

enum GalleryViewerStripMetrics {
    static let horizontalPadding: CGFloat = 12
    static let inactiveWidth: CGFloat = 40
    static let inactiveHeight: CGFloat = 50
    static let activeWidth: CGFloat = 54
    static let activeHeight: CGFloat = 70
    static let interColumnSpacing: CGFloat = 3
    static let thumbCornerRadiusInactive: CGFloat = 3
    static let thumbCornerRadiusActive: CGFloat = 4
    /// 左右两侧虚化带宽度（模糊 + 渐变淡出）
    static let edgeFadeWidth: CGFloat = 44
    /// 与未选中缩略图等高；选中格更高时可超出条外（见 collectionView / 外层 clipsToBounds）
    static var stripHeight: CGFloat { inactiveHeight }
}

// MARK: - Flow layout（横向一列一项，纵向居中）

private final class GalleryThumbnailStripFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        scrollDirection = .horizontal
        minimumLineSpacing = GalleryViewerStripMetrics.interColumnSpacing
        minimumInteritemSpacing = 0
        sectionInset = UIEdgeInsets(
            top: 0,
            left: GalleryViewerStripMetrics.horizontalPadding,
            bottom: 0,
            right: GalleryViewerStripMetrics.horizontalPadding
        )
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attrs = super.layoutAttributesForElements(in: rect) else { return nil }
        return attrs.compactMap { a in
            guard let copy = a.copy() as? UICollectionViewLayoutAttributes else { return nil }
            if copy.representedElementCategory == .cell {
                centerCellVertically(copy)
            }
            return copy
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attrs = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else { return nil }
        centerCellVertically(attrs)
        return attrs
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { true }

    private func centerCellVertically(_ attrs: UICollectionViewLayoutAttributes) {
        guard let cv = collectionView else { return }
        let top = cv.adjustedContentInset.top
        let h = cv.bounds.height - top - cv.adjustedContentInset.bottom
        var f = attrs.frame
        f.origin.y = top + (h - f.height) / 2
        attrs.frame = f
    }
}

// MARK: - Cell

private final class GalleryThumbnailStripCell: UICollectionViewCell {
    static let reuseId = "GalleryThumbnailStripCell"

    private let imageView = UIImageView()
    private let dimOverlay = UIView()
    private let playIcon = UIImageView()
    private let durationLabel = UILabel()
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimOverlay.isHidden = true
        dimOverlay.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(dimOverlay)

        playIcon.image = UIImage(systemName: "play.fill")
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit
        playIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.isHidden = true
        imageView.addSubview(playIcon)

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        durationLabel.textColor = .white
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.isHidden = true
        imageView.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            dimOverlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            dimOverlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            playIcon.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            playIcon.centerYAnchor.constraint(equalTo: imageView.centerYAnchor, constant: -4),

            durationLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -3),
            durationLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
        imageView.image = nil
        dimOverlay.isHidden = true
        playIcon.isHidden = true
        durationLabel.isHidden = true
    }

    func configure(asset: PHAsset, isSelected: Bool, targetScale: CGFloat) {
        let m = GalleryViewerStripMetrics.self
        imageView.layer.cornerRadius = isSelected ? m.thumbCornerRadiusActive : m.thumbCornerRadiusInactive
        imageView.layer.borderWidth = isSelected ? 2 : 0
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor

        let w = isSelected ? m.activeWidth : m.inactiveWidth
        let h = isSelected ? m.activeHeight : m.inactiveHeight
        let px = max(1, Int(w * targetScale * 2))
        let py = max(1, Int(h * targetScale * 2))
        let targetSize = CGSize(width: px, height: py)

        let isVideo = asset.mediaType == .video
        dimOverlay.isHidden = !isVideo
        playIcon.isHidden = !isVideo
        if isVideo {
            let sec = max(0, Int(round(asset.duration)))
            let mm = sec / 60
            let ss = sec % 60
            durationLabel.text = String(format: "%d:%02d", mm, ss)
            durationLabel.isHidden = false
        } else {
            durationLabel.isHidden = true
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let self else { return }
            self.imageView.image = image
        }
    }
}

// MARK: - Strip

final class GalleryViewerThumbnailStripView: UIView {
    var assets: [PHAsset] = [] {
        didSet {
            if selectedIndex >= assets.count {
                selectedIndex = max(0, assets.count - 1)
            }
            collectionView.reloadData()
        }
    }

    private var selectedIndex: Int = 0
    /// 由 `scrollToItem` 等引起的滚动，不触发「居中换页」逻辑。
    private var isProgrammaticStripScroll = false
    var onSelect: ((Int) -> Void)?
    /// 横向滑动缩略条，视口中心对准的索引变化时回调（用于同步大图）。
    var onCenteredIndexChanged: ((Int) -> Void)?

    private let collectionView: UICollectionView
    private let leftEdgeFade = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let rightEdgeFade = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let leftFadeMask = CAGradientLayer()
    private let rightFadeMask = CAGradientLayer()

    override init(frame: CGRect) {
        let layout = GalleryThumbnailStripFlowLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        clipsToBounds = false
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GalleryThumbnailStripCell.self, forCellWithReuseIdentifier: GalleryThumbnailStripCell.reuseId)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)

        let m = GalleryViewerStripMetrics.self
        for (v, mask, isLeft) in [(leftEdgeFade, leftFadeMask, true), (rightEdgeFade, rightFadeMask, false)] {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isUserInteractionEnabled = false
            v.clipsToBounds = true
            if isLeft {
                mask.colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
                mask.startPoint = CGPoint(x: 0, y: 0.5)
                mask.endPoint = CGPoint(x: 1, y: 0.5)
            } else {
                mask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
                mask.startPoint = CGPoint(x: 0, y: 0.5)
                mask.endPoint = CGPoint(x: 1, y: 0.5)
            }
            mask.locations = [0, 1]
            v.layer.mask = mask
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftEdgeFade.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftEdgeFade.topAnchor.constraint(equalTo: topAnchor),
            leftEdgeFade.bottomAnchor.constraint(equalTo: bottomAnchor),
            leftEdgeFade.widthAnchor.constraint(equalToConstant: m.edgeFadeWidth),

            rightEdgeFade.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightEdgeFade.topAnchor.constraint(equalTo: topAnchor),
            rightEdgeFade.bottomAnchor.constraint(equalTo: bottomAnchor),
            rightEdgeFade.widthAnchor.constraint(equalToConstant: m.edgeFadeWidth)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftFadeMask.frame = leftEdgeFade.bounds
        rightFadeMask.frame = rightEdgeFade.bounds
    }

    func syncSelection(_ index: Int, animated: Bool) {
        guard !assets.isEmpty else { return }
        let clamped = min(max(0, index), assets.count - 1)
        let previous = selectedIndex
        selectedIndex = clamped
        if previous != selectedIndex {
            let paths = [IndexPath(item: previous, section: 0), IndexPath(item: selectedIndex, section: 0)]
                .filter { $0.item >= 0 && $0.item < assets.count }
            let unique = Array(Set(paths))
            collectionView.performBatchUpdates {
                collectionView.reloadItems(at: unique)
            }
        }
        scrollToSelected(animated: animated)
    }

    private func scrollToSelected(animated: Bool) {
        guard selectedIndex >= 0, selectedIndex < assets.count else { return }
        let ip = IndexPath(item: selectedIndex, section: 0)
        collectionView.layoutIfNeeded()
        isProgrammaticStripScroll = true
        collectionView.scrollToItem(at: ip, at: .centeredHorizontally, animated: animated)
        if !animated {
            DispatchQueue.main.async { [weak self] in
                self?.isProgrammaticStripScroll = false
            }
        }
    }

    /// 视口中心点命中的索引；间隙处取横向距离最近的可见 cell。
    private func indexAtViewportCenter() -> Int? {
        guard !assets.isEmpty, collectionView.bounds.width > 0 else { return nil }
        let pt = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        if let ip = collectionView.indexPathForItem(at: pt), ip.item < assets.count {
            return ip.item
        }
        var best = CGFloat.greatestFiniteMagnitude
        var bestItem: Int?
        for cell in collectionView.visibleCells {
            guard let ip = collectionView.indexPath(for: cell), ip.item < assets.count else { continue }
            let frameInCV = collectionView.convert(cell.bounds, from: cell)
            let d = abs(frameInCV.midX - pt.x)
            if d < best {
                best = d
                bestItem = ip.item
            }
        }
        return bestItem
    }
}

extension GalleryViewerThumbnailStripView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GalleryThumbnailStripCell.reuseId, for: indexPath) as! GalleryThumbnailStripCell
        let asset = assets[indexPath.item]
        let isSelected = indexPath.item == selectedIndex
        let scale = window?.screen.scale ?? UIScreen.main.scale
        cell.configure(asset: asset, isSelected: isSelected, targetScale: scale)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let m = GalleryViewerStripMetrics.self
        if indexPath.item == selectedIndex {
            return CGSize(width: m.activeWidth, height: m.activeHeight)
        }
        return CGSize(width: m.inactiveWidth, height: m.inactiveHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(indexPath.item)
    }

    // MARK: UIScrollViewDelegate（滑动缩略条时按居中项切换大图）

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            isProgrammaticStripScroll = false
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, !isProgrammaticStripScroll, !assets.isEmpty else { return }
        guard let idx = indexAtViewportCenter(), idx != selectedIndex else { return }
        let previous = selectedIndex
        selectedIndex = idx
        let paths = [IndexPath(item: previous, section: 0), IndexPath(item: idx, section: 0)]
            .filter { $0.item >= 0 && $0.item < assets.count }
        collectionView.performBatchUpdates {
            collectionView.reloadItems(at: Array(Set(paths)))
        }
        onCenteredIndexChanged?(idx)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            isProgrammaticStripScroll = false
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            isProgrammaticStripScroll = false
        }
    }
}
