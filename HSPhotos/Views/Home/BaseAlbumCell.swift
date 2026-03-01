//
//  BaseAlbumCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

/// 相册Cell的基类，提取共同功能
class BaseAlbumCell: UICollectionViewCell {
    // 标题标签
    let titleLabel = UILabel()
    
    // 图片请求ID数组，用于取消请求
    var imageRequests: [PHImageRequestID] = []

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
    
    /// 取消所有图片请求
    func cancelImageRequests() {
        for requestID in imageRequests {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        imageRequests.removeAll()
    }
    
    /// 加载图片的通用方法
    func loadImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        options.deliveryMode = .opportunistic
        
        let requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
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
    }
}