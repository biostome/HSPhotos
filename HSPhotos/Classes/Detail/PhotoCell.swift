//
//  PhotoCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//
import UIKit
import Photos

class PhotoCell: UICollectionViewCell {

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
        overlay.layer.cornerRadius = 6
        overlay.layer.borderWidth = 2
        overlay.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
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
    
    // MARK: - 数据缓存
    private var currentAssetID: String?
    private var requestID: PHImageRequestID?

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
        contentView.layer.cornerRadius = 6
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
            
            selectionNumberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            selectionNumberLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            selectionNumberLabel.widthAnchor.constraint(equalToConstant: 20),
            selectionNumberLabel.heightAnchor.constraint(equalToConstant: 20)
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
    func configure(with asset: PHAsset, isSelected: Bool, selectionIndex: Int?, selectionMode: PhotoSelectionMode) {

        // 避免重复请求
        if currentAssetID != asset.localIdentifier {
            currentAssetID = asset.localIdentifier

            let targetSize = CGSize(width: bounds.width * UIScreen.main.scale,
                                    height: bounds.height * UIScreen.main.scale)
            requestID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { [weak self] image, _ in
                self?.imageView.image = image
            }
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
        currentAssetID = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
    }
}
