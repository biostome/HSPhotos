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
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "首"
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.systemRed
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var headerBorderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.systemRed.cgColor
        view.layer.cornerRadius = 4
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        
        contentView.addSubview(indexLabel)
        contentView.addSubview(topLabelsStackView)
        contentView.addSubview(headerBorderView)
        
        // 将锚点和首图label添加到StackView
        topLabelsStackView.addArrangedSubview(anchorLabel)
        topLabelsStackView.addArrangedSubview(headerLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            indexLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            indexLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            indexLabel.heightAnchor.constraint(equalToConstant: 20),
            
            topLabelsStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            topLabelsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            
            anchorLabel.widthAnchor.constraint(equalToConstant: 20),
            anchorLabel.heightAnchor.constraint(equalToConstant: 20),
            
            headerLabel.widthAnchor.constraint(equalToConstant: 20),
            headerLabel.heightAnchor.constraint(equalToConstant: 20),
            
            headerBorderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerBorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerBorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerBorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
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
    func configure(with asset: PHAsset, isSelected: Bool, selectionIndex: Int?, selectionMode: PhotoSelectionMode, index: Int? = nil, isAnchor: Bool = false, isHeader: Bool = false) {
        
        // 保存当前资产
        currentAsset = asset

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
        
        // 设置索引标签
        if let index = index {
            if index >= 0 {
                indexLabel.text = "\(index + 1)"
            } else {
                // 如果index为-1，表示不在自定义排序中，显示"-"
                indexLabel.text = "-"
            }
        }

        // 设置锚点标识
        anchorLabel.isHidden = !isAnchor
        
        // 设置首图标识
        headerLabel.isHidden = !isHeader
        headerBorderView.isHidden = !isHeader
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
        headerLabel.isHidden = true
        headerBorderView.isHidden = true
        currentAssetID = nil
        currentAsset = nil
        if let requestID = requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
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

