//
//  BaseAlbumCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

/// 图片缓存工具类
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // 设置缓存大小限制
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 50 // 50MB
    }
    
    func get(key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func remove(key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

/// 相册Cell的基类，提取共同功能
class BaseAlbumCell: UICollectionViewCell {
    // 标题标签
    let titleLabel = UILabel()
    
    // 图片请求ID数组，用于取消请求
    var imageRequests: [PHImageRequestID] = []
    private var hierarchyLevel: Int = 0

    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCommonUI()
        setupTraitChangeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 设置通用的UI元素
    private func setupCommonUI() {
        // 设置背景色为浅灰色，支持深色模式
        setupBackgroundColor()
        
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 12
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 6
        contentView.layer.shadowOpacity = 0.12
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor(white: 0.9, alpha: 1.0).cgColor
        
        // 标题标签
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    /// 设置背景色，支持深色模式
    private func setupBackgroundColor() {
        contentView.backgroundColor = UIColor {
            $0.userInterfaceStyle == .dark ? .systemGray5 : .systemGray4
        }
    }
    
    /// 根据层级设置背景与内容的水平缩进
    func applyHierarchyAppearance(level: Int) {
        let newLevel = max(level, 0)
        if hierarchyLevel != newLevel {
            hierarchyLevel = newLevel
            setNeedsLayout()
        }
    }
    
    /// 取消所有图片请求
    func cancelImageRequests() {
        for requestID in imageRequests {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        imageRequests.removeAll()
    }
    
    /// 生成图片缓存键
    private func generateCacheKey(for asset: PHAsset, targetSize: CGSize) -> String {
        return "\(asset.localIdentifier)_\(targetSize.width)_\(targetSize.height)"
    }
    
    /// 加载图片的通用方法
    func loadImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {
        // 检查缓存
        let cacheKey = generateCacheKey(for: asset, targetSize: targetSize)
        if let cachedImage = ImageCache.shared.get(key: cacheKey) {
            completion(cachedImage)
            return nil
        }
        
        // 配置图片请求选项
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            guard let self = self else { return }
            
            // 检查是否是最终图片
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if !isDegraded, let image = image {
                // 缓存图片
                ImageCache.shared.set(key: cacheKey, image: image)
            }
            
            completion(image)
        }
        
        imageRequests.append(requestID)
        return requestID
    }
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: BaseAlbumCell, previousTraitCollection: UITraitCollection) in
            self.setupBackgroundColor()
        }
    }
    
    deinit {
        // 移除trait变化监听
        // 系统会自动处理trait变化注册的清理
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        cancelImageRequests()
        // 优化：不在prepareForReuse中重置层级，避免不必要的布局更新
        // applyHierarchyAppearance(level: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 优化：只在层级大于0时进行缩进计算
        if hierarchyLevel > 0 {
            let inset = CGFloat(hierarchyLevel) * 24.0
            contentView.frame = bounds.inset(by: UIEdgeInsets(top: 0, left: inset, bottom: 0, right: 0))
        } else {
            contentView.frame = bounds
        }
    }
}
