//
//  AlbumCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos



// MARK: - AlbumCell
class AlbumCell: BaseAlbumCell {
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
    
    private let gradientView = UIView()
    private var gradientLayer: CAGradientLayer?
    
    private func setupUI() {
        // 相册布局 - 单张封面图
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // 占位图视图
        placeholderView.contentMode = .center
        placeholderView.clipsToBounds = true
        placeholderView.layer.cornerRadius = 12
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeholderView)
        
        // 渐变视图，使标题更清晰可见
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gradientView)
        
        // 标题标签
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // 照片数量标签
        photoCountLabel.textColor = .white
        photoCountLabel.font = .systemFont(ofSize: 12, weight: .medium)
        photoCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(photoCountLabel)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 相册布局 - 占据整个cell
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            placeholderView.topAnchor.constraint(equalTo: imageView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            // 渐变视图
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 60),
            
            // 标题标签（左下角，浮在图片上方）
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // 照片数量标签（右下角，浮在图片上方）
            photoCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            photoCountLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
        
        // 设置占位图
        updatePlaceholderImage()
    }

    // MARK: - Configure
    func configure(with item: AlbumListItem) {
        // 取消之前的图片请求
        cancelImageRequests()
        
        // 设置相册标题和数量
        titleLabel.text = item.title
        photoCountLabel.text = "\(item.itemCount)"
        
        // 加载相册封面图
        guard let coverAsset = item.coverAsset else {
            showPlaceholder()
            return
        }
        
        if coverAsset.localIdentifier == currentAssetID { return }
        
        currentAssetID = coverAsset.localIdentifier
        
        let cellSize = contentView.bounds.size
        let targetSize = CGSize(width: cellSize.width * 2, height: cellSize.height * 2)
        
        let requestID = loadImage(for: coverAsset, targetSize: targetSize) { [weak self] image in
            if let image = image {
                self?.imageView.image = image
                self?.showImage()
            }
        }
        
        if let requestID = requestID {
            imageRequests.append(requestID)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 每次布局时更新渐变层
        setupGradient()
    }
    
    /// 设置渐变层
    private func setupGradient() {
        // 移除旧的渐变层
        gradientLayer?.removeFromSuperlayer()
        
        // 创建新的渐变层
        let gradient = CAGradientLayer()
        gradient.frame = gradientView.bounds
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradientView.layer.insertSublayer(gradient, at: 0)
        
        // 保存渐变层引用
        gradientLayer = gradient
    }
    
    /// 设置占位图，确保在不同大小的Cell中都能正确显示
    private func updatePlaceholderImage() {
        // 创建一个配置对象，指定渲染模式、大小和颜色
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
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
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AlbumCell, previousTraitCollection: UITraitCollection) in
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
