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
        collectionView.translatesAutoresizingMaskIntoConstraints = false
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
        if !animated || window == nil {
            collections = newCollections
            collectionView.reloadData()
            return
        }
        
        let oldCollections = collections
        let oldKeys = oldCollections.map { itemKey(for: $0) }
        let newKeys = newCollections.map { itemKey(for: $0) }
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
            let key = itemKey(for: item)
            guard let oldItem = oldItemByKey[key] else { return nil }
            let needsReload = oldItem.isExpanded != item.isExpanded
                || oldItem.canExpand != item.canExpand
                || oldItem.hierarchyLevel != item.hierarchyLevel
            return needsReload ? IndexPath(item: entry.offset, section: 0) : nil
        }
        
        collections = newCollections
        
        if deletedIndexPaths.isEmpty && insertedIndexPaths.isEmpty && reloadedIndexPaths.isEmpty {
            return
        }
        
        collectionView.performBatchUpdates({
            if !deletedIndexPaths.isEmpty {
                collectionView.deleteItems(at: deletedIndexPaths)
            }
            if !insertedIndexPaths.isEmpty {
                collectionView.insertItems(at: insertedIndexPaths)
            }
            if !reloadedIndexPaths.isEmpty {
                collectionView.reloadItems(at: reloadedIndexPaths)
            }
        })
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
        // 根据布局模式返回不同的大小
        switch layoutMode {
        case .grid:
            // 网格布局：正方形
            let totalWidth = collectionView.frame.width
            let sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            let interitemSpacing: CGFloat = 12
            let availableWidth = totalWidth - sectionInset.left - sectionInset.right - interitemSpacing
            let cellWidth = availableWidth / 2
            let cellHeight = cellWidth // 正方形
            return CGSize(width: cellWidth, height: cellHeight)
        case .list:
            // 列表布局：固定高度的矩形
            let totalWidth = collectionView.frame.width
            let sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            let cellWidth = totalWidth - sectionInset.left - sectionInset.right
            let cellHeight: CGFloat = 100 // 固定高度
            return CGSize(width: cellWidth, height: cellHeight)
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
            let editAction = UIAction(title: "编辑标题", image: UIImage(systemName: "pencil")) { _ in
                self.delegate?.albumListView(self, didTapEditTitleFor: item)
            }
            
            let deleteActionTitle = item.isFolder ? "删除文件夹" : "删除相册"
            let deleteAction = UIAction(title: deleteActionTitle, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.delegate?.albumListView(self, didTapDeleteFor: item)
            }
            
            return UIMenu(title: "", children: [editAction, deleteAction])
        }
    }
}
