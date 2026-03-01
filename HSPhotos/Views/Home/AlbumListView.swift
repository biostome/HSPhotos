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
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt collection: PHAssetCollection)
    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList)
}

class AlbumListView: UIView{
    
    public var delegate: AlbumListViewDelegate?
    
    public var collections: [AlbumListItem] = [] {
        didSet{
            self.collectionView.reloadData()
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
}

// MARK: - UICollectionViewDataSource
extension AlbumListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collections[indexPath.item]
        
        if item.isFolder {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FolderCell", for: indexPath) as! FolderCell
            cell.configure(with: item)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
            cell.configure(with: item)
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension AlbumListView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 确保总是显示2列，计算宽度时考虑sectionInset和interitemSpacing
        let totalWidth = collectionView.frame.width
        let sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let interitemSpacing: CGFloat = 12
        let availableWidth = totalWidth - sectionInset.left - sectionInset.right - interitemSpacing
        let cellWidth = availableWidth / 2
        let cellHeight = cellWidth // 正方形
        return CGSize(width: cellWidth, height: cellHeight)
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
}
