//
//  PhotoGridView.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//



import UIKit
import Photos

// Define custom errors for the sorting logic
enum PhotoSortError: Error, LocalizedError {
    case notEnoughPhotosSelected
    case anchorPhotoMissing
    
    // Provide user-friendly descriptions for each error
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
    func photoGridView(_ photoGridView: PhotoGridView, didSelctedItems assets: [PHAsset])
}
extension PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath){}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset){}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath){}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset){}
    func photoGridView(_ photoGridView: PhotoGridView, didSelctedItems assets: [PHAsset]){}
}

class PhotoGridView: UIView {
    
    public var assets: [PHAsset] = [] {
        didSet{
            self.collectionView.reloadData()
        }
    }
    
    public var delegate: PhotoGridViewDelegate?
    
    public var selectedAssets: [PHAsset] { selectedPhotos }
    
    public var isSelectionMode = false {
        didSet{
            self.collectionView.reloadData()
        }
    }
    
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
    
    func index(of photo: PHAsset) -> Int? {
        return selectedMap[photo.localIdentifier].map { $0 + 1 }
    }
    
    // 以第一张选中的照片为锚点，将其他选中的照片按照选中顺序插入到第一张照片的后面
    // This function now throws an error if sorting is not possible.
    func sort() throws -> [PHAsset] {
        // 1. 确保至少有两张选中的照片才能进行排序
        guard selectedPhotos.count > 1 else {
            throw PhotoSortError.notEnoughPhotosSelected
        }
        
        // 2. 获取作为锚点的第一张照片，以及其他需要移动的照片
        // Because of the guard above, .first will never be nil, so we can safely unwrap.
        let anchorPhoto = selectedPhotos.first!
        let photosToMove = Array(selectedPhotos.dropFirst())
        
        // 3. 创建一个包含待移动照片ID的Set，以便高效过滤
        let identifiersToMove = Set(photosToMove.map { $0.localIdentifier })
        
        // 4. 从当前照片数组中移除所有待移动的照片，得到一个临时数组
        var temporaryAssets = self.assets.filter { !identifiersToMove.contains($0.localIdentifier) }
        
        // 5. 在临时数组中找到锚点照片的新位置
        guard let anchorIndex = temporaryAssets.firstIndex(of: anchorPhoto) else {
            // 如果锚点照片不在数组中（理论上不应发生），则抛出异常
            throw PhotoSortError.anchorPhotoMissing
        }
        
        // 6. 将待移动的照片集体插入到锚点照片的后面
        temporaryAssets.insert(contentsOf: photosToMove, at: anchorIndex + 1)
        
        // 7. 成功后返回排序好的新数组
        return temporaryAssets
    }

    // 获取
    
    func clearSelected(){
        selectedPhotos.removeAll()
        selectedMap.removeAll()
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
        let selectionIndex = index(of: photo) // 返回序号，从1开始
        cell.configure(with: photo, isSelected: isSelected, selectionIndex: selectionIndex, isSelectionMode: isSelectionMode)
        return cell
    }

}

extension PhotoGridView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            let photo = assets[indexPath.item]
            
            collectionView.performBatchUpdates {                
                toggle(photo: photo)
                collectionView.reloadItems(at: [indexPath])
            } completion: { completion in
                collectionView.reloadData()
            }

            self.delegate?.photoGridView(self, didSelctedItems: self.selectedPhotos)
            self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
        } 
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PhotoGridView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 2
        let availableWidth = collectionView.bounds.width - 16 - spacing * 4 // 减去左右边距和3个间距
        let itemWidth = availableWidth / 5
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
}


