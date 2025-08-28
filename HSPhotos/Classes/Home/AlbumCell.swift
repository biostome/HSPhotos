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
        
        // Image View
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // Count Label
        countLabel.backgroundColor = .white
        countLabel.textColor = UIColor(white: 0.2, alpha: 1.0)
        countLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 10
        countLabel.clipsToBounds = true
        countLabel.layer.borderWidth = 0.5
        countLabel.layer.borderColor = UIColor(white: 0.9, alpha: 1.0).cgColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        // Title Label
        titleLabel.textColor = UIColor(white: 0.2, alpha: 1.0)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.75),
            
            countLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -8),
            countLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            countLabel.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
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
