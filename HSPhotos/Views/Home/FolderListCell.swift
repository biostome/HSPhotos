//
//  FolderListCell.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/2.
//

import UIKit
import Photos

/// 文件夹列表布局Cell，类似于UITableViewCell的布局，左侧显示4宫格缩略图
class FolderListCell: BaseAlbumCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onDisclosureTap: (() -> Void)?
    
    private let collectionView: UICollectionView
    private let photoCountLabel = UILabel()
    private let disclosureImageView = UIImageView()
    private let disclosureButton = UIButton(type: .system)
    private var disclosureLeadingConstraint: NSLayoutConstraint?
    private var collectionViewLeadingConstraint: NSLayoutConstraint?
    private var titleLeadingConstraint: NSLayoutConstraint?
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
        setupTraitChangeObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // 左侧4宫格CollectionView
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false // 关闭用户交互
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        contentView.addSubview(collectionView)
        
        disclosureImageView.image = UIImage(systemName: "chevron.right")
        disclosureImageView.tintColor = .secondaryLabel
        disclosureImageView.contentMode = .scaleAspectFit
        disclosureImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(disclosureImageView)
        
        disclosureButton.translatesAutoresizingMaskIntoConstraints = false
        disclosureButton.backgroundColor = .clear
        disclosureButton.addTarget(self, action: #selector(handleDisclosureTap), for: .touchUpInside)
        contentView.addSubview(disclosureButton)
        
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
        disclosureLeadingConstraint = disclosureImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        collectionViewLeadingConstraint = collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: collectionView.trailingAnchor, constant: 12)
        
        NSLayoutConstraint.activate([
            disclosureLeadingConstraint!,
            disclosureImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 12),
            disclosureImageView.heightAnchor.constraint(equalToConstant: 12),
            disclosureButton.centerXAnchor.constraint(equalTo: disclosureImageView.centerXAnchor),
            disclosureButton.widthAnchor.constraint(equalToConstant: 64),
            disclosureButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            disclosureButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 左侧4宫格CollectionView
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            collectionViewLeadingConstraint!,
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            collectionView.widthAnchor.constraint(equalTo: collectionView.heightAnchor), // 正方形
            
            // 标题标签（图片右侧，顶部对齐）
            titleLabel.topAnchor.constraint(equalTo: collectionView.topAnchor),
            titleLeadingConstraint!,
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // 照片数量标签（标题下方）
            photoCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            photoCountLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            photoCountLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    // MARK: - Configure
    func configure(with item: AlbumListItem) {
        // 取消之前的图片请求
        cancelImageRequests()
        applyHierarchyAppearance(level: item.hierarchyLevel)
        
        // 设置文件夹标题和数量
        titleLabel.text = item.title
        photoCountLabel.text = "\(item.itemCount) 个相册"
        
        disclosureLeadingConstraint?.constant = 12
        collectionViewLeadingConstraint?.constant = 24
        titleLeadingConstraint?.constant = 12
        disclosureImageView.isHidden = !item.canExpand
        disclosureButton.isHidden = !item.canExpand
        disclosureImageView.transform = item.isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        
        // 加载文件夹缩略图
        loadFolderThumbnails(from: item)
    }
    
    private func loadFolderThumbnails(from item: AlbumListItem) {
        var assets: [PHAsset] = []
        
        // 检查是否为文件夹类型
        if item.isFolder, let collectionList = item.collectionList {
            // 获取文件夹内的所有子集合（包括相册和子文件夹）
            let fetchOptions = PHFetchOptions()
            
            let subCollections = PHCollection.fetchCollections(in: collectionList, options: fetchOptions)
            
            // 遍历子集合，只处理相册类型
            subCollections.enumerateObjects { (collection, _, _) in
                if let album = collection as? PHAssetCollection {
                    // 从相册中获取第一张图片
                    let albumAssets = PHAsset.fetchAssets(in: album, options: nil)
                    if let asset = albumAssets.firstObject {
                        assets.append(asset)
                        if assets.count >= 4 {
                            return
                        }
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
            // 优化：使用固定的缩略图尺寸
            let thumbnailSize = CGSize(width: 100, height: 100)
            
            // 检查缓存
            let cacheKey = "\(asset.localIdentifier)_\(thumbnailSize.width)_\(thumbnailSize.height)"
            if let cachedImage = ImageCache.shared.get(key: cacheKey) {
                cell.imageView.image = cachedImage
                cell.imageView.backgroundColor = .clear
                return cell
            }
            
            // 缓存未命中，加载图片
            let requestID = loadImage(for: asset, targetSize: thumbnailSize) { image in
                if let image = image {
                    cell.imageView.image = image
                    cell.imageView.backgroundColor = .clear
                }
            }
            // 保存请求ID，以便在需要时取消请求
            if let requestID = requestID {
                imageRequests.append(requestID)
            }
        } else {
            cell.imageView.image = nil
            // 设置四宫格背景色为稍微深一点的灰色，支持深色模式
            cell.imageView.backgroundColor = UIColor {
                $0.userInterfaceStyle == .dark ? .systemGray3 : .systemGray2
            }
        }
        
        return cell
    }
    
    // 缓存单元格尺寸
    private var cachedCellSize: CGSize?
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 优化：缓存单元格尺寸，避免每次都重新计算
        if let cachedSize = cachedCellSize {
            return cachedSize
        }
        
        // 计算单元格大小，确保四宫格大小相等
        // 宽度：(CollectionView宽度 - 间距) / 2
        let collectionViewWidth = collectionView.bounds.width
        let width = floor((collectionViewWidth - 8) / 2) // 2列，间距8
        
        // 高度：(CollectionView高度 - 间距) / 2
        let collectionViewHeight = collectionView.bounds.height
        let height = floor((collectionViewHeight - 8) / 2) // 2行，间距8
        
        let cellSize = CGSize(width: width, height: height)
        cachedCellSize = cellSize
        return cellSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 当布局改变时，清除缓存的尺寸并重新计算collectionView的布局
        cachedCellSize = nil
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.invalidateLayout()
        }
    }
    
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FolderListCell, previousTraitCollection: UITraitCollection) in
            // 当界面模式改变时，只更新需要更新的部分，避免全量重加载
            // 只更新背景色等UI元素，不需要重新加载图片
            self.collectionView.performBatchUpdates(nil, completion: nil)
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
        disclosureImageView.isHidden = false
        disclosureButton.isHidden = false
        disclosureImageView.transform = .identity
        onDisclosureTap = nil
        disclosureLeadingConstraint?.constant = 12
        collectionViewLeadingConstraint?.constant = 24
        titleLeadingConstraint?.constant = 12
        
        // 重置数据
        assets.removeAll()
        
        // 优化：只清除缓存的尺寸，不重新加载collectionView
        // 在下一次布局时会自动重新计算
        cachedCellSize = nil
    }
    
    @objc private func handleDisclosureTap() {
        onDisclosureTap?()
    }
}
