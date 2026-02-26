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
    private let countLabel = UILabel()
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
        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // 渐变阴影View（添加在imageView上方，Label下方）
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gradientView)
        
        // 添加渐变层
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 0, alpha: 0.7).cgColor,  // 底部深色
            UIColor(white: 0, alpha: 0.3).cgColor,  // 中间半透明
            UIColor(white: 0, alpha: 0).cgColor     // 顶部透明
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        
        // Title Label（后添加，在中层）
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Count Label（最后添加，在上层）
        countLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        countLabel.textColor = .white
        countLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 10
        countLabel.clipsToBounds = true
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        // Layout - Label浮在图片上方
        NSLayoutConstraint.activate([
            // 图片视图：填充整个Cell
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 渐变阴影View：填充整个Cell
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 标题标签：左上角，浮在图片上方
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // 计数标签：左下角，浮在图片上方
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            countLabel.heightAnchor.constraint(equalToConstant: 16),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }

    // MARK: - Configure
    func configure(with collection: PHAssetCollection) {
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        
        titleLabel.text = collection.localizedTitle
        countLabel.text = "\(assets.count)"
        imageView.image = UIImage(systemName: "photo") // 占位图

        guard let coverAsset = assets.firstObject else { return }
        if coverAsset.localIdentifier == currentAssetID { return }
        
        currentAssetID = coverAsset.localIdentifier
        
        let targetSize = CGSize(width: imageView.bounds.width * UIScreen.main.scale,
                                height: imageView.bounds.height * UIScreen.main.scale)
        
        requestID = PHImageManager.default().requestImage(
            for: coverAsset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        ) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 更新渐变层的frame
        if let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = gradientView.bounds
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        countLabel.text = ""
        imageView.image = UIImage(systemName: "photo")
        currentAssetID = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
    }
}
