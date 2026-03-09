//
//  AlbumListView.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

protocol AlbumListViewDelegate {
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt indexPath: IndexPath)
    func albumListView(_ albumListView: AlbumListView, didTapFolderDisclosureAt indexPath: IndexPath)
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt collection: PHAssetCollection)
    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList)
    func albumListView(_ albumListView: AlbumListView, didTapAddPhotosFor item: AlbumListItem)
    func albumListView(_ albumListView: AlbumListView, didTapEditTitleFor item: AlbumListItem)
    func albumListView(_ albumListView: AlbumListView, didTapDeleteFor item: AlbumListItem)
}

/// 相册列表布局模式
enum AlbumListLayoutMode {
    case grid // 网格布局
    case list // 列表布局
}

class AlbumListView: UIView{
    
    public var delegate: AlbumListViewDelegate?
    
    public private(set) var collections: [AlbumListItem] = []
    
    /// 布局模式
    public var layoutMode: AlbumListLayoutMode = .grid {
        didSet {
            // 重新加载布局
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
        }
    }
    
    // 缓存 Cell 尺寸，避免重复计算
    private var cachedGridCellSize: CGSize?
    private var cachedListCellSize: CGSize?
    private var lastCollectionViewWidth: CGFloat = 0
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear // 设置为透明，显示渐变背景
        collectionView.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        collectionView.register(FolderCell.self, forCellWithReuseIdentifier: "FolderCell")
        collectionView.register(AlbumListCell.self, forCellWithReuseIdentifier: "AlbumListCell")
        collectionView.register(FolderListCell.self, forCellWithReuseIdentifier: "FolderListCell")
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear // 设置为透明，显示渐变背景
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self // 启用预加载
        collectionView.isPrefetchingEnabled = true // 启用预加载
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // 高级性能优化设置
        collectionView.preservesSuperviewLayoutMargins = false
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.layoutMargins = UIEdgeInsets.zero
        
        // 启用预渲染和离屏渲染优化
        // 移除了 preferredFocusEnvironments 的设置，因为它是不可变的
        
        // 优化滚动性能
        collectionView.decelerationRate = .fast
        collectionView.alwaysBounceVertical = true
        
        // 优化布局性能
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            // 不使用自动尺寸估计，使用我们在 sizeForItemAt 中计算的固定尺寸
            flowLayout.estimatedItemSize = .zero
            flowLayout.invalidateLayout()
        }
        
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    /// 滚动到指定的相册位置
    public func scrollToItem(at indexPath: IndexPath, at scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
        collectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: animated)
    }
    
    public func setCollections(_ newCollections: [AlbumListItem], animated: Bool) {
        // 优化：快速路径，当数据相同时直接返回
        if collections.count == newCollections.count {
            var hasChanges = false
            for (old, new) in zip(collections, newCollections) {
                if old.localIdentifier != new.localIdentifier || 
                   old.isExpanded != new.isExpanded || 
                   old.canExpand != new.canExpand || 
                   old.hierarchyLevel != new.hierarchyLevel {
                    hasChanges = true
                    break
                }
            }
            if !hasChanges {
                return
            }
        }
        
        // 异步处理数据计算，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 计算变更
            let oldCollections = self.collections
            let oldKeys = oldCollections.map { self.itemKey(for: $0) }
            let newKeys = newCollections.map { self.itemKey(for: $0) }
            let oldKeySet = Set(oldKeys)
            let newKeySet = Set(newKeys)
            
            let oldItemByKey = Dictionary(uniqueKeysWithValues: zip(oldKeys, oldCollections))
            let deletedIndexPaths = oldKeys.enumerated().compactMap { entry -> IndexPath? in
                newKeySet.contains(entry.element) ? nil : IndexPath(item: entry.offset, section: 0)
            }
            let insertedIndexPaths = newKeys.enumerated().compactMap { entry -> IndexPath? in
                oldKeySet.contains(entry.element) ? nil : IndexPath(item: entry.offset, section: 0)
            }
            let reloadedIndexPaths = newCollections.enumerated().compactMap { entry -> IndexPath? in
                let item = entry.element
                let key = self.itemKey(for: item)
                guard let oldItem = oldItemByKey[key] else { return nil }
                let needsReload = oldItem.isExpanded != item.isExpanded
                    || oldItem.canExpand != item.canExpand
                    || oldItem.hierarchyLevel != item.hierarchyLevel
                return needsReload ? IndexPath(item: entry.offset, section: 0) : nil
            }
            
            // 更新主线程
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if !animated || self.window == nil || newCollections.count > 100 {
                    // 优化：当数据量较大时，使用reloadData以获得更好的性能
                    self.collections = newCollections
                    self.collectionView.reloadData()
                    return
                }
                
                self.collections = newCollections
                
                if deletedIndexPaths.isEmpty && insertedIndexPaths.isEmpty && reloadedIndexPaths.isEmpty {
                    return
                }

                let hasStructuralChanges = !deletedIndexPaths.isEmpty || !insertedIndexPaths.isEmpty
                if hasStructuralChanges {
                    // 优化：使用weak self避免循环引用
                    self.collectionView.performBatchUpdates({ [weak self] in
                        guard let self = self else { return }
                        if !deletedIndexPaths.isEmpty {
                            self.collectionView.deleteItems(at: deletedIndexPaths)
                        }
                        if !insertedIndexPaths.isEmpty {
                            self.collectionView.insertItems(at: insertedIndexPaths)
                        }
                    }, completion: { [weak self] _ in
                        // 优化：只在必要时重新加载
                        guard let self = self else { return }
                        if !reloadedIndexPaths.isEmpty {
                            self.collectionView.reloadItems(at: reloadedIndexPaths)
                        }
                    })
                    return
                }

                if !reloadedIndexPaths.isEmpty {
                    self.collectionView.performBatchUpdates({ [weak self] in
                        guard let self = self else { return }
                        self.collectionView.reloadItems(at: reloadedIndexPaths)
                    })
                }
            }
        }
    }
    
    private func itemKey(for item: AlbumListItem) -> String {
        let typePrefix = item.isFolder ? "folder" : "album"
        return "\(typePrefix)-\(item.localIdentifier)-\(item.hierarchyLevel)"
    }
}

// MARK: - UICollectionViewDataSource
extension AlbumListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collections[indexPath.item]
        
        if item.isFolder {
            switch layoutMode {
            case .grid:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FolderCell", for: indexPath) as! FolderCell
                cell.configure(with: item)
                return cell
            case .list:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FolderListCell", for: indexPath) as! FolderListCell
                cell.configure(with: item)
                cell.onDisclosureTap = { [weak self, weak collectionView, weak cell] in
                    guard
                        let self = self,
                        let collectionView = collectionView,
                        let cell = cell,
                        let currentIndexPath = collectionView.indexPath(for: cell)
                    else {
                        return
                    }
                    self.delegate?.albumListView(self, didTapFolderDisclosureAt: currentIndexPath)
                }
                return cell
            }
        } else {
            switch layoutMode {
            case .grid:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
                cell.configure(with: item)
                return cell
            case .list:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumListCell", for: indexPath) as! AlbumListCell
                cell.configure(with: item)
                return cell
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension AlbumListView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 检查 CollectionView 宽度是否变化
        if collectionView.bounds.width != lastCollectionViewWidth {
            // 宽度变化，清除缓存
            cachedGridCellSize = nil
            cachedListCellSize = nil
            lastCollectionViewWidth = collectionView.bounds.width
        }
        
        // 根据布局模式返回不同的大小
        switch layoutMode {
        case .grid:
            // 网格布局：正方形
            if let cachedSize = cachedGridCellSize {
                return cachedSize
            }
            
            guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
                return CGSize(width: 100, height: 100)
            }
            
            let sectionInset = flowLayout.sectionInset
            let interitemSpacing = flowLayout.minimumInteritemSpacing
            let totalWidth = collectionView.bounds.width
            let availableWidth = totalWidth - sectionInset.left - sectionInset.right - interitemSpacing
            let cellWidth = availableWidth / 2
            let cellHeight = cellWidth // 正方形
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            
            // 缓存结果
            cachedGridCellSize = cellSize
            return cellSize
            
        case .list:
            // 列表布局：固定高度的矩形
            if let cachedSize = cachedListCellSize {
                return cachedSize
            }
            
            guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
                return CGSize(width: 300, height: 100)
            }
            
            let sectionInset = flowLayout.sectionInset
            let totalWidth = collectionView.bounds.width
            let cellWidth = totalWidth - sectionInset.left - sectionInset.right
            let cellHeight: CGFloat = 100 // 固定高度
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            
            // 缓存结果
            cachedListCellSize = cellSize
            return cellSize
        }
    }
}

// MARK: - UICollectionViewDelegate
extension AlbumListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = self.collections[indexPath.item]
        self.delegate?.albumListView(self, didSelectItemAt: indexPath)
        
        // 根据类型调用不同的代理方法
        switch item.type {
        case .album(let collection):
            self.delegate?.albumListView(self, didSelectItemAt: collection)
        case .folder(let collectionList):
            self.delegate?.albumListView(self, didSelectFolder: collectionList)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let item = self.collections[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addPhotosAction = UIAction(title: "添加照片", image: UIImage(systemName: "plus.rectangle.on.folder")) { _ in
                self.delegate?.albumListView(self, didTapAddPhotosFor: item)
            }
            let editAction = UIAction(title: "编辑标题", image: UIImage(systemName: "pencil")) { _ in
                self.delegate?.albumListView(self, didTapEditTitleFor: item)
            }
            
            let deleteActionTitle = item.isFolder ? "删除文件夹" : "删除相册"
            let deleteAction = UIAction(title: deleteActionTitle, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.delegate?.albumListView(self, didTapDeleteFor: item)
            }
            
            var actions: [UIAction] = []
            if item.isAlbum {
                actions.append(addPhotosAction)
            }
            actions.append(editAction)
            actions.append(deleteAction)
            
            return UIMenu(title: "", children: actions)
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching
extension AlbumListView: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // 预加载即将显示的Cell数据
        for indexPath in indexPaths {
            if indexPath.item < collections.count {
                let item = collections[indexPath.item]
                // 预加载封面图
                if item.isAlbum, let coverAsset = item.coverAsset {
                    // 根据布局模式选择合适的预加载尺寸
                    let targetSize: CGSize
                    switch layoutMode {
                    case .grid:
                        targetSize = CGSize(width: 300, height: 300) // 网格布局使用稍大尺寸
                    case .list:
                        targetSize = CGSize(width: 160, height: 160) // 列表布局使用较小尺寸
                    }
                    
                    // 检查缓存
                    let cacheKey = "\(coverAsset.localIdentifier)_\(targetSize.width)_\(targetSize.height)"
                    if ImageCache.shared.get(key: cacheKey) == nil {
                        // 缓存未命中，触发预加载
                        loadImageForPrefetch(asset: coverAsset, targetSize: targetSize, cacheKey: cacheKey)
                    }
                } else if item.isFolder, let collectionList = item.collectionList {
                    // 预加载文件夹的缩略图
                    prefetchFolderThumbnails(for: collectionList)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // 取消预加载，这里可以添加取消逻辑
    }
    
    /// 为预加载加载图片
    private func loadImageForPrefetch(asset: PHAsset, targetSize: CGSize, cacheKey: String) {
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // 检查是否是最终图片
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if !isDegraded, let image = image {
                // 缓存图片
                ImageCache.shared.set(key: cacheKey, image: image)
            }
        }
    }
    
    /// 预加载文件夹的缩略图
    private func prefetchFolderThumbnails(for collectionList: PHCollectionList) {
        var assets: [PHAsset] = []
        
        // 获取文件夹内的所有子集合（包括相册和子文件夹）
        let fetchOptions = PHFetchOptions()
        let subCollections = PHCollection.fetchCollections(in: collectionList, options: fetchOptions)
        
        // 遍历子集合，只处理相册类型
        subCollections.enumerateObjects { (collection, _, stop) in
            if let album = collection as? PHAssetCollection {
                // 从相册中获取第一张图片
                let albumAssets = PHAsset.fetchAssets(in: album, options: nil)
                if let asset = albumAssets.firstObject {
                    assets.append(asset)
                    if assets.count >= 4 {
                        stop.pointee = true
                    }
                }
            }
        }
        
        // 预加载文件夹缩略图
        for asset in assets {
            let targetSize = CGSize(width: 100, height: 100)
            let cacheKey = "\(asset.localIdentifier)_\(targetSize.width)_\(targetSize.height)"
            if ImageCache.shared.get(key: cacheKey) == nil {
                loadImageForPrefetch(asset: asset, targetSize: targetSize, cacheKey: cacheKey)
            }
        }
    }
}
