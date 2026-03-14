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
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didRequestSetHierarchyLevelFor asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didRequestSetTopLevelFor asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset)
}

extension PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didRequestSetHierarchyLevelFor asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didRequestSetTopLevelFor asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset) {}
}


// MARK: - Constants
struct PhotoGridConstants {
    static let allowedColumns = [1, 3, 5, 7, 11]
    static let defaultColumns = 3
    static let defaultSpacing: CGFloat = 2
    static let compactSpacing: CGFloat = 0
    static let sectionInset: CGFloat = 2
    static let zoomThreshold: (enlarge: CGFloat, shrink: CGFloat) = (1.3, 0.7)
}


class PhotoGridView: UIView {
    
    public var assets: [PHAsset] = [] {
        didSet {
            // 应用层级折叠过滤
            updateVisibleAssets()
        }
    }
    
    // 实际显示的照片（经过层级折叠过滤）
    private var visibleAssets: [PHAsset] = []
    
    public var delegate: PhotoGridViewDelegate?
    
    public weak var scrollDelegate: UIScrollViewDelegate?
    
    public var selectedAssets: [PHAsset] { selectedPhotos }
    
    // 获取所有资产（包括隐藏的）
    public var allAssets: [PHAsset] { assets }
    
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
    
    // 新增：用于跟踪滑动手势选中的状态
    internal var isSlidingSelectionEnabled = false
    internal var lastSelectedIndexPath: IndexPath?
    
    // 新增：用于临时禁用滚动
    internal var isScrollDisabled = false
    
    // 新增：用于跟踪手势方向
    internal var initialTouchPoint: CGPoint = .zero
    internal var hasStartedSelection = false
    internal let selectionThreshold: CGFloat = 10.0 // 开始选中的阈值
    
    // 滑动选择相关
    internal var panStartIndexPath: IndexPath?
    internal var panLastIndexPath: IndexPath?
    
    // 记录滑动开始位置的选择状态
    internal var panInitialSelectionState: Bool = false
    
    // 选中照片（根据选中顺序排序的派生数组）
    private var selectedPhotos: [PHAsset] {
        return selectedMap.values.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    
    // 照片ID -> (选中序号(从1开始且连续), 资产)
    private var selectedMap: [String: (Int, PHAsset)] = [:]
    
    // 当前锚点照片
    private var anchorPhoto: PHAsset?
    
    // 当前层级参照照片（用于“设为某项子级/插入到某级后面”）
    public private(set) var hierarchyReferenceAsset: PHAsset?
    
    // 当前排序方式
    public var sortPreference: PhotoSortPreference = .custom
    
    // 当前相册引用，用于获取自定义排序数据
    public var currentCollection: PHAssetCollection? {
        didSet {
            hierarchyCache.removeAll()
            customOrderIndexCache.removeAll()
        }
    }
    
    private let hierarchyService = PhotoHierarchyService.shared
    
    // 层级信息缓存，避免重复计算
    private var hierarchyCache: [String: (text: String?, isCollapsed: Bool)] = [:]
    
    // 自定义排序索引缓存：assetID -> index，O(1) 查找
    private var customOrderIndexCache: [String: Int] = [:]
    
    private var columns: Int = PhotoGridConstants.defaultColumns
    
    /// 获取指定资产的cell frame
    public func getCellFrame(for asset: PHAsset) -> CGRect? {
        if let index = visibleAssets.firstIndex(of: asset) {
            let indexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) {
                return collectionView.convert(cell.frame, to: self)
            }
        }
        return nil
    }
    
    
    private var lastScale: CGFloat = 3.0
    
    // 缓存 Cell 尺寸，避免重复计算
    private var cachedCellSize: CGSize?
    private var lastCollectionViewWidth: CGFloat = 0
    
    private lazy var collectionView: UICollectionView = {
        let initialLayout = createLayout(for: columns)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: initialLayout)
        collectionView.backgroundColor = .clear
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // 性能优化设置
        collectionView.preservesSuperviewLayoutMargins = false
        collectionView.layoutMargins = .zero
        collectionView.decelerationRate = .normal
        
        return collectionView
    }()
    
    lazy var verticalScrollIndicator: CustomVerticalScrollIndicator = {
        let view = CustomVerticalScrollIndicator()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.0 // 初始隐藏
        view.backgroundColor = .clear
        view.delegate = self
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
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
        
        addSubview(verticalScrollIndicator)
        
        NSLayoutConstraint.activate([
            verticalScrollIndicator.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            verticalScrollIndicator.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalScrollIndicator.widthAnchor.constraint(equalToConstant: 30),
            verticalScrollIndicator.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
        
    }
    
    
    private func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)
        
        // 添加滑动手势识别器
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        collectionView.addGestureRecognizer(panGesture)
    }
    
    private func calculateNewColumns(for scaleDelta: CGFloat) -> Int {
        guard let currentIndex = PhotoGridConstants.allowedColumns.firstIndex(of: columns) else {
            return columns
        }
        
        if scaleDelta > PhotoGridConstants.zoomThreshold.enlarge {
            // 放大时减少列数
            return currentIndex > 0 ? PhotoGridConstants.allowedColumns[currentIndex - 1] : columns
        } else if scaleDelta < PhotoGridConstants.zoomThreshold.shrink {
            // 缩小时增加列数
            return currentIndex < PhotoGridConstants.allowedColumns.count - 1
                ? PhotoGridConstants.allowedColumns[currentIndex + 1]
                : columns
        }
        
        return columns
    }
    
    private func updateColumns(to newColumns: Int) {
        columns = newColumns
        cachedCellSize = nil
        lastCollectionViewWidth = 0
        let newLayout = createLayout(for: columns)
        collectionView.setCollectionViewLayout(newLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.collectionView.reloadData()
        }
    }
    
    // MARK: - Gesture Handling
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            lastScale = gesture.scale
            
        case .changed:
            let scaleDelta = gesture.scale / lastScale
            let newColumns = calculateNewColumns(for: scaleDelta)
            
            if newColumns != columns {
                updateColumns(to: newColumns)
                lastScale = gesture.scale
            }
            
        default:
            break
        }
    }
    
    // 新增：处理滑动手势
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        // 只在多选模式或范围选择模式下启用滑动选择
        guard selectionMode == .multiple || selectionMode == .range else { return }
        
        let point = gesture.location(in: collectionView)
        
        switch gesture.state {
        case .began:
            // 记录滑动开始的indexPath和初始选择状态
            if let indexPath = collectionView.indexPathForItem(at: point) {
                panStartIndexPath = indexPath
                panLastIndexPath = indexPath
                
                // 记录起始位置的初始选择状态
                if let asset = getAsset(at: indexPath) {
                    panInitialSelectionState = selectedMap[asset.localIdentifier] != nil
                    
                    // 切换起始位置的选择状态
                    _ = toggle(photo: asset)
                    
                    // 刷新UI
                    collectionView.reloadItems(at: [indexPath])
                    // 通知代理
                    delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
                }
            }
        case .changed:
            // 处理滑动中的选择
            if let startIndexPath = panStartIndexPath, let currentIndexPath = collectionView.indexPathForItem(at: point) {
                // 只在indexPath变化时处理
                guard currentIndexPath != panLastIndexPath else { return }
                
                // 获取当前所有的asset ids，按照collectionView的顺序
                let allAssetIds = assets.map { $0.localIdentifier }
                
                // 获取当前位置的asset和index
                guard let currentAsset = getAsset(at: currentIndexPath),
                      let currentIndex = allAssetIds.firstIndex(of: currentAsset.localIdentifier) else { return }
                
                // 获取起始位置的asset和index
                guard let startAsset = getAsset(at: startIndexPath),
                      let startIndex = allAssetIds.firstIndex(of: startAsset.localIdentifier) else { return }
                
                // 获取上一个位置的asset和index
                guard let lastIndexPath = panLastIndexPath,
                      let lastAsset = getAsset(at: lastIndexPath),
                      let lastIndex = allAssetIds.firstIndex(of: lastAsset.localIdentifier) else {
                    // 如果没有上一个位置，只处理当前位置
                    let asset = getAsset(at: currentIndexPath)
                    if let asset = asset {
                        let targetSelectionState = !panInitialSelectionState
                        let isCurrentlySelected = selectedMap[asset.localIdentifier] != nil
                        
                        if isCurrentlySelected != targetSelectionState {
                            _ = toggle(photo: asset)
                        }
                    }
                    
                    panLastIndexPath = currentIndexPath
                    collectionView.reloadItems(at: [currentIndexPath])
                    // 通知代理
                    delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
                    return
                }
                
                // 计算目标选择状态：基于起始位置的初始状态，滑动选择的照片应该是统一的选择或取消
                let targetSelectionState = !panInitialSelectionState
                
                // 计算当前滑动的范围（只处理变化的部分）
                let rangeStart = min(lastIndex, currentIndex)
                let rangeEnd = max(lastIndex, currentIndex)
                
                // 遍历范围内的所有asset，设置为目标选择状态
                var indexPathsToUpdate: [IndexPath] = []
                for i in rangeStart...rangeEnd {
                    if i < assets.count {
                        let asset = assets[i]
                        let isCurrentlySelected = selectedMap[asset.localIdentifier] != nil
                        
                        // 计算该位置应该有的选择状态
                        // 基于起始位置到当前位置的完整范围
                        let fullRangeStart = min(startIndex, currentIndex)
                        let fullRangeEnd = max(startIndex, currentIndex)
                        let isInFullRange = i >= fullRangeStart && i <= fullRangeEnd
                        
                        // 如果在完整范围内，设置为目标状态；否则设置为初始状态
                        let expectedState = isInFullRange ? targetSelectionState : panInitialSelectionState
                        
                        if isCurrentlySelected != expectedState {
                            _ = toggle(photo: asset)
                            // 添加到更新列表
                            let itemIndex = i
                            let sectionIndex = 0 // 假设所有照片都在一个section中
                            let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                            indexPathsToUpdate.append(indexPath)
                        }
                    }
                }
                
                // 更新最后处理的indexPath
                panLastIndexPath = currentIndexPath
                
                // 刷新所有受影响的单元格
                if !indexPathsToUpdate.isEmpty {
                    collectionView.reloadItems(at: indexPathsToUpdate)
                }
                
                // 通知代理
                delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
            }
        case .ended, .cancelled, .failed:
            // 清理状态
            panStartIndexPath = nil
            panLastIndexPath = nil
            gesture.setTranslation(.zero, in: collectionView) // 重置手势位移
        default:
            break
        }
    }
    

    

    
    // MARK: - Layout Methods
    private func createLayout(for columns: Int) -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        
        // 根据列数动态调整间距
        let spacing = columns > 5 ? PhotoGridConstants.compactSpacing : PhotoGridConstants.defaultSpacing
        let sectionInset = columns > 5 ? PhotoGridConstants.compactSpacing : PhotoGridConstants.sectionInset
        
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(
            top: sectionInset,
            left: sectionInset,
            bottom: sectionInset,
            right: sectionInset
        )
        
        let totalSpacing = sectionInset * 2 + (CGFloat(columns - 1) * spacing)
        let itemWidth = max(1, (bounds.width - totalSpacing) / CGFloat(columns))
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        
        return layout
    }
    
    // 新增：根据索引路径获取资源
    private func getAsset(at indexPath: IndexPath) -> PHAsset? {
        guard indexPath.item < assets.count else { return nil }
        return assets[indexPath.item]
    }
    
    internal func toggle(photo: PHAsset) -> [PHAsset] {
        var updatedPhotos: [PHAsset] = []
        
        if let (removedRank, _) = selectedMap[photo.localIdentifier] {
            // 取消选择：移除照片
            selectedMap.removeValue(forKey: photo.localIdentifier)
            // 如果删除的是锚点照片，清除锚点
            if anchorPhoto?.localIdentifier == photo.localIdentifier {
                anchorPhoto = nil
            }
            
            // 只调整比被取消序号大的项的序号，而不是重新分配所有序号
            for (assetId, (currentRank, asset)) in selectedMap {
                if currentRank > removedRank {
                    selectedMap[assetId] = (currentRank - 1, asset)
                    // 记录需要更新的照片
                    updatedPhotos.append(asset)
                }
            }
        } else {
            // 新选：序号为当前数量+1
            let newRank = selectedMap.count + 1
            selectedMap[photo.localIdentifier] = (newRank, photo)
        }
        
        return updatedPhotos
    }
    
    /// 重新分配所有选中照片的序号，确保连续且与选择顺序对应
    private func reassignRanks() {
        // 获取当前选中的照片，按照选择顺序排序
        let sortedPhotos = selectedMap.values.sorted { $0.0 < $1.0 }.map { $0.1 }
        // 清空当前的序号映射
        selectedMap.removeAll()
        // 重新分配序号，从1开始连续递增
        for (index, photo) in sortedPhotos.enumerated() {
            selectedMap[photo.localIdentifier] = (index + 1, photo)
        }
    }
    
    /// 选择指定范围的照片（根据方向分配顺序）
    private func selectRange(from startIndex: Int, to endIndex: Int, reverse: Bool) {
        var indexPaths: [IndexPath] = []
        // 归一化范围并根据方向决定追加顺序
        let low = min(startIndex, endIndex)
        let high = max(startIndex, endIndex)
        let baseRange = low...high
        let indices: [Int] = reverse ? Array(baseRange.reversed()) : Array(baseRange)
        var nextRank = selectedMap.count + 1
        
        for index in indices {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            if selectedMap[asset.localIdentifier] == nil {
                selectedMap[asset.localIdentifier] = (nextRank, asset)
                nextRank += 1
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
    
    /// 取消选择指定范围的照片（根据方向分配顺序）
    private func deselectRange(from startIndex: Int, to endIndex: Int) {
        var indexPaths: [IndexPath] = []
        var updatedPhotos: [PHAsset] = []
        // 根据方向决定追加顺序
        let indices = startIndex <= endIndex ? Array(startIndex...endIndex) : Array(endIndex...startIndex).reversed()
        
        for index in indices {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            if selectedMap[asset.localIdentifier] != nil {
                let assetsToUpdate = toggle(photo: asset)
                updatedPhotos.append(contentsOf: assetsToUpdate)
                indexPaths.append(IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: asset)
            }
        }
        
        if !indexPaths.isEmpty {
            collectionView.performBatchUpdates {
                collectionView.reloadItems(at: indexPaths)
                
                // 只重新加载序号发生变化的照片的单元格，提高性能
                var updatedIndexPaths: [IndexPath] = []
                for (index, asset) in visibleAssets.enumerated() {
                    if updatedPhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        updatedIndexPaths.append(IndexPath(item: index, section: 0))
                    }
                }
                if !updatedIndexPaths.isEmpty {
                    collectionView.reloadItems(at: updatedIndexPaths)
                }
            } completion: { _ in
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
            }
        }
    }
    
    // 已不需要按次序计算排名，直接从 selectedMap 中读取
    
    /// O(1) 查找照片在自定义排序中的下标
    private func getCustomOrderIndex(for photo: PHAsset) -> Int {
        return customOrderIndexCache[photo.localIdentifier] ?? -1
    }
    
    func sort() throws -> [PHAsset] {
        guard selectedPhotos.count > 1 else {
            throw PhotoSortError.notEnoughPhotosSelected
        }
        
        // 确定排序基准照片：优先使用锚点，如果没有锚点则使用第一张选中的照片
        let currentAnchorPhoto: PHAsset
        if let anchorPhoto = anchorPhoto {
            // 锚点照片即使没有被选中也可以作为排序基准
            currentAnchorPhoto = anchorPhoto
        } else {
            // 没有锚点时，使用第一张选中的照片作为基准
            currentAnchorPhoto = selectedPhotos.first!
        }
        
        // 获取要移动的照片（除了基准照片之外的所有选中照片）
        let photosToMove = selectedPhotos.filter { $0.localIdentifier != currentAnchorPhoto.localIdentifier }
        let identifiersToMove = Set(photosToMove.map { $0.localIdentifier })
        var temporaryAssets = self.assets.filter { !identifiersToMove.contains($0.localIdentifier) }
        
        guard let anchorIndex = temporaryAssets.firstIndex(of: currentAnchorPhoto) else {
            throw PhotoSortError.anchorPhotoMissing
        }
        
        // 按选中顺序插入照片（基准照片始终在首位，其余按选中顺序跟随）
        temporaryAssets.insert(contentsOf: photosToMove, at: anchorIndex + 1)
        return temporaryAssets
    }
    
    func clearSelected() {
        selectedMap.removeAll()
        selectedStart = nil
        selectedEnd = nil
        anchorPhoto = nil  // 清除锚点
        // 清空后序号从1开始（由 selectedMap.count + 1 决定），无需重置计数器
        delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
        collectionView.reloadData()
    }
    
    /// 全选所有可见照片
    func selectAll() {
        // 清除现有选中状态
        selectedMap.removeAll()
        selectedStart = nil
        selectedEnd = nil
        anchorPhoto = nil
        
        // 选中所有可见照片
        for (index, asset) in visibleAssets.enumerated() {
            selectedMap[asset.localIdentifier] = (index + 1, asset)
        }
        
        // 通知代理
        delegate?.photoGridView(self, didSelectedItems: selectedPhotos)
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    /// 更新可见资产（应用层级折叠过滤）
    private func updateVisibleAssets() {
        let newVisibleAssets: [PHAsset]
        
        if let collection = currentCollection {
            if let referenceAsset = hierarchyReferenceAsset,
               !assets.contains(where: { $0.localIdentifier == referenceAsset.localIdentifier }) {
                hierarchyReferenceAsset = nil
            }
            newVisibleAssets = hierarchyService.getVisibleAssets(from: assets, in: collection)
        } else {
            newVisibleAssets = assets
        }
        
        // 只在数据真正变化时才更新
        if newVisibleAssets.count != visibleAssets.count ||
           !newVisibleAssets.elementsEqual(visibleAssets, by: { $0.localIdentifier == $1.localIdentifier }) {
            PhotoCell.cachingManager.stopCachingImagesForAllAssets()
            visibleAssets = newVisibleAssets
            preloadCustomOrderCache()
            prewarmHierarchyCache(for: newVisibleAssets)
            collectionView.reloadData()
        }
    }
    
    /// 预构建自定义排序索引字典，将 O(n) 线性搜索降为 O(1)
    func invalidateCustomOrderCache() {
        customOrderIndexCache.removeAll()
    }
    private func preloadCustomOrderCache() {
        guard let collection = currentCollection, customOrderIndexCache.isEmpty else { return }
        let order = PhotoOrder.order(for: collection)
        var dict = [String: Int](minimumCapacity: order.count)
        for (i, id) in order.enumerated() {
            dict[id] = i
        }
        customOrderIndexCache = dict
    }
    
    /// 批量预计算首屏层级信息并写入缓存，减少滚动时 cellForItemAt 的计算量
    private static let hierarchyPrewarmCount = 60
    private func prewarmHierarchyCache(for assets: [PHAsset]) {
        guard let collection = currentCollection else { return }
        let count = min(assets.count, Self.hierarchyPrewarmCount)
        for i in 0..<count {
            let asset = assets[i]
            let id = asset.localIdentifier
            if hierarchyCache[id] == nil {
                let text = hierarchyService.hierarchyText(for: asset, in: collection)
                let collapsed = hierarchyService.isCollapsed(asset, in: collection)
                hierarchyCache[id] = (text: text, isCollapsed: collapsed)
            }
        }
    }
    
    /// 刷新层级显示
    func refreshParagraphDisplay() {
        // 清除层级缓存，确保重新获取最新的层级信息
        hierarchyCache.removeAll()
        updateVisibleAssets()
        // 强制刷新当前可见的Cell，确保层级信息更新
        collectionView.reloadData()
    }
    
    /// 定位到指定索引位置的照片
    /// - Parameter index: 照片在数组中的索引位置
    func scrollTo(index: Int) {
        guard index >= 0 && index < visibleAssets.count else { return }
        
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
            
            // 从选中列表中移除
            for asset in assetsToDelete {
                if self.selectedMap[asset.localIdentifier] != nil {
                    self.selectedMap.removeValue(forKey: asset.localIdentifier)
                    // 如果删除的是锚点照片，清除锚点
                    if self.anchorPhoto?.localIdentifier == asset.localIdentifier {
                        self.anchorPhoto = nil
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
        return visibleAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = visibleAssets[indexPath.item]
        let isSelected = selectedMap[photo.localIdentifier] != nil
        
        // 列数多时 cell 很小，跳过不可见的 UI 计算（层级、媒体图标、收藏等）
        let isCompact = columns >= 7
        
        if isCompact {
            cell.configure(
                with: photo,
                isSelected: isSelected,
                selectionIndex: nil,
                selectionMode: selectionMode,
                compact: true
            )
        } else {
            let selectionIndex = selectedMap[photo.localIdentifier]?.0
            let isAnchor = anchorPhoto?.localIdentifier == photo.localIdentifier
            
            let assetID = photo.localIdentifier
            var hierarchyText: String?
            var isHierarchyCollapsed: Bool = false
            
            if let cached = hierarchyCache[assetID] {
                hierarchyText = cached.text
                isHierarchyCollapsed = cached.isCollapsed
            } else {
                if let collection = currentCollection {
                    hierarchyText = hierarchyService.hierarchyText(for: photo, in: collection)
                    isHierarchyCollapsed = hierarchyService.isCollapsed(photo, in: collection)
                }
                hierarchyCache[assetID] = (text: hierarchyText, isCollapsed: isHierarchyCollapsed)
            }
            
            let displayIndex: Int
            switch sortPreference {
            case .creationDate, .modificationDate, .recentDate:
                displayIndex = getCustomOrderIndex(for: photo)
            case .custom:
                displayIndex = indexPath.item
            }
            
            cell.configure(
                with: photo,
                isSelected: isSelected,
                selectionIndex: selectionIndex,
                selectionMode: selectionMode,
                index: displayIndex,
                isAnchor: isAnchor,
                hierarchyText: hierarchyText,
                isHierarchyCollapsed: isHierarchyCollapsed
            )
        }
        return cell
    }
}

// MARK: - UICollectionViewDataSourcePrefetching
extension PhotoGridView: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let cellSize = effectiveCellSize(for: collectionView)
        let targetSize = PhotoCell.thumbnailSize(for: cellSize)
        let assets = indexPaths.compactMap { $0.item < visibleAssets.count ? visibleAssets[$0.item] : nil }
        guard !assets.isEmpty else { return }
        PhotoCell.cachingManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: PhotoCell.thumbnailOptionsFast
        )
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let cellSize = effectiveCellSize(for: collectionView)
        let targetSize = PhotoCell.thumbnailSize(for: cellSize)
        let assets = indexPaths.compactMap { $0.item < visibleAssets.count ? visibleAssets[$0.item] : nil }
        guard !assets.isEmpty else { return }
        PhotoCell.cachingManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: PhotoCell.thumbnailOptionsFast
        )
    }
    
    private func effectiveCellSize(for collectionView: UICollectionView) -> CGSize {
        if let cached = cachedCellSize, collectionView.bounds.width == lastCollectionViewWidth {
            return cached
        }
        let sectionInset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let spacing = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? PhotoGridConstants.defaultSpacing
        let totalSpacing = sectionInset.left + sectionInset.right + (CGFloat(columns - 1) * spacing)
        let width = max(1, (collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        return CGSize(width: width, height: width)
    }
}

// MARK: - UICollectionViewDelegate
extension PhotoGridView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         guard indexPath.item < visibleAssets.count else { return }
         let photo = visibleAssets[indexPath.item]
         
         switch selectionMode {
         case .none:
             // 调用代理方法
             delegate?.photoGridView(self, didSelectItemAt: photo)
         case .multiple:
             handleMultipleSelection(at: indexPath, in: collectionView, with: photo)
         case .range:
             handleRangeSelection(at: indexPath, in: collectionView, with: photo)
         }
     }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard (selectionMode == .multiple || selectionMode == .range), indexPath.item < visibleAssets.count else { return }
        let photo = visibleAssets[indexPath.item]
        handleDeselection(at: indexPath, in: collectionView, with: photo)
    }
    
}

// MARK: - Helper Methods
extension PhotoGridView {
    private func handleMultipleSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }
        
        let wasSelected = selectedMap[photo.localIdentifier] != nil
        collectionView.performBatchUpdates {
            let updatedPhotos = toggle(photo: photo)
            collectionView.reloadItems(at: [indexPath])
            
            // 只重新加载序号发生变化的照片的单元格，提高性能
            if wasSelected {
                var updatedIndexPaths: [IndexPath] = []
                for (index, asset) in visibleAssets.enumerated() {
                    if updatedPhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        updatedIndexPaths.append(IndexPath(item: index, section: 0))
                    }
                }
                if !updatedIndexPaths.isEmpty {
                    collectionView.reloadItems(at: updatedIndexPaths)
                }
            }
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
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }
        
        let index = indexPath.item
        let isSelected = selectedMap[photo.localIdentifier] != nil
        
        if isSelected {
            // 如果点击已选中照片，反选它，并重设范围
            collectionView.performBatchUpdates {
                let updatedPhotos = toggle(photo: photo)
                collectionView.reloadItems(at: [indexPath])
                
                // 只重新加载序号发生变化的照片的单元格，提高性能
                var updatedIndexPaths: [IndexPath] = []
                for (idx, asset) in visibleAssets.enumerated() {
                    if updatedPhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        updatedIndexPaths.append(IndexPath(item: idx, section: 0))
                    }
                }
                if !updatedIndexPaths.isEmpty {
                    collectionView.reloadItems(at: updatedIndexPaths)
                }
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
                _ = toggle(photo: photo)
                collectionView.reloadItems(at: [indexPath])
            } completion: { _ in
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
            }
        } else {
            // 第二次点击：设置结束位置，选中范围，重设范围
            selectedEnd = index
            
            // 检查范围内是否所有照片都已选中，如果是则执行反选，否则执行选中
            let startIndex = min(selectedStart!, selectedEnd!)
            let endIndex = max(selectedStart!, selectedEnd!)
            var allSelected = true
            
            for i in startIndex...endIndex {
                if i < visibleAssets.count {
                    let asset = visibleAssets[i]
                    if selectedMap[asset.localIdentifier] == nil {
                        allSelected = false
                        break
                    }
                }
            }
            
            if allSelected {
                // 范围内所有照片都已选中，执行反选
                deselectRange(from: startIndex, to: endIndex)
            } else {
                // 范围内有未选中的照片，执行选中
                let reverse = selectedEnd! < selectedStart!
                selectRange(from: startIndex, to: endIndex, reverse: reverse)
            }
            
            selectedStart = nil
            selectedEnd = nil
        }
    }
    
    private func handleDeselection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击取消选择
        guard !isSlidingSelectionEnabled else { return }
        
        collectionView.performBatchUpdates {
            // 取消选择并获取需要更新序号的照片列表
            let updatedPhotos = toggle(photo: photo)
            // 重新加载当前取消选择的照片的单元格
            collectionView.reloadItems(at: [indexPath])
            
            // 只重新加载序号发生变化的照片的单元格，提高性能
            var updatedIndexPaths: [IndexPath] = []
            for (index, asset) in visibleAssets.enumerated() {
                if updatedPhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                    updatedIndexPaths.append(IndexPath(item: index, section: 0))
                }
            }
            if !updatedIndexPaths.isEmpty {
                collectionView.reloadItems(at: updatedIndexPaths)
            }
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
        // 如果 CollectionView 宽度和列数没有变化，直接返回缓存的尺寸
        if collectionView.bounds.width == lastCollectionViewWidth,
           let cachedSize = cachedCellSize {
            return cachedSize
        }
        
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let sectionInset = flowLayout.sectionInset
        let interItemSpacing = flowLayout.minimumInteritemSpacing
        
        let totalSpacing = sectionInset.left + sectionInset.right + (CGFloat(columns - 1) * interItemSpacing)
        let width = max(1, (collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        let size = CGSize(width: width, height: width)
        
        // 缓存结果
        cachedCellSize = size
        lastCollectionViewWidth = collectionView.bounds.width
        
        return size
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !isSlidingSelectionEnabled {
            scrollDelegate?.scrollViewDidScroll?(scrollView)
        }
    }
        
    // 新增：重写 scrollViewWillBeginDragging 方法来控制滚动
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 如果正在滑动选择，则阻止滚动
        if isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = false
        }
        
        scrollDelegate?.scrollViewWillBeginDragging?(scrollView)
    }
    
    // 新增：重写 scrollViewDidEndDragging 方法来恢复滚动
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = true
        }
        scrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PhotoGridView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 不允许滑动手势和滚动同时进行
        return false
    }
    
    // 新增：控制手势识别的条件
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只处理pan手势
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        
        // 只有在选择模式下才考虑滑动选择
        guard selectionMode == .multiple || selectionMode == .range else { return false }
        
        // 检查手势的初始方向
        let velocity = panGesture.velocity(in: collectionView)
        let verticalVelocity = abs(velocity.y)
        let horizontalVelocity = abs(velocity.x)
        
        // 只有横向滑动才触发滑动选择，纵向滑动保持正常滚动
        return horizontalVelocity > verticalVelocity
    }
    
    // 新增：控制手势是否应该被取消
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 让滚动手势在滑动选择手势开始后失败，优先处理滑动选择
        if gestureRecognizer is UIPanGestureRecognizer, 
           otherGestureRecognizer is UIPanGestureRecognizer, 
           otherGestureRecognizer.view == collectionView {
            // 检查是否在选择模式下
            return selectionMode == .multiple || selectionMode == .range
        }
        return false
    }
    
    // 新增：控制手势是否应该取消其他手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldCancelOtherGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 当滑动选择手势开始时，取消滚动手势
        if gestureRecognizer is UIPanGestureRecognizer, 
           otherGestureRecognizer is UIPanGestureRecognizer, 
           otherGestureRecognizer.view == collectionView {
            // 检查是否在选择模式下
            return selectionMode == .multiple || selectionMode == .range
        }
        return false
    }
}

// MARK: - UICollectionView Context Menu
extension PhotoGridView {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < visibleAssets.count else { return nil }
        let asset = visibleAssets[indexPath.item]
        let isCurrentAnchor = anchorPhoto?.localIdentifier == asset.localIdentifier
        let isCurrentHierarchyCollapsed = currentCollection != nil ? hierarchyService.isCollapsed(asset, in: currentCollection!) : false
        let hasHierarchyDescendants = currentCollection != nil ? hierarchyService.hasDescendants(asset, in: assets, collection: currentCollection!) : false
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [self] _ in
            var anchorGroup: [UIMenuElement] = []
            var hierarchyGroup: [UIMenuElement] = []
            var tailGroup: [UIMenuElement] = []
            var hierarchyChildren: [UIMenuElement] = []
            
            // 锚点相关操作
            if isCurrentAnchor {
                let removeAnchorAction = UIAction(title: "取消锚点", image: UIImage(systemName: "anchor.slash")) { [weak self] _ in
                    self?.anchorPhoto = nil
                    self?.collectionView.reloadData()
                }
                anchorGroup.append(removeAnchorAction)
            } else {
                let setAnchorAction = UIAction(title: "设为锚点", image: UIImage(systemName: "anchor")) { [weak self] _ in
                    self?.anchorPhoto = asset
                    self?.collectionView.reloadData()
                    self?.delegate?.photoGridView(self!, didSetAnchor: asset)
                }
                anchorGroup.append(setAnchorAction)
            }
            
            // 层级相关操作
            if let collection = currentCollection {
                let setTopLevelAction = UIAction(title: "设为1级（顶级）", image: UIImage(systemName: "list.number")) { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.photoGridView(self, didRequestSetTopLevelFor: asset)
                }
                hierarchyGroup.append(setTopLevelAction)

                let setSameLevelAction = UIAction(title: "设为同级", image: UIImage(systemName: "equal.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyService.setAsSiblingOfPrevious(asset, in: self.assets, collection: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyChildren.append(setSameLevelAction)

                let setChildOfPreviousAction = UIAction(title: "设为子级", image: UIImage(systemName: "arrow.down.right")) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyService.setAsChildOfPrevious(asset, in: self.assets, collection: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyChildren.append(setChildOfPreviousAction)

                let setSpecificLevelAction = UIAction(title: "指定层级...", image: UIImage(systemName: "number.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.photoGridView(self, didRequestSetHierarchyLevelFor: asset)
                }
                hierarchyChildren.append(setSpecificLevelAction)

                let isReference = hierarchyReferenceAsset?.localIdentifier == asset.localIdentifier
                let toggleReferenceAction = UIAction(
                    title: isReference ? "取消层级参照" : "设为层级参照",
                    image: UIImage(systemName: isReference ? "flag.slash" : "flag")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyReferenceAsset = isReference ? nil : asset
                    self.refreshParagraphDisplay()
                }
                hierarchyChildren.append(toggleReferenceAction)

                if let referenceAsset = hierarchyReferenceAsset, referenceAsset.localIdentifier != asset.localIdentifier {
                    let referenceText = hierarchyService.hierarchyText(for: referenceAsset, in: collection) ?? "参照项"
                    let setAsChildAction = UIAction(
                        title: "设为“\(referenceText)”的子级",
                        image: UIImage(systemName: "arrow.down.right")
                    ) { [weak self] _ in
                        guard let self = self else { return }
                        self.hierarchyService.setAsChild(asset, of: referenceAsset, in: collection)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyChildren.append(setAsChildAction)

                    let insertAfterAction = UIAction(
                        title: "插入到参照后面（同级）",
                        image: UIImage(systemName: "arrow.right.to.line.compact")
                    ) { [weak self] _ in
                        guard let self = self else { return }
                        self.hierarchyService.insertAsSiblingAfter(asset, reference: referenceAsset, in: collection)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyChildren.append(insertAfterAction)
                }

                let promoteAction = UIAction(title: "提升一级", image: UIImage(systemName: "arrow.up.left")) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyService.promote(asset, in: self.assets, collection: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyChildren.append(promoteAction)

                let demoteAction = UIAction(title: "降一级", image: UIImage(systemName: "arrow.down.right.and.arrow.up.left")) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyService.setAsChildOfPrevious(asset, in: self.assets, collection: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyChildren.append(demoteAction)

                let clearHierarchyAction = UIAction(title: "清理层级", image: UIImage(systemName: "xmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.hierarchyService.clearSubtree(of: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyGroup.append(clearHierarchyAction)

                if hasHierarchyDescendants || isCurrentHierarchyCollapsed {
                    let collapseAction = UIAction(
                        title: isCurrentHierarchyCollapsed ? "展开分组" : "折叠分组",
                        image: UIImage(systemName: isCurrentHierarchyCollapsed ? "chevron.down" : "chevron.up")
                    ) { [weak self] _ in
                        guard let self = self else { return }
                        self.hierarchyService.toggleCollapse(asset, in: collection)
                        self.refreshParagraphDisplay()
                    }
                    hierarchyGroup.append(collapseAction)
                }

            }

            // 标签操作
            let tagAction = UIAction(title: "添加标签", image: UIImage(systemName: "tag")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.photoGridView(self, didRequestAddTagFor: asset)
            }
            tailGroup.append(tagAction)

            // 粘贴到此后方操作
            // 不直接检查剪贴板，而是在用户点击时才访问，避免触发权限弹窗
            let pasteAction = UIAction(title: "粘贴到此后方", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                if let pasteAssets = AssetPasteboard.assetsFromPasteboard(), !pasteAssets.isEmpty {
                    self?.handlePasteToAfter(asset: asset, assets: pasteAssets)
                }
            }
            tailGroup.append(pasteAction)

            if !hierarchyChildren.isEmpty {
                hierarchyGroup.append(
                    UIMenu(
                        title: "层级",
                        image: UIImage(systemName: "list.bullet.indent"),
                        children: hierarchyChildren
                    )
                )
            }

            var rootChildren: [UIMenuElement] = []
            if !anchorGroup.isEmpty {
                rootChildren.append(UIMenu(title: "锚点", image: UIImage(systemName: "anchor"), options: .displayInline, children: anchorGroup))
            }
            if !hierarchyGroup.isEmpty {
                rootChildren.append(UIMenu(title: "层级", options: .displayInline, children: hierarchyGroup))
            }
            if !tailGroup.isEmpty {
                rootChildren.append(UIMenu(title: "其他", options: .displayInline, children: tailGroup))
            }
            return UIMenu(title: "", children: rootChildren)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: identifier) else { return nil }
        
        return UITargetedPreview(view: cell)
    }
}

// MARK: - CustomVerticalScrollIndicatorDelegate
extension PhotoGridView: CustomVerticalScrollIndicatorDelegate {
    func scrollIndicator(_ indicator: CustomVerticalScrollIndicator, textForScrollProgress scrollProgress: CGFloat) -> String? {
        guard !visibleAssets.isEmpty else { return nil }
        
        // 根据滚动进度计算当前显示的照片索引
        let totalItems = visibleAssets.count
        let currentIndex = Int(scrollProgress * CGFloat(totalItems - 1))
        let clampedIndex = max(0, min(currentIndex, totalItems - 1))
        
        let asset = visibleAssets[clampedIndex]
        
        switch sortPreference {
        case .creationDate, .modificationDate, .recentDate:
            // 日期排序：显示日期
            return formatDate(for: asset)
        case .custom:
            // 自定义排序：显示下标（从1开始）
            return "\(clampedIndex + 1)"
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    private func formatDate(for asset: PHAsset) -> String {
        let date: Date
        switch sortPreference {
        case .creationDate:
            date = asset.creationDate ?? Date()
        case .modificationDate, .recentDate:
            date = asset.modificationDate ?? asset.creationDate ?? Date()
        case .custom:
            date = asset.creationDate ?? Date()
        }
        
        return Self.dateFormatter.string(from: date)
    }
    
    // MARK: - 粘贴到此后方处理
    private func handlePasteToAfter(asset: PHAsset, assets: [PHAsset]) {
        guard currentCollection != nil else { return }
        self.delegate?.photoGridView(self, didPasteAssets: assets, after: asset)
    }
}
