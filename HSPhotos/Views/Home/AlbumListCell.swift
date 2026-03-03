//
//  AlbumListCell.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/2.
//

import UIKit
import Photos

/// 相册列表布局Cell，类似于UITableViewCell的布局
class AlbumListCell: BaseAlbumCell {
    private let imageView = UIImageView()
    private let placeholderView = UIImageView()
    private let photoCountLabel = UILabel()
    
    private var currentAssetID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupTraitChangeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 相册布局 - 左侧图片
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // 占位图视图
        placeholderView.contentMode = .center
        placeholderView.clipsToBounds = true
        placeholderView.layer.cornerRadius = 8
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeholderView)
        
        // 标题标签
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // 照片数量标签
        photoCountLabel.textColor = .secondaryLabel
        photoCountLabel.font = .systemFont(ofSize: 14, weight: .regular)
        photoCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(photoCountLabel)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 左侧图片
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor), // 正方形图片
            
            placeholderView.topAnchor.constraint(equalTo: imageView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            // 标题标签（图片右侧，顶部对齐）
            titleLabel.topAnchor.constraint(equalTo: imageView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // 照片数量标签（标题下方）
            photoCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            photoCountLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            photoCountLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
        
        // 设置占位图
        updatePlaceholderImage()
    }

    // MARK: - Configure
    func configure(with item: AlbumListItem) {
        // 取消之前的图片请求
        cancelImageRequests()
        applyHierarchyAppearance(level: item.hierarchyLevel)
        
        // 设置相册标题和数量
        titleLabel.text = item.title
        photoCountLabel.text = "\(item.itemCount) 张照片"
        
        // 加载相册封面图
        guard let coverAsset = item.coverAsset else {
            showPlaceholder()
            return
        }
        
        if coverAsset.localIdentifier == currentAssetID { return }
        
        currentAssetID = coverAsset.localIdentifier
        
        let imageSize = CGSize(width: 80, height: 80)
        let targetSize = CGSize(width: imageSize.width * 2, height: imageSize.height * 2)
        
        _ = loadImage(for: coverAsset, targetSize: targetSize) { [weak self] image in
            if let image = image {
                self?.imageView.image = image
                self?.showImage()
            }
        }
    }
    
    /// 设置占位图，确保在不同大小的Cell中都能正确显示
    private func updatePlaceholderImage() {
        // 创建一个配置对象，指定渲染模式、大小和颜色
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        // 根据当前界面模式设置占位图颜色
        let placeholderColor: UIColor = traitCollection.userInterfaceStyle == .dark ? .lightGray : .darkGray
        let coloredConfiguration = configuration.applying(UIImage.SymbolConfiguration(paletteColors: [placeholderColor]))
        // 使用配置创建系统图标
        let placeholderImage = UIImage(systemName: "photo.on.rectangle", withConfiguration: coloredConfiguration)
        // 设置占位图视图的图片
        placeholderView.image = placeholderImage
    }
    
    /// 显示占位图，隐藏图片视图
    private func showPlaceholder() {
        // 显示占位图视图，隐藏图片视图
        placeholderView.isHidden = false
        imageView.isHidden = true
        // 更新占位图
        updatePlaceholderImage()
    }
    
    /// 显示图片视图，隐藏占位图
    private func showImage() {
        // 显示图片视图，隐藏占位图
        imageView.isHidden = false
        placeholderView.isHidden = true
    }
    
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AlbumListCell, previousTraitCollection: UITraitCollection) in
            // 当界面模式改变时，更新占位图颜色
            self.updatePlaceholderImage()
        }
    }
    
    deinit {
        // 系统会自动处理trait变化注册的清理
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 取消之前的图片请求
        cancelImageRequests()
        
        // 重置UI状态
        titleLabel.text = ""
        photoCountLabel.text = ""
        imageView.image = nil
        
        // 显示占位图
        showPlaceholder()
        
        // 重置状态
        currentAssetID = nil
    }
}
