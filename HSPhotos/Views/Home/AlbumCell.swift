//
//  AlbumCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos



// MARK: - AlbumCell
class AlbumCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let placeholderView = UIImageView()
    private let titleLabel = UILabel()
    private let gradientView = UIView()
    
    private var currentAssetID: String?
    private var requestID: PHImageRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 6
        contentView.layer.shadowOpacity = 0.12
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor(white: 0.9, alpha: 1.0).cgColor
        
        // Image View（先添加，在底层）
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // 占位图视图（添加在imageView上方）
        placeholderView.contentMode = .center
        placeholderView.clipsToBounds = true
        placeholderView.layer.cornerRadius = 12
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeholderView)
        
        // 渐变阴影View（添加在placeholderView上方，Label下方）
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.backgroundColor = .clear
        gradientView.layer.cornerRadius = 12
        gradientView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] // 左下角和右下角圆角
        gradientView.clipsToBounds = true
        contentView.addSubview(gradientView)
        
        // 确保gradientView在正确的层级
        contentView.bringSubviewToFront(gradientView)
        contentView.bringSubviewToFront(titleLabel)
        
        // 添加渐变层
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.7).cgColor,  // 底部深色
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor     // 顶部透明
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.frame = gradientView.bounds
        gradientLayer.cornerRadius = 12
        gradientLayer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] // 左下角和右下角圆角
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        
        // 确保gradientView可见
        gradientView.isHidden = false
        
        // Title Label（添加在gradientView上方）
        titleLabel.textColor = .white // 保持白色，在渐变背景上更清晰
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold) // 增大字体
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // 设置Cell背景色，支持深色模式
        contentView.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .systemGray6 : .systemBackground
        }
        // 确保Cell的layer有圆角
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        

        
        // 设置占位图
        showPlaceholder()
        
        // Layout - Label浮在图片上方
        NSLayoutConstraint.activate([
            // 图片视图：填充整个Cell
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 占位图视图：与imageView大小相同
            placeholderView.topAnchor.constraint(equalTo: imageView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            // 渐变阴影View：高度为Cell的30%
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.3),
            
            // 标题标签：左下角，浮在渐变阴影View上
            titleLabel.bottomAnchor.constraint(equalTo: gradientView.bottomAnchor, constant: -8), // 底部对齐
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12), // 增加左边距
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12), // 增加右边距
            titleLabel.heightAnchor.constraint(equalToConstant: 24), // 增加高度以适应更大的字体
        ])
    }

    // MARK: - Configure
    func configure(with collection: PHAssetCollection) {
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        
        titleLabel.text = collection.localizedTitle
        showPlaceholder() // 显示占位图

        guard let coverAsset = assets.firstObject else { return }
        if coverAsset.localIdentifier == currentAssetID { return }
        
        currentAssetID = coverAsset.localIdentifier
        
        // 适当增加目标图片大小，提高图片质量，同时保持较好的加载速度
        let cellSize = contentView.bounds.size
        // 使用适中的目标尺寸，在速度和质量之间取得平衡
        let targetSize = CGSize(width: cellSize.width * 2,
                                height: cellSize.height * 2)
        
        // 创建图片请求选项，使用均衡模式
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        options.deliveryMode = .opportunistic
        
        requestID = PHImageManager.default().requestImage(
            for: coverAsset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            if let image = image {
                self?.imageView.image = image
                // 有封面图片时，显示图片视图，隐藏占位图
                self?.showImage()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 更新渐变层的frame
        if let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = gradientView.bounds
            // 确保渐变层的圆角与gradientView一致
            gradientLayer.cornerRadius = gradientView.layer.cornerRadius
            gradientLayer.maskedCorners = gradientView.layer.maskedCorners
        }
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
        // 当没有图片时，设置灰白背景色
        contentView.backgroundColor = .systemGray5
        // 更新占位图
        updatePlaceholderImage()
    }
    
    /// 显示图片视图，隐藏占位图
    private func showImage() {
        // 显示图片视图，隐藏占位图
        imageView.isHidden = false
        placeholderView.isHidden = true
        // 有图片时，恢复支持深色模式的背景色
        contentView.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .systemGray6 : .systemBackground
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 当界面模式改变时，更新占位图颜色
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updatePlaceholderImage()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        showPlaceholder() // 显示占位图
        currentAssetID = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
        gradientView.isHidden = false
    }
}
