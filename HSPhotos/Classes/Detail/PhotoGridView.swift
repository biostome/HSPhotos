//
//  PhotoGridView.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos

/// 多选模式
enum PhotoSelectionMode {
    case none
    case multiple
    case range
}

// 定义排序逻辑的自定义错误
enum PhotoSortError: Error, LocalizedError {
    case notEnoughPhotosSelected
    case anchorPhotoMissing
    
    var errorDescription: String? {
        switch self {
        case .notEnoughPhotosSelected:
            return "至少需要选择两张照片才能进行排序。"
        case .anchorPhotoMissing:
            return "内部错误：无法在照片数组中找到作为排序基准的锚点照片。"
        }
    }
}

protocol PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath)
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath)
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset])
}

extension PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {}
}

class PhotoGridView: UIView {
    
    public var assets: [PHAsset] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    public var delegate: PhotoGridViewDelegate?
    
    public weak var scrollDelegate: UIScrollViewDelegate?
    
    public var selectedAssets: [PHAsset] { selectedPhotos }
    
    public var selectionMode: PhotoSelectionMode = .none {
        didSet {
            collectionView.allowsMultipleSelection = selectionMode == .multiple || selectionMode == .range
            collectionView.reloadData()
        }
    }
    
    /// 选中的开始位置
    public var selectedStart: Int?
    
    /// 选中的结束位置
    public var selectedEnd: Int?
    
    // 选中照片
    private var selectedPhotos: [PHAsset] = []
    
    // 本地ID -> 数组索引，用于快速查找选中照片在数组中的位置
    private var selectedMap: [String: Int] = [:]
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 80, right: 8)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
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
        backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.keyboardDismissMode = .onDrag
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    
    func toggle(photo: PHAsset) {
        if let index = selectedMap[photo.localIdentifier] {
            selectedPhotos.remove(at: index)
            selectedMap.removeValue(forKey: photo.localIdentifier)
            // 更新后续索引
            for i in index..<selectedPhotos.count {
                selectedMap[selectedPhotos[i].localIdentifier] = i
            }
        } else {
            selectedPhotos.append(photo)
            selectedMap[photo.localIdentifier] = selectedPhotos.count - 1
        }
    }
    
    /// 选择指定范围的照片（根据方向分配顺序）
    private func selectRange(from startIndex: Int, to endIndex: Int) {
        var indexPaths: [IndexPath] = []
        // 根据方向决定追加顺序
        let indices = startIndex <= endIndex ? Array(startIndex...endIndex) : Array(endIndex...startIndex).reversed()
        
        for index in indices {
            guard index < assets.count else { continue }
            let asset = assets[index]
            if selectedMap[asset.localIdentifier] == nil {
                toggle(photo: asset)
                indexPaths.append(IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didSelectItemAt: IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didSelectItemAt: asset)
            }
        }
        
        if !indexPaths.isEmpty {
            collectionView.performBatchUpdates {
                collectionView.reloadItems(at: indexPaths)
            } completion: { _ in
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
            }
        }
    }
    
    func index(of photo: PHAsset) -> Int? {
        return selectedMap[photo.localIdentifier].map { $0 + 1 }
    }
    
    func sort() throws -> [PHAsset] {
        guard selectedPhotos.count > 1 else {
            throw PhotoSortError.notEnoughPhotosSelected
        }
        
        let anchorPhoto = selectedPhotos.first!
        let photosToMove = Array(selectedPhotos.dropFirst())
        let identifiersToMove = Set(photosToMove.map { $0.localIdentifier })
        var temporaryAssets = self.assets.filter { !identifiersToMove.contains($0.localIdentifier) }
        
        guard let anchorIndex = temporaryAssets.firstIndex(of: anchorPhoto) else {
            throw PhotoSortError.anchorPhotoMissing
        }
        
        temporaryAssets.insert(contentsOf: photosToMove, at: anchorIndex + 1)
        return temporaryAssets
    }
    
    func clearSelected() {
        selectedPhotos.removeAll()
        selectedMap.removeAll()
        selectedStart = nil
        selectedEnd = nil
        delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    /// 定位到指定索引位置的照片
    /// - Parameter index: 照片在数组中的索引位置
    func scrollTo(index: Int) {
        guard index >= 0 && index < assets.count else { return }
        
        let indexPath = IndexPath(item: index, section: 0)
        
        // 先执行滚动动画
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        
        // 等待滚动动画完成后再执行高亮边框动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            if let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.performHighlightAnimation()
            }
        }
    }

    // MARK: - Asset Management
    
    /// 删除指定的资源项
    /// - Parameters:
    ///   - assetsToDelete: 要删除的资源数组
    ///   - completion: 删除完成回调
    func deleteAssets(assets assetsToDelete: [PHAsset], completion: @escaping (Bool) -> Void) {
        guard !assetsToDelete.isEmpty else {
            completion(true)
            return
        }
        
        // 使用 Set 提高查找效率
        let assetsToDeleteSet = Set(assetsToDelete.map { $0.localIdentifier })
        
        // 收集需要删除的 IndexPath
        let indexPathsToDelete = assets.enumerated().compactMap { index, asset in
            assetsToDeleteSet.contains(asset.localIdentifier) ? IndexPath(item: index, section: 0) : nil
        }
        
        // 执行删除动画 - 在 batch updates 内部更新数据源
        collectionView.performBatchUpdates {
            // 在这里更新数据源，确保与 UI 更新同步
            self.assets.removeAll { asset in
                assetsToDeleteSet.contains(asset.localIdentifier)
            }
            
            // 从选中列表中移除并更新索引
            for asset in assetsToDelete {
                if let selectedIndex = self.selectedMap[asset.localIdentifier] {
                    self.selectedPhotos.remove(at: selectedIndex)
                    self.selectedMap.removeValue(forKey: asset.localIdentifier)
                    // 更新后续索引
                    for i in selectedIndex..<self.selectedPhotos.count {
                        self.selectedMap[self.selectedPhotos[i].localIdentifier] = i
                    }
                }
            }
            
            // 删除 UI 中的项目
            self.collectionView.deleteItems(at: indexPathsToDelete)
        } completion: { finished in
            completion(finished)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension PhotoGridView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = assets[indexPath.item]
        let isSelected = selectedMap[photo.localIdentifier] != nil
        let selectionIndex = index(of: photo)
        cell.configure(with: photo, isSelected: isSelected, selectionIndex: selectionIndex, selectionMode: selectionMode, index: indexPath.item)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension PhotoGridView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < assets.count else { return }
        let photo = assets[indexPath.item]
        
        switch selectionMode {
        case .none:
            return
        case .multiple:
            handleMultipleSelection(at: indexPath, in: collectionView, with: photo)
        case .range:
            handleRangeSelection(at: indexPath, in: collectionView, with: photo)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard (selectionMode == .multiple || selectionMode == .range), indexPath.item < assets.count else { return }
        let photo = assets[indexPath.item]
        handleDeselection(at: indexPath, in: collectionView, with: photo)
    }
}

// MARK: - Helper Methods
extension PhotoGridView {
    private func handleMultipleSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        let wasSelected = selectedMap[photo.localIdentifier] != nil
        collectionView.performBatchUpdates {
            toggle(photo: photo)
            collectionView.reloadItems(at: [indexPath])
        } completion: { _ in
            if wasSelected {
                self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            } else {
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
            }
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
        }
    }
    
    private func handleRangeSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        let index = indexPath.item
        let isSelected = selectedMap[photo.localIdentifier] != nil
        
        if isSelected {
            // 如果点击已选中照片，反选它，并重设范围
            collectionView.performBatchUpdates {
                toggle(photo: photo)
                collectionView.reloadItems(at: [indexPath])
            } completion: { _ in
                self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                self.delegate?.photoGridView(self, didDeselectItemAt: photo)
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
            }
            selectedStart = nil
            selectedEnd = nil
            return
        }
        
        if selectedStart == nil {
            // 第一次点击：设置开始位置，选中单个
            selectedStart = index
            collectionView.performBatchUpdates {
                toggle(photo: photo)
                collectionView.reloadItems(at: [indexPath])
            } completion: { _ in
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
            }
        } else {
            // 第二次点击：设置结束位置，选中范围，重设范围
            selectedEnd = index
            selectRange(from: selectedStart!, to: index)
            selectedStart = nil
            selectedEnd = nil
        }
    }
    
    private func handleDeselection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        collectionView.performBatchUpdates {
            toggle(photo: photo)
            collectionView.reloadItems(at: [indexPath])
        } completion: { _ in
            self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
            self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
        }
        selectedStart = nil
        selectedEnd = nil
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PhotoGridView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 2
        let availableWidth = collectionView.bounds.width - 16 - spacing * 4
        let itemWidth = availableWidth / 5
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidScroll?(scrollView)
    }
}
