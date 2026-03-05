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
            hierarchyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }
    
    
    
    lazy var requestOptions: PHImageRequestOptions = {
        
        let options = PHImageRequestOptions()
        options.version = .current
//        options.deliveryMode = .highQualityFormat
//        options.resizeMode = .exact
        
        // 允许iCloud下载
        options.isNetworkAccessAllowed = true
        
        // 设置进度回调
        options.progressHandler = { progress, _, _, _ in
            DispatchQueue.main.async {
//                print("progress: \(progress)%")
            }
        }
        
        return options
    }()

    // MARK: - 配置
    func configure(with asset: PHAsset, isSelected: Bool, selectionIndex: Int?, selectionMode: PhotoSelectionMode, index: Int? = nil, isAnchor: Bool = false, hierarchyText: String? = nil, isHierarchyCollapsed: Bool = false) {
        
        // 保存当前资产
        currentAsset = asset

        // 避免重复请求
        if currentAssetID != asset.localIdentifier {
            currentAssetID = asset.localIdentifier

            // 计算合理的目标大小，避免请求过大的图片
            // 使用最小边长100作为基准，确保图片质量的同时避免过大
            let maxDimension: CGFloat = 200
            // 使用通过上下文获取的UIScreen实例
            let scale = imageView.window?.windowScene?.screen.scale ?? 2.0 // 默认使用2.0作为回退
            let targetSize = CGSize(width: maxDimension * scale,
                                    height: maxDimension * scale)
            requestID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { [weak self] image, _ in
                self?.imageView.image = image
            }
        }
        


        // 设置锚点标识
        anchorLabel.isHidden = !isAnchor
        
        if let hierarchyText, !hierarchyText.isEmpty {
            hierarchyLabel.text = isHierarchyCollapsed ? "\(hierarchyText) 折" : hierarchyText
            hierarchyLabel.isHidden = false
        } else {
            hierarchyLabel.text = nil
            hierarchyLabel.isHidden = true
        }
        
        // 设置收藏标识
        favoriteIcon.isHidden = !asset.isFavorite
        favoriteIcon.image = UIImage(systemName: asset.isFavorite ? "heart.fill" : "heart")
        
        // 设置媒体类型标识
        if asset.mediaSubtypes.contains(.photoLive) {
            mediaIconView.isHidden = false
            mediaIconView.image = UIImage(systemName: "livephoto")
            mediaDurationLabel.isHidden = true
        } else if asset.mediaType == .video {
            mediaIconView.isHidden = false
            mediaIconView.image = UIImage(systemName: "play.fill")
            mediaDurationLabel.isHidden = false
            mediaDurationLabel.text = formatDuration(asset.duration)
        } else {
            mediaIconView.isHidden = true
            mediaDurationLabel.isHidden = true
        }
        
        switch selectionMode {
        case .none:
            selectionOverlay.isHidden = true
            selectionNumberLabel.isHidden = true
        case .multiple:
            selectionOverlay.isHidden = !isSelected
            if isSelected, let index = selectionIndex {
                selectionNumberLabel.text = "\(index)"
                selectionNumberLabel.isHidden = false
            } else {
                selectionNumberLabel.isHidden = true
            }
        case .range:
            selectionOverlay.isHidden = !isSelected
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
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
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
