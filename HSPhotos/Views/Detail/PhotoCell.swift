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
    
    // MARK: - 数据缓存
    private var currentAssetID: String?
    private var requestID: PHImageRequestID?
    private var currentAsset: PHAsset?
    
    // 层级信息缓存，避免重复计算
    private var lastHierarchyText: String?
    private var lastIsHierarchyCollapsed: Bool?
    
    // MARK: - 图片缓存
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 1024 * 1024 * 200
        return cache
    }()
    private var lastCacheKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 布局
    private func setupUI() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 0
        contentView.clipsToBounds = true
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
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
        
        contentView.addSubview(topLabelsStackView)
        contentView.addSubview(bottomStackView)
        
        // 将锚点label添加到StackView
        topLabelsStackView.addArrangedSubview(anchorLabel)
        topLabelsStackView.addArrangedSubview(hierarchyLabel)
        
        // 将媒体图标、时长标签和收藏图标添加到底部StackView
        bottomStackView.addArrangedSubview(mediaIconView)
        bottomStackView.addArrangedSubview(mediaDurationLabel)
        bottomStackView.addArrangedSubview(favoriteIcon)
        
        // 设置约束
        NSLayoutConstraint.activate([
            topLabelsStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            topLabelsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            
            // 底部StackView约束
            bottomStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            bottomStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // 媒体图标约束
            mediaIconView.widthAnchor.constraint(equalToConstant: 16),
            mediaIconView.heightAnchor.constraint(equalToConstant: 16),
            
            // 收藏图标约束
            favoriteIcon.widthAnchor.constraint(equalToConstant: 24),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 24),
            
            anchorLabel.widthAnchor.constraint(equalToConstant: 24),
            anchorLabel.heightAnchor.constraint(equalToConstant: 24),

            hierarchyLabel.heightAnchor.constraint(equalToConstant: 24),
            hierarchyLabel.widthAnchor.constraint(equalToConstant: 40) // 使用固定宽度，避免动态计算
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
    func configure(with asset: PHAsset, isSelected: Bool, selectionIndex: Int?, selectionMode: PhotoSelectionMode, index: Int? = nil, isAnchor: Bool = false, hierarchyText: String? = nil, isHierarchyCollapsed: Bool = false) {
        
        // 保存当前资产
        currentAsset = asset

        // 取消之前的请求（重要：避免滚动时图片延迟显示）
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        
        // 避免重复请求
        if currentAssetID != asset.localIdentifier {
            currentAssetID = asset.localIdentifier

            // 根据 Cell 大小动态调整图片尺寸
            let cellSize = bounds.size
            let maxDimension: CGFloat = min(cellSize.width, cellSize.height) * 2 // 根据 Cell 大小动态调整
            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: maxDimension * scale, height: maxDimension * scale)
            let cacheKey = "\(asset.localIdentifier)_\(maxDimension)_\(scale)"
            
            // 检查缓存
            if let cachedImage = PhotoCell.imageCache.object(forKey: cacheKey as NSString) {
                imageView.image = cachedImage
                lastCacheKey = cacheKey
            } else {
                // 请求新图片
                // 使用更高效的图片加载策略：先显示低质量图片，再显示高质量图片
                let options = PHImageRequestOptions()
                options.version = .current
                options.deliveryMode = .opportunistic
                options.resizeMode = .fast
                options.isNetworkAccessAllowed = true
                
                requestID = PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { [weak self] image, info in
                    guard let self = self, let image = image else { return }
                    
                    // 立即显示图片
                    self.imageView.image = image
                    
                    // 只缓存最终质量的图片
                    let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                    if !isDegraded {
                        PhotoCell.imageCache.setObject(image, forKey: cacheKey as NSString)
                        self.lastCacheKey = cacheKey
                    }
                }
            }
        }
        


        // 设置锚点标识
        anchorLabel.isHidden = !isAnchor
        
        // 只有当层级信息变化时才更新
        if hierarchyText != lastHierarchyText || isHierarchyCollapsed != lastIsHierarchyCollapsed {
            if let hierarchyText, !hierarchyText.isEmpty {
                // 简化层级文本，只显示数字，避免过长文本
                let simplifiedText = hierarchyText.replacingOccurrences(of: "级", with: "")
                hierarchyLabel.text = isHierarchyCollapsed ? "\(simplifiedText)折" : simplifiedText
                hierarchyLabel.isHidden = false
            } else {
                hierarchyLabel.text = nil
                hierarchyLabel.isHidden = true
            }
            
            // 更新缓存
            lastHierarchyText = hierarchyText
            lastIsHierarchyCollapsed = isHierarchyCollapsed
        }
        
        // 设置收藏标识
        let isFavorite = asset.isFavorite
        if favoriteIcon.isHidden != !isFavorite {
            favoriteIcon.isHidden = !isFavorite
            favoriteIcon.image = UIImage(systemName: isFavorite ? "heart.fill" : "heart")
        }
        
        // 设置媒体类型标识
        let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        let isVideo = asset.mediaType == .video
        
        if isLivePhoto {
            mediaIconView.isHidden = false
            mediaIconView.image = UIImage(systemName: "livephoto")
            mediaDurationLabel.isHidden = true
        } else if isVideo {
            mediaIconView.isHidden = false
            mediaIconView.image = UIImage(systemName: "play.fill")
            mediaDurationLabel.isHidden = false
            mediaDurationLabel.text = formatDuration(asset.duration)
        } else {
            mediaIconView.isHidden = true
            mediaDurationLabel.isHidden = true
        }
        
        // 设置选择状态
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

    override func prepareForReuse() {
        super.prepareForReuse()
        selectionOverlay.isHidden = true
        selectionNumberLabel.isHidden = true
        anchorLabel.isHidden = true
        hierarchyLabel.isHidden = true
        mediaIconView.isHidden = true
        mediaDurationLabel.isHidden = true
        favoriteIcon.isHidden = true
        currentAssetID = nil
        currentAsset = nil
        lastHierarchyText = nil
        lastIsHierarchyCollapsed = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
        lastCacheKey = nil
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
