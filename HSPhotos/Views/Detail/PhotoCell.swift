//
//  PhotoCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//
import UIKit
import Photos

class PhotoCell: UICollectionViewCell, CAAnimationDelegate {

    // MARK: - 懒加载 UI 元素
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iv)
        return iv
    }()
    
    private lazy var selectionOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.25)
        overlay.layer.cornerRadius = 0
        overlay.layer.borderWidth = 2
        overlay.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlay)
        return overlay
    }()
    
    private lazy var highlightOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.25)
        overlay.layer.cornerRadius = 0
        overlay.layer.borderWidth = 2
        overlay.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = false
        contentView.addSubview(overlay)
        return overlay
    }()
    
    private lazy var selectionNumberLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        return label
    }()
    

    
    private lazy var anchorLabel: UILabel = {
        let label = UILabel()
        label.text = "锚"
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.systemOrange
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var hierarchyLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var topLabelsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var bottomStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var mediaIconView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = UIColor.white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var mediaDurationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var favoriteIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "heart")
        iv.tintColor = UIColor.white
        iv.contentMode = .center
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var displayInfoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.alignment = .trailing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var customOrderLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var creationDateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    private lazy var modificationDateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    // MARK: - 数据缓存
    private var currentAssetID: String?
    private var requestID: PHImageRequestID?
    private var currentAsset: PHAsset?
    
    // 层级信息缓存，避免重复计算
    private var lastHierarchyText: String?
    private var lastIsHierarchyCollapsed: Bool?
    
    // MARK: - 图片缓存
    private static let heartImage = UIImage(systemName: "heart")
    private static let heartFillImage = UIImage(systemName: "heart.fill")
    private static let livePhotoImage = UIImage(systemName: "livephoto")
    private static let playFillImage = UIImage(systemName: "play.fill")
    
    /// 共享 PHCachingImageManager，专为快速滚动列表设计
    static let cachingManager: PHCachingImageManager = {
        PHCachingImageManager()
    }()
    
    /// 小 cell（compact）专用：fastFormat 只回调一次，最大化滚动性能
    static let thumbnailOptionsFast: PHImageRequestOptions = {
        let o = PHImageRequestOptions()
        o.deliveryMode = .fastFormat
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = true
        return o
    }()
    
    /// 大 cell 专用：opportunistic 先返回低质量再返回高质量，保证最终清晰
    static let thumbnailOptionsQuality: PHImageRequestOptions = {
        let o = PHImageRequestOptions()
        o.deliveryMode = .opportunistic
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = true
        return o
    }()
    
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 1024 * 1024 * 200
        return cache
    }()
    private var lastCacheKey: String?
    
    static func thumbnailSize(for cellSize: CGSize, scale: CGFloat) -> CGSize {
        let dimension = max(cellSize.width, cellSize.height) * scale
        return CGSize(width: dimension, height: dimension)
    }
    
    static func cacheKey(for assetID: String, cellSize: CGSize, scale: CGFloat) -> String {
        let dimension = Int(max(cellSize.width, cellSize.height) * scale)
        return "\(assetID)_\(dimension)"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 布局
    private var overlaysInstalled = false
    private var labelsInstalled = false
    
    private func setupUI() {
        contentView.backgroundColor = .white
        contentView.clipsToBounds = true
        
        // 只创建 imageView，其他子视图延迟到首次需要时再创建
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    /// 首次需要选中/高亮效果时安装 overlay 子视图
    private func installOverlaysIfNeeded() {
        guard !overlaysInstalled else { return }
        overlaysInstalled = true
        
        NSLayoutConstraint.activate([
            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            highlightOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            highlightOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            highlightOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            highlightOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            selectionNumberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            selectionNumberLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            selectionNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            selectionNumberLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    /// 首次需要标签/图标时安装
    private func installLabelsIfNeeded() {
        guard !labelsInstalled else { return }
        labelsInstalled = true
        
        contentView.addSubview(topLabelsStackView)
        contentView.addSubview(bottomStackView)
        contentView.addSubview(displayInfoStackView)
        
        topLabelsStackView.addArrangedSubview(anchorLabel)
        topLabelsStackView.addArrangedSubview(hierarchyLabel)
        
        bottomStackView.addArrangedSubview(mediaIconView)
        bottomStackView.addArrangedSubview(mediaDurationLabel)
        bottomStackView.addArrangedSubview(favoriteIcon)

        displayInfoStackView.addArrangedSubview(customOrderLabel)
        displayInfoStackView.addArrangedSubview(creationDateLabel)
        displayInfoStackView.addArrangedSubview(modificationDateLabel)
        
        NSLayoutConstraint.activate([
            topLabelsStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            topLabelsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            
            bottomStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            bottomStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            displayInfoStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            displayInfoStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            mediaIconView.widthAnchor.constraint(equalToConstant: 16),
            mediaIconView.heightAnchor.constraint(equalToConstant: 16),
            
            favoriteIcon.widthAnchor.constraint(equalToConstant: 24),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 24),
            
            anchorLabel.widthAnchor.constraint(equalToConstant: 24),
            anchorLabel.heightAnchor.constraint(equalToConstant: 24),
            
            hierarchyLabel.heightAnchor.constraint(equalToConstant: 24),
            hierarchyLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    
    
    lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat // 使用高质量格式，确保滚动时图片清晰
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        return options
    }()

    // MARK: - 配置
    func configure(
        with asset: PHAsset,
        isSelected: Bool,
        selectionIndex: Int?,
        selectionMode: PhotoSelectionMode,
        customOrderNumber: Int? = nil,
        creationDateText: String? = nil,
        modificationDateText: String? = nil,
        showFieldPrefixes: Bool = true,
        isAnchor: Bool = false,
        hierarchyText: String? = nil,
        isHierarchyCollapsed: Bool = false,
        compact: Bool = false
    ) {
        
        currentAsset = asset
        
        if let rid = requestID {
            Self.cachingManager.cancelImageRequest(rid)
            requestID = nil
        }
        
        loadImage(for: asset, compact: compact)
        
        // compact 模式（列数 >= 7）：cell 太小，只显示图片和选中框
        if compact {
            if isSelected {
                installOverlaysIfNeeded()
                selectionOverlay.isHidden = false
            } else if overlaysInstalled {
                selectionOverlay.isHidden = true
            }
            if labelsInstalled {
                customOrderLabel.isHidden = true
                creationDateLabel.isHidden = true
                modificationDateLabel.isHidden = true
            }
            return
        }
        
        installOverlaysIfNeeded()
        installLabelsIfNeeded()
        
        anchorLabel.isHidden = !isAnchor
        
        if hierarchyText != lastHierarchyText || isHierarchyCollapsed != lastIsHierarchyCollapsed {
            if let hierarchyText, !hierarchyText.isEmpty {
                let simplifiedText = hierarchyText.replacingOccurrences(of: "级", with: "")
                hierarchyLabel.text = isHierarchyCollapsed ? "\(simplifiedText)折" : simplifiedText
                hierarchyLabel.isHidden = false
            } else {
                hierarchyLabel.text = nil
                hierarchyLabel.isHidden = true
            }
            lastHierarchyText = hierarchyText
            lastIsHierarchyCollapsed = isHierarchyCollapsed
        }
        
        let isFavorite = asset.isFavorite
        if favoriteIcon.isHidden != !isFavorite {
            favoriteIcon.isHidden = !isFavorite
            favoriteIcon.image = isFavorite ? Self.heartFillImage : Self.heartImage
        }

        if let customOrderNumber {
            customOrderLabel.text = showFieldPrefixes ? " #\(customOrderNumber) " : " \(customOrderNumber) "
            customOrderLabel.isHidden = false
        } else {
            customOrderLabel.isHidden = true
        }

        if let creationDateText, !creationDateText.isEmpty {
            creationDateLabel.text = showFieldPrefixes ? " C \(creationDateText) " : " \(creationDateText) "
            creationDateLabel.isHidden = false
        } else {
            creationDateLabel.isHidden = true
        }

        if let modificationDateText, !modificationDateText.isEmpty {
            modificationDateLabel.text = showFieldPrefixes ? " M \(modificationDateText) " : " \(modificationDateText) "
            modificationDateLabel.isHidden = false
        } else {
            modificationDateLabel.isHidden = true
        }
        
        let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        let isVideo = asset.mediaType == .video
        
        if isLivePhoto {
            mediaIconView.isHidden = false
            mediaIconView.image = Self.livePhotoImage
            mediaDurationLabel.isHidden = true
        } else if isVideo {
            mediaIconView.isHidden = false
            mediaIconView.image = Self.playFillImage
            mediaDurationLabel.isHidden = false
            mediaDurationLabel.text = formatDuration(asset.duration)
        } else {
            mediaIconView.isHidden = true
            mediaDurationLabel.isHidden = true
        }
        
        selectionOverlay.isHidden = !isSelected
        
        switch selectionMode {
        case .none:
            selectionNumberLabel.isHidden = true
        case .multiple, .range:
            if isSelected, let index = selectionIndex {
                selectionNumberLabel.text = "\(index)"
                selectionNumberLabel.isHidden = false
            } else {
                selectionNumberLabel.isHidden = true
            }
        }
    }
    
    private func loadImage(for asset: PHAsset, compact: Bool) {
        guard currentAssetID != asset.localIdentifier else { return }
        currentAssetID = asset.localIdentifier

        let cellSize = bounds.size
        let scale = traitCollection.displayScale
        let cacheKey = Self.cacheKey(for: asset.localIdentifier, cellSize: cellSize, scale: scale)
        
        if let cachedImage = Self.imageCache.object(forKey: cacheKey as NSString) {
            imageView.image = cachedImage
            lastCacheKey = cacheKey
        } else {
            let targetSize = Self.thumbnailSize(for: cellSize, scale: scale)
            let options = compact ? Self.thumbnailOptionsFast : Self.thumbnailOptionsQuality
            
            requestID = Self.cachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                guard let self = self, let image = image else { return }
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                DispatchQueue.main.async {
                    guard self.currentAssetID == asset.localIdentifier else { return }
                    self.imageView.image = image
                    if !isDegraded {
                        Self.imageCache.setObject(image, forKey: cacheKey as NSString)
                        self.lastCacheKey = cacheKey
                    }
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 只重置已创建的子视图，避免触发 lazy 初始化
        if overlaysInstalled {
            selectionOverlay.isHidden = true
            selectionNumberLabel.isHidden = true
        }
        if labelsInstalled {
            anchorLabel.isHidden = true
            hierarchyLabel.isHidden = true
            mediaIconView.isHidden = true
            mediaDurationLabel.isHidden = true
            favoriteIcon.isHidden = true
            customOrderLabel.isHidden = true
            creationDateLabel.isHidden = true
            modificationDateLabel.isHidden = true
        }
        currentAsset = nil
        lastHierarchyText = nil
        lastIsHierarchyCollapsed = nil
        if let rid = requestID {
            Self.cachingManager.cancelImageRequest(rid)
        }
        requestID = nil
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return String(format: "0:%02d", s)
    }
    
    /// 执行渐变柔光高亮效果
    func performHighlightAnimation() {
        installOverlaysIfNeeded()
        self.highlightOverlay.isHidden = false
        UIView.animate(withDuration: 0.45) {
            self.highlightOverlay.alpha = 0.8
        } completion: { completion in
            UIView.animate(withDuration: 0.45) {
                self.highlightOverlay.alpha = 0
            } completion: { finish in
                self.highlightOverlay.isHidden = true
            }
        }
    }
}
