//
//  PhotoCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//
import UIKit
import Photos
import SKPhotoBrowser

class PhotoCell: UICollectionViewCell, CAAnimationDelegate {

    // MARK: - 懒加载 UI 元素
    public lazy var imageView: UIImageView = {
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
    
    private lazy var indexLabel: UILabel = {
        let label = UILabel()
        
        // 使用更轻量级的背景效果替代虚化
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 1
        
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
    
    fileprivate lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    fileprivate lazy var bigRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    fileprivate var requestId: PHImageRequestID?
    
    
    fileprivate let imageManager = PHCachingImageManager.default()


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
            selectionNumberLabel.widthAnchor.constraint(equalToConstant: 20),
            selectionNumberLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        contentView.addSubview(indexLabel)
        contentView.addSubview(anchorLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            indexLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            indexLabel.widthAnchor.constraint(equalToConstant: 32),
            indexLabel.heightAnchor.constraint(equalToConstant: 20),
            
            anchorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            anchorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            anchorLabel.widthAnchor.constraint(equalToConstant: 20),
            anchorLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - 配置
    func configure(with asset: PHAsset, isSelected: Bool, selectionIndex: Int?, selectionMode: PhotoSelectionMode, index: Int? = nil, isAnchor: Bool = false) {
        
        if let id = requestId {
            imageManager.cancelImageRequest(id)
            requestId = nil
        }
        
        requestId = requestImageForAsset(asset, options: requestOptions) {[weak self] image, requestId in
            if requestId == self?.requestId || self?.requestId == nil {
                self?.imageView.image = image
            }
        }
        
        // 设置索引标签
        if let index = index {
            indexLabel.text = "\(index + 1)"
        }

        // 设置锚点标识
        anchorLabel.isHidden = !isAnchor
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
    
    fileprivate func requestImageForAsset(_ asset: PHAsset, options: PHImageRequestOptions, completion: @escaping (_ image: UIImage?, _ requestId: PHImageRequestID?) -> Void) -> PHImageRequestID {
        
        let scale = UIScreen.main.scale
        let targetSize: CGSize
        
        if options.deliveryMode == .highQualityFormat {
            targetSize = CGSize(width: 600 * scale, height: 600 * scale)
        } else {
            targetSize = CGSize(width: 182 * scale, height: 182 * scale)
        }
        
        requestOptions.isSynchronous = false
        
        // Workaround because PHImageManager.requestImageForAsset doesn't work for burst images
        if asset.representsBurst {
            return imageManager.requestImageData(for: asset, options: options) { data, _, _, dict in
                let image = data.flatMap { UIImage(data: $0) }
                let requestId = dict?[PHImageResultRequestIDKey] as? NSNumber
                completion(image, requestId?.int32Value)
            }
        } else {
            return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, dict in
                let requestId = dict?[PHImageResultRequestIDKey] as? NSNumber
                completion(image, requestId?.int32Value)
            }
        }
    }
}

