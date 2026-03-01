//
//  FolderCell.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

/// 文件夹Cell，显示4宫格布局
class FolderCell: BaseAlbumCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let containerView = UIView()
    private let collectionView: UICollectionView
    private var assets: [PHAsset] = []

    override init(frame: CGRect) {
        // 初始化CollectionView
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.scrollDirection = .vertical
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 容器视图
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // CollectionView设置
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false // 关闭用户交互
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        containerView.addSubview(collectionView)
        
        // 添加标题标签
        titleLabel.textAlignment = .left
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 容器视图
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -8), // 与标题保持8间距
            
            // CollectionView - 四宫格布局
            collectionView.topAnchor.constraint(equalTo: containerView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor), // 填满容器视图
            
            // 文件夹标题（在左下角）
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 20), // 固定标题高度
        ])
    }
    
    // MARK: - Configure
    func configure(with item: AlbumListItem) {
        titleLabel.text = item.title
        
        // 取消之前的图片请求
        cancelImageRequests()
        
        // 加载文件夹缩略图
        loadFolderThumbnails()
    }
    
    private func loadFolderThumbnails() {
        // 获取所有相册的照片作为文件夹缩略图
        let options = PHFetchOptions()
        options.fetchLimit = 4
        
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        var assets: [PHAsset] = []
        
        albums.enumerateObjects { (collection, _, _) in
            if let assetCollection = collection as? PHAssetCollection {
                let albumAssets = PHAsset.fetchAssets(in: assetCollection, options: nil)
                if let asset = albumAssets.firstObject {
                    assets.append(asset)
                    if assets.count >= 4 {
                        return
                    }
                }
            }
        }
        
        self.assets = assets
        collectionView.reloadData()
    }
    
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as! ThumbnailCell
        
        if indexPath.item < assets.count {
            let asset = assets[indexPath.item]
            let thumbnailSize = CGSize(width: 100, height: 100)
            
            loadImage(for: asset, targetSize: thumbnailSize) { [weak self] image in
                if let image = image {
                    cell.imageView.image = image
                    cell.imageView.backgroundColor = .clear
                }
            }
        } else {
            cell.imageView.image = nil
            // 设置四宫格背景色为稍微深一点的灰色，支持深色模式
            cell.imageView.backgroundColor = UIColor {
                $0.userInterfaceStyle == .dark ? .systemGray4 : .systemGray3
            }
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 计算单元格大小，确保四宫格大小相等
        // 宽度：(CollectionView宽度 - 间距) / 2
        let collectionViewWidth = collectionView.bounds.width
        let width = floor((collectionViewWidth - 8) / 2) // 2列，间距8
        
        // 高度：(CollectionView高度 - 间距) / 2
        let collectionViewHeight = collectionView.bounds.height
        let height = floor((collectionViewHeight - 8) / 2) // 2行，间距8
        
        return CGSize(width: width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 当布局改变时，重新计算collectionView的布局
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.invalidateLayout()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 当界面模式改变时，更新collectionView
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.reloadData()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assets.removeAll()
        collectionView.reloadData()
    }
}

/// 缩略图Cell
class ThumbnailCell: UICollectionViewCell {
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 设置Cell背景色，支持深色模式
        contentView.backgroundColor = .clear
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        // 设置四宫格背景色为稍微深一点的灰色，支持深色模式
        imageView.backgroundColor = UIColor {
            $0.userInterfaceStyle == .dark ? .systemGray4 : .systemGray3
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
