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
}

extension PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {}
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
            // 应用段落折叠过滤
            updateVisibleAssets()
        }
    }
    
    // 实际显示的照片（经过段落折叠过滤）
    private var visibleAssets: [PHAsset] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
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
    private var isSlidingSelectionEnabled = false
    private var lastSelectedIndexPath: IndexPath?
    
    // 新增：用于跟踪滑动选择的方向（选中或反选）
    private var isSlidingToSelect = true
    
    // 新增：用于临时禁用滚动
    private var isScrollDisabled = false
    
    // 新增：用于跟踪手势方向
    private var initialTouchPoint: CGPoint = .zero
    private var hasStartedSelection = false
    private let selectionThreshold: CGFloat = 10.0 // 开始选中的阈值
    
    // 选中照片（根据选中顺序排序的派生数组）
    private var selectedPhotos: [PHAsset] {
        return selectedMap.values.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    
    // 照片ID -> (选中序号(从1开始且连续), 资产)
    private var selectedMap: [String: (Int, PHAsset)] = [:]
    
    // 当前锚点照片
    private var anchorPhoto: PHAsset?
    
    // 当前排序方式
    public var sortPreference: PhotoSortPreference = .custom
    
    // 当前相册引用，用于获取自定义排序数据
    public var currentCollection: PHAssetCollection?
    
    // 首图服务引用
    private let headerService = PhotoHeaderService.shared
    
    private var columns: Int = PhotoGridConstants.defaultColumns
    
    
    private var lastScale: CGFloat = 3.0
    
    private lazy var collectionView: UICollectionView = {
        let initialLayout = createLayout(for: columns)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: initialLayout)
        collectionView.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
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
        
        addSubview(verticalScrollIndicator)
        
        NSLayoutConstraint.activate([
            verticalScrollIndicator.topAnchor.constraint(equalTo: topAnchor),
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
        let newLayout = createLayout(for: columns)
        collectionView.setCollectionViewLayout(newLayout, animated: true)
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
        let translation = gesture.translation(in: collectionView)
        
        switch gesture.state {
        case .began:
            initialTouchPoint = point
            hasStartedSelection = false
            isSlidingSelectionEnabled = false
            lastSelectedIndexPath = nil
            isSlidingToSelect = true // 默认为选中模式
        case .changed:
            let deltaX = abs(translation.x)
            let deltaY = abs(translation.y)
            
            // 如果还没有开始选择，判断是否应该开始选择
            if !hasStartedSelection {
                // 如果横向移动大于阈值且横向移动大于纵向移动，则开始选择
                if deltaX > selectionThreshold && deltaX > deltaY {
                    hasStartedSelection = true
                    isSlidingSelectionEnabled = true
                    // 禁用滚动
                    isScrollDisabled = true
                    collectionView.isScrollEnabled = false
                    // 获取起始点的索引路径
                    if let indexPath = collectionView.indexPathForItem(at: initialTouchPoint) {
                        // 检查起始点是否已选中，如果是则设置为反选模式
                        if let asset = getAsset(at: indexPath) {
                            isSlidingToSelect = selectedMap[asset.localIdentifier] == nil
                        }
                        handleSlidingSelection(at: indexPath)
                    }
                }
            }
            
            // 如果已经开始了选择，则处理滑动选择
            if isSlidingSelectionEnabled {
                if let indexPath = collectionView.indexPathForItem(at: point) {
                    handleSlidingSelection(at: indexPath)
                }
            }
        case .ended, .cancelled:
            // 恢复滚动
            isSlidingSelectionEnabled = false
            isScrollDisabled = false
            collectionView.isScrollEnabled = true
            hasStartedSelection = false
            lastSelectedIndexPath = nil
        default:
            break
        }
    }
    
    // 新增：处理滑动选择逻辑
    private func handleSlidingSelection(at indexPath: IndexPath) {
        guard isSlidingSelectionEnabled, indexPath.item < visibleAssets.count else { return }
        
        // 如果是同一个单元格，不处理
        if lastSelectedIndexPath == indexPath {
            return
        }
        
        let photo = visibleAssets[indexPath.item]
        let isSelected = selectedMap[photo.localIdentifier] != nil
        
        // 根据滑动模式进行选中或反选
        if isSlidingToSelect {
            // 选中模式：只选中未选中的照片
            if !isSelected {
                collectionView.performBatchUpdates {
                    toggle(photo: photo)
                    collectionView.reloadItems(at: [indexPath])
                } completion: { _ in
                    self.delegate?.photoGridView(self, didSelectItemAt: photo)
                    self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
                }
            }
        } else {
            // 反选模式：只取消已选中的照片
            if isSelected {
                collectionView.performBatchUpdates {
                    toggle(photo: photo)
                    collectionView.reloadItems(at: [indexPath])
                } completion: { _ in
                    self.delegate?.photoGridView(self, didDeselectItemAt: photo)
                    self.delegate?.photoGridView(self, didSelectedItems: self.selectedPhotos)
                }
            }
        }
        
        lastSelectedIndexPath = indexPath
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
        let itemWidth = (bounds.width - totalSpacing) / CGFloat(columns)
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        
        return layout
    }
    
    // 新增：根据索引路径获取资源
    private func getAsset(at indexPath: IndexPath) -> PHAsset? {
        guard indexPath.item < assets.count else { return nil }
        return assets[indexPath.item]
    }
    
    func toggle(photo: PHAsset) {
        if let (removedRank, _) = selectedMap[photo.localIdentifier] {
            // 取消选择：移除并将比它序号大的全部-1，保持连续
            selectedMap.removeValue(forKey: photo.localIdentifier)
            for (id, value) in selectedMap {
                if value.0 > removedRank {
                    selectedMap[id] = (value.0 - 1, value.1)
                }
            }
            // 如果删除的是锚点照片，清除锚点
            if anchorPhoto?.localIdentifier == photo.localIdentifier {
                anchorPhoto = nil
            }
        } else {
            // 新选：序号为当前数量+1
            let newRank = selectedMap.count + 1
            selectedMap[photo.localIdentifier] = (newRank, photo)
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
        // 根据方向决定追加顺序
        let indices = startIndex <= endIndex ? Array(startIndex...endIndex) : Array(endIndex...startIndex).reversed()
        
        for index in indices {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            if selectedMap[asset.localIdentifier] != nil {
                toggle(photo: asset)
                indexPaths.append(IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: asset)
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
    
    // 已不需要按次序计算排名，直接从 selectedMap 中读取
    
    /// 获取照片在自定义排序中的下标位置
    /// - Parameter photo: 要查询的照片
    /// - Returns: 自定义排序中的下标位置（从0开始），如果未找到则返回-1
    private func getCustomOrderIndex(for photo: PHAsset) -> Int {
        guard let collection = currentCollection else { 
            print("❌ getCustomOrderIndex: currentCollection is nil")
            return -1 
        }
        
        // 获取自定义排序数据
        let customOrder = PhotoOrder.order(for: collection)
        print("🔍 getCustomOrderIndex: customOrder count = \(customOrder.count)")
        print("🔍 getCustomOrderIndex: looking for photo = \(photo.localIdentifier)")
        
        // 在自定义排序中查找照片的位置
        if let index = customOrder.firstIndex(of: photo.localIdentifier) {
            print("✅ getCustomOrderIndex: found at index = \(index)")
            return index
        }
        
        // 如果在自定义排序中未找到，返回-1表示不在自定义排序中
        print("❌ getCustomOrderIndex: photo not found in custom order")
        return -1
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
    
    // MARK: - Public Methods
    
    /// 更新可见资产（应用段落折叠过滤）
    private func updateVisibleAssets() {
        guard let collection = currentCollection else {
            visibleAssets = assets
            return
        }
        
        visibleAssets = headerService.getVisibleAssets(from: assets, in: collection)
    }
    
    /// 刷新段落显示
    func refreshParagraphDisplay() {
        updateVisibleAssets()
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
        let selectionIndex = selectedMap[photo.localIdentifier]?.0
        let isAnchor = anchorPhoto?.localIdentifier == photo.localIdentifier
        
        // 检查是否为首图
        let isHeader = currentCollection != nil ? headerService.isHeader(photo, for: currentCollection!) : false
        
        // 根据排序方式决定显示的下标
        let displayIndex: Int
        switch sortPreference {
        case .creationDate, .modificationDate, .recentDate:
            // 时间排序：显示自定义排序的下标
            displayIndex = getCustomOrderIndex(for: photo)
        case .custom:
            // 自定义排序：显示顺序下标
            displayIndex = indexPath.item
        }
        
        cell.configure(with: photo, isSelected: isSelected, selectionIndex: selectionIndex, selectionMode: selectionMode, index: displayIndex, isAnchor: isAnchor, isHeader: isHeader)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension PhotoGridView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < visibleAssets.count else { return }
        let photo = visibleAssets[indexPath.item]
        
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
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }
        
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
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let sectionInset = flowLayout.sectionInset
        let interItemSpacing = flowLayout.minimumInteritemSpacing
        
        let totalSpacing = sectionInset.left + sectionInset.right + (CGFloat(columns - 1) * interItemSpacing)
        let width = (collectionView.bounds.width - totalSpacing) / CGFloat(columns)
        return CGSize(width: width, height: width)
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 只有在非滑动选择状态下才通知代理
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
        // 如果不是在滑动选择状态，则恢复滚动
        if !isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = true
        }
        
        scrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 滚动完全停止时的处理
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PhotoGridView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许滑动手势和滚动同时进行
        return true
    }
    
    // 新增：控制手势识别的条件
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只有在多选模式或范围选择模式下才允许滑动手势开始
        return selectionMode == .multiple || selectionMode == .range
    }
}

// MARK: - UICollectionView Context Menu
extension PhotoGridView {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < visibleAssets.count else { return nil }
        let asset = visibleAssets[indexPath.item]
        let isCurrentAnchor = anchorPhoto?.localIdentifier == asset.localIdentifier
        let isCurrentHeader = currentCollection != nil ? headerService.isHeader(asset, for: currentCollection!) : false
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [self] _ in
            var actions: [UIAction] = []
            
            // 锚点相关操作
            if isCurrentAnchor {
                let removeAnchorAction = UIAction(title: "取消锚点", image: UIImage(systemName: "anchor.slash")) { [weak self] _ in
                    self?.anchorPhoto = nil
                    self?.collectionView.reloadData()
                    print("锚点已取消")
                }
                actions.append(removeAnchorAction)
            } else {
                let setAnchorAction = UIAction(title: "设为锚点", image: UIImage(systemName: "anchor")) { [weak self] _ in
                    self?.anchorPhoto = asset
                    self?.collectionView.reloadData()
                    self?.delegate?.photoGridView(self!, didSetAnchor: asset)
                    print("锚点已设置为: \(asset.localIdentifier)")
                }
                actions.append(setAnchorAction)
            }
            
            // 首图相关操作
            if isCurrentHeader {
                let removeHeaderAction = UIAction(title: "取消首图", image: UIImage(systemName: "photo.badge.minus")) { [weak self] _ in
                    guard let self = self, let collection = self.currentCollection else { return }
                    self.headerService.removeHeader(asset, for: collection)
                    self.refreshParagraphDisplay()
                    print("首图已取消: \(asset.localIdentifier)")
                }
                actions.append(removeHeaderAction)
                
                // 段落折叠/展开操作
                let isCollapsed = currentCollection != nil ? headerService.isParagraphCollapsed(asset, for: currentCollection!) : false
                let collapseAction = UIAction(
                    title: isCollapsed ? "展开段落" : "折叠段落",
                    image: UIImage(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                ) { [weak self] _ in
                    guard let self = self, let collection = self.currentCollection else { return }
                    self.headerService.toggleParagraphCollapse(asset, for: collection)
                    self.refreshParagraphDisplay()
                    print("段落状态已切换: \(asset.localIdentifier)")
                }
                actions.append(collapseAction)
            } else {
                let setHeaderAction = UIAction(title: "设为首图", image: UIImage(systemName: "photo.badge.plus")) { [weak self] _ in
                    guard let self = self, let collection = self.currentCollection else { return }
                    self.headerService.setHeader(asset, for: collection)
                    self.refreshParagraphDisplay()
                    print("首图已设置: \(asset.localIdentifier)")
                }
                actions.append(setHeaderAction)
            }
            
            // 粘贴到此后方操作
            if let pasteAssets = AssetPasteboard.assetsFromPasteboard(), !pasteAssets.isEmpty {
                let pasteAction = UIAction(title: "粘贴到此后方", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                    self?.handlePasteToAfter(asset: asset, assets: pasteAssets)
                }
                actions.append(pasteAction)
            }
            
            return UIMenu(title: "", children: actions)
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
    
    private func formatDate(for asset: PHAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let date: Date
        switch sortPreference {
        case .creationDate:
            date = asset.creationDate ?? Date()
        case .modificationDate, .recentDate:
            date = asset.modificationDate ?? asset.creationDate ?? Date()
        case .custom:
            date = asset.creationDate ?? Date()
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - 粘贴到此后方处理
    private func handlePasteToAfter(asset: PHAsset, assets: [PHAsset]) {
        guard let collection = currentCollection else { return }
        self.delegate?.photoGridView(self, didPasteAssets: assets, after: asset)
    }
}

