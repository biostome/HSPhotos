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

protocol PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath)
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath)
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset)
    /// 选中集变化。`assets` 在数量很大时可能为空以省内存，请使用 `photoGridView.selectedAssets` 取全量。
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset])
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset)
    func photoGridView(_ photoGridView: PhotoGridView, didRequestDelete asset: PHAsset)
}

extension PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {}
    func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {}
    func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset) {}
    func photoGridView(_ photoGridView: PhotoGridView, didRequestDelete asset: PHAsset) {}
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
    private let overlaySettings = OverlayDisplaySettings.shared
    internal var overlaySettingsObserver: NSObjectProtocol?
    internal var hierarchyCollapseSettingsObserver: NSObjectProtocol?

    /// 单相簿领域状态；绑定后 `assets` / 可见行由 Session 派生。
    public weak var albumSession: AlbumSession?

    internal var lastGridInputIdentifiers: [String] = []

    /// 标签筛选后的网格输入行（绑定 Session 后由 Session 派生）。
    public var assets: [PHAsset] {
        albumSession?.tagFilteredMembers() ?? []
    }

    /// 将网格挂载到相簿 Session，并同步排序/层级配置与展示序列。
    public func bind(to session: AlbumSession) {
        albumSession = session
        reloadFromSession()
    }

    /// Session 成员、筛选或排序变化后由控制器调用。
    public func reloadFromSession() {
        let newIds = assets.map(\.localIdentifier)
        let idsChanged = lastGridInputIdentifiers != newIds
        lastGridInputIdentifiers = newIds
        invalidateCustomOrderCache()
        invalidateDateTextCache()
        if idsChanged {
            hierarchyCache.removeAll()
        }
        updateVisibleAssets()
        // 删除节点后存储层级已校正，但可见序列可能不变（例如删的是折叠分支内未展示的项），须强制刷新编号 overlay
        if idsChanged, sortPreference == .custom, supportsHierarchyNumbering {
            collectionView.reloadData()
        }
    }

    // 实际显示的照片（经过层级折叠过滤）
    internal var visibleAssets: [PHAsset] = []

    public var delegate: PhotoGridViewDelegate?

    public weak var scrollDelegate: UIScrollViewDelegate?

    public var selectedAssets: [PHAsset] { selectedPhotos }

    public var selectedAssetCount: Int { selectionState.count }

    public var hasSelectedAssets: Bool { selectionState.count > 0 }

    /// 与 `selectedAssets` 成员一致，用于 O(1) 成员判断而无需构造 `[PHAsset]`。
    public var selectedMembershipIdentifiers: Set<String> { selectionState.selectedIdentifierSet }

    private static let maxSelectedAssetsInDelegatePayload = 512

    /// 通知 delegate 时避免在数万选中下分配整表 `[PHAsset]`。
    internal var selectedAssetsForDelegateNotification: [PHAsset] {
        if selectionState.count > Self.maxSelectedAssetsInDelegatePayload { return [] }
        return selectedPhotos
    }

    // 获取所有资产（包括隐藏的）
    public var allAssets: [PHAsset] { assets }

    /// 当前屏幕中心区域对应的可见照片，用于模糊快捷操作定位目标。
    public var centerVisibleAsset: PHAsset? {
        layoutIfNeeded()
        collectionView.layoutIfNeeded()

        let centerInGrid = CGPoint(x: bounds.midX, y: bounds.midY)
        let centerInCollection = convert(centerInGrid, to: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: centerInCollection),
           indexPath.item < visibleAssets.count {
            return visibleAssets[indexPath.item]
        }

        return nearestVisibleAsset(to: centerInCollection)
    }

    public var selectionMode: PhotoSelectionMode = .none {
        didSet {
            collectionView.allowsMultipleSelection = selectionMode == .multiple || selectionMode == .range
            collectionView.reloadData()
            if oldValue != selectionMode {
                syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
            }
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
    internal var selectedPhotos: [PHAsset] {
        selectionState.orderedIDs.compactMap { selectedAssetByID[$0] }
    }

    internal var selectionState = PhotoGridSelectionState()
    /// 仅缓存「当前在选中集中」的资源，供 `selectedPhotos` 与 delegate 使用。
    internal var selectedAssetByID: [String: PHAsset] = [:]

    /// 选择模式快速定位：链式「上一处/下一处」的锚点（可见下标）；`nil` 表示按当前视口边界取下一目标。
    internal var selectionQuickNavJumpIndex: Int?
    /// 由控制器注入：锚点或选中集变化时刷新底部工具条上按钮的 `isEnabled`。
    var onSelectionQuickNavToolbarRefresh: (() -> Void)?

    // 当前锚点照片
    internal var anchorPhoto: PHAsset?

    // 当前层级参照照片（用于“设为某项子级/插入到某级后面”）

    /// 排序方式（绑定 Session 后只读 Session）。
    public var sortPreference: PhotoSortPreference {
        albumSession?.sortPreference ?? .custom
    }

    /// 当前相册（绑定 Session 后只读 Session）。
    public var currentCollection: PHAssetCollection? {
        albumSession?.collection
    }

    /// 是否支持层级编号（绑定 Session 后只读 Session）。
    public var supportsHierarchyNumbering: Bool {
        albumSession?.supportsHierarchyNumbering ?? false
    }

    // 层级信息缓存，避免重复计算
    internal var hierarchyCache: [String: (text: String?, isCollapsed: Bool)] = [:]

    // 自定义排序索引缓存：assetID -> index，O(1) 查找
    internal var customOrderIndexCache: [String: Int] = [:]
    // 日期文本缓存：assetID -> (creationText, modificationText)
    internal var dateTextCache: [String: (creation: String, modification: String)] = [:]
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    internal var columns: Int = PhotoGridConstants.defaultColumns

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


    internal var lastScale: CGFloat = 3.0

    // 缓存 Cell 尺寸，避免重复计算
    internal var cachedCellSize: CGSize?
    internal var lastCollectionViewWidth: CGFloat = 0

    internal lazy var collectionView: UICollectionView = {
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
        observeOverlayAndHierarchySettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let token = overlaySettingsObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = hierarchyCollapseSettingsObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    internal func observeOverlayAndHierarchySettings() {
        overlaySettingsObserver = NotificationCenter.default.addObserver(
            forName: .overlayDisplaySettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.collectionView.reloadData()
        }
        hierarchyCollapseSettingsObserver = NotificationCenter.default.addObserver(
            forName: .hierarchyCollapseSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateVisibleAssets()
            self.collectionView.reloadData()
        }
    }

    internal func setupUI() {
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


    internal func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        // 添加滑动手势识别器
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        collectionView.addGestureRecognizer(panGesture)
    }

    internal func calculateNewColumns(for scaleDelta: CGFloat) -> Int {
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

    internal func updateColumns(to newColumns: Int) {
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
    @objc internal func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
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
    @objc internal func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
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
                    panInitialSelectionState = selectionState.contains(asset.localIdentifier)

                    let rankChanged = Set(toggle(photo: asset))
                    let toReload = indexPathsMergingExplicitAndVisibleRankChanges(
                        rankChangedIDs: rankChanged,
                        explicit: [indexPath]
                    )
                    reloadSelectionCellsWithoutAnimation(at: toReload)
                    // 通知代理
                    delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
                }
            }
        case .changed:
            // 处理滑动中的选择
            if let startIndexPath = panStartIndexPath, let currentIndexPath = collectionView.indexPathForItem(at: point) {
                // 只在indexPath变化时处理
                guard currentIndexPath != panLastIndexPath else { return }

                let startVisibleIndex = startIndexPath.item
                let currentVisibleIndex = currentIndexPath.item

                guard let currentAsset = getAsset(at: currentIndexPath) else { return }

                guard let lastIndexPath = panLastIndexPath else {
                    let targetSelectionState = !panInitialSelectionState
                    let isCurrentlySelected = selectionState.contains(currentAsset.localIdentifier)
                    let rankChanged: Set<String> = isCurrentlySelected != targetSelectionState
                        ? Set(toggle(photo: currentAsset))
                        : []
                    let toReload = indexPathsMergingExplicitAndVisibleRankChanges(
                        rankChangedIDs: rankChanged,
                        explicit: [currentIndexPath]
                    )
                    reloadSelectionCellsWithoutAnimation(at: toReload)
                    panLastIndexPath = currentIndexPath
                    delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
                    return
                }

                let lastVisibleIndex = lastIndexPath.item
                let targetSelectionState = !panInitialSelectionState
                let rangeStart = min(lastVisibleIndex, currentVisibleIndex)
                let rangeEnd = max(lastVisibleIndex, currentVisibleIndex)
                let fullRangeStart = min(startVisibleIndex, currentVisibleIndex)
                let fullRangeEnd = max(startVisibleIndex, currentVisibleIndex)

                var rankChangedAccumulator = Set<String>()
                var indexPathsToUpdate: [IndexPath] = []
                for i in rangeStart...rangeEnd {
                    guard i < visibleAssets.count else { continue }
                    let asset = visibleAssets[i]
                    let isCurrentlySelected = selectionState.contains(asset.localIdentifier)
                    let isInFullRange = i >= fullRangeStart && i <= fullRangeEnd
                    let expectedState = isInFullRange ? targetSelectionState : panInitialSelectionState
                    if isCurrentlySelected != expectedState {
                        rankChangedAccumulator.formUnion(toggle(photo: asset))
                        indexPathsToUpdate.append(IndexPath(item: i, section: 0))
                    }
                }

                // 更新最后处理的indexPath
                panLastIndexPath = currentIndexPath

                if !indexPathsToUpdate.isEmpty {
                    let toReload = indexPathsMergingExplicitAndVisibleRankChanges(
                        rankChangedIDs: rankChangedAccumulator,
                        explicit: indexPathsToUpdate
                    )
                    reloadSelectionCellsWithoutAnimation(at: toReload)
                }

                // 通知代理
                delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
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
    internal func createLayout(for columns: Int) -> UICollectionViewFlowLayout {
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

    /// 根据 collectionView 的 indexPath 获取对应资源（数据源为 visibleAssets）
    internal func getAsset(at indexPath: IndexPath) -> PHAsset? {
        guard indexPath.item < visibleAssets.count else { return nil }
        return visibleAssets[indexPath.item]
    }

    internal func nearestVisibleAsset(to point: CGPoint) -> PHAsset? {
        guard !visibleAssets.isEmpty else { return nil }
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return nil }

        let itemHeight = max(1, layout.itemSize.height + layout.minimumLineSpacing)
        let itemWidth = max(1, layout.itemSize.width + layout.minimumInteritemSpacing)
        let approximateRow = max(0, Int((point.y - layout.sectionInset.top) / itemHeight))
        let approximateColumn = max(0, min(columns - 1, Int((point.x - layout.sectionInset.left) / itemWidth)))
        let approximateIndex = approximateRow * columns + approximateColumn
        let clampedIndex = max(0, min(approximateIndex, visibleAssets.count - 1))
        return visibleAssets[clampedIndex]
    }

    /// 合并「必须刷的 indexPath」与「当前屏幕上且序号可能已变的 cell」，避免对整表做 O(n×m) 的 `contains` 与上万次 `reloadItems`。
    internal func indexPathsMergingExplicitAndVisibleRankChanges(
        rankChangedIDs: Set<String>,
        explicit indexPaths: [IndexPath]
    ) -> [IndexPath] {
        var result = Set(indexPaths)
        for ip in collectionView.indexPathsForVisibleItems {
            guard ip.section == 0, ip.item < visibleAssets.count else { continue }
            if rankChangedIDs.contains(visibleAssets[ip.item].localIdentifier) {
                result.insert(ip)
            }
        }
        return Array(result)
    }

    /// 无动画批量 `reloadItems`，让大量选中下的点选更快结束一帧布局。
    internal func reloadItemsForSelectionChange(at indexPaths: [IndexPath], completion: @escaping (Bool) -> Void) {
        guard !indexPaths.isEmpty else {
            completion(true)
            return
        }
        UIView.performWithoutAnimation {
            self.collectionView.performBatchUpdates({
                self.collectionView.reloadItems(at: indexPaths)
            }, completion: completion)
        }
    }

    /// 滑动手势等高频路径：无动画、无 batch，直接 `reloadItems`。
    internal func reloadSelectionCellsWithoutAnimation(at indexPaths: [IndexPath]) {
        guard !indexPaths.isEmpty else { return }
        UIView.performWithoutAnimation {
            self.collectionView.reloadItems(at: indexPaths)
        }
    }

    /// - Returns: 序号发生变化的其它资源的 `localIdentifier`（不含本次点选的那张若其为取消选中）。
    internal func toggle(photo: PHAsset) -> [String] {
        let id = photo.localIdentifier
        let wasSelected = selectionState.contains(id)
        if wasSelected, anchorPhoto?.localIdentifier == id {
            anchorPhoto = nil
        }
        let updatedIDs = selectionState.toggle(id: id)
        if wasSelected {
            selectedAssetByID.removeValue(forKey: id)
        } else {
            selectedAssetByID[id] = photo
        }
        return updatedIDs
    }

    /// 选择指定范围的照片（根据方向分配顺序）
    internal func selectRange(from startIndex: Int, to endIndex: Int, reverse: Bool) {
        var indexPaths: [IndexPath] = []
        // 归一化范围并根据方向决定追加顺序
        let low = min(startIndex, endIndex)
        let high = max(startIndex, endIndex)
        let baseRange = low...high
        let indices: [Int] = reverse ? Array(baseRange.reversed()) : Array(baseRange)

        for index in indices {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            if selectionState.insertIfAbsent(id: asset.localIdentifier) {
                selectedAssetByID[asset.localIdentifier] = asset
                indexPaths.append(IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didSelectItemAt: IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didSelectItemAt: asset)
            }
        }

        if !indexPaths.isEmpty {
            reloadItemsForSelectionChange(at: indexPaths) { _ in
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
        }
    }

    /// 取消选择指定范围的照片（根据方向分配顺序）
    internal func deselectRange(from startIndex: Int, to endIndex: Int) {
        var explicitIndexPaths: [IndexPath] = []
        var rankChangedIDs = Set<String>()
        // 根据方向决定追加顺序
        let indices = startIndex <= endIndex ? Array(startIndex...endIndex) : Array(endIndex...startIndex).reversed()

        for index in indices {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            if selectionState.contains(asset.localIdentifier) {
                rankChangedIDs.formUnion(toggle(photo: asset))
                explicitIndexPaths.append(IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: IndexPath(item: index, section: 0))
                delegate?.photoGridView(self, didDeselectItemAt: asset)
            }
        }

        if !explicitIndexPaths.isEmpty {
            let toReload = indexPathsMergingExplicitAndVisibleRankChanges(
                rankChangedIDs: rankChangedIDs,
                explicit: explicitIndexPaths
            )
            reloadItemsForSelectionChange(at: toReload) { _ in
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
        }
    }

    /// O(1) 查找照片在自定义排序中的下标
    internal func getCustomOrderIndex(for photo: PHAsset) -> Int {
        return customOrderIndexCache[photo.localIdentifier] ?? -1
    }

    func sort() throws -> [PHAsset] {
        let input = albumSession?.tagFilteredMembers() ?? []
        return try PhotoAnchorSortLogic.sortedAssets(
            in: input,
            selectedPhotos: selectedPhotos,
            anchorPhoto: anchorPhoto
        )
    }

    func clearSelected() {
        selectionState.clear()
        selectedAssetByID.removeAll()
        selectedStart = nil
        selectedEnd = nil
        anchorPhoto = nil  // 清除锚点
        delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
        collectionView.reloadData()
        syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
    }

    /// 全选所有可见照片
    func selectAll() {
        selectedStart = nil
        selectedEnd = nil
        anchorPhoto = nil
        selectionState.replaceAll(orderedIDs: visibleAssets.map(\.localIdentifier))
        selectedAssetByID = Dictionary(uniqueKeysWithValues: visibleAssets.map { ($0.localIdentifier, $0) })

        delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
        collectionView.reloadData()
        syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
    }

    // MARK: - Public Methods

    /// 更新可见资产（仅自定义排序且支持层级时应用折叠过滤）
    internal func updateVisibleAssets() {
        guard let session = albumSession else { return }
        let newVisibleAssets = session.visibleRowsForGrid()

        // 只在数据真正变化时才更新
        if newVisibleAssets.count != visibleAssets.count ||
           !newVisibleAssets.elementsEqual(visibleAssets, by: { $0.localIdentifier == $1.localIdentifier }) {
            PhotoCell.cachingManager.stopCachingImagesForAllAssets()
            visibleAssets = newVisibleAssets
            preloadCustomOrderCache()
            preloadDateTextCache()
            if sortPreference == .custom, supportsHierarchyNumbering {
                prewarmHierarchyCache(for: newVisibleAssets)
            }
            collectionView.reloadData()
            syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
        }
    }

    /// 预构建自定义排序索引字典，将 O(n) 线性搜索降为 O(1)
    func invalidateCustomOrderCache() {
        customOrderIndexCache.removeAll()
    }
    internal func invalidateDateTextCache() {
        dateTextCache.removeAll()
    }
    internal func preloadCustomOrderCache() {
        guard customOrderIndexCache.isEmpty else { return }
        guard let collection = currentCollection else {
            var dict = [String: Int](minimumCapacity: assets.count)
            for (i, asset) in assets.enumerated() {
                dict[asset.localIdentifier] = i
            }
            customOrderIndexCache = dict
            return
        }
        // 与系统「相簿内默认顺序」一致（`fetch` 无 sortDescriptors）；后台构建避免阻塞主线程。
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fetched = PHAsset.fetchAssets(in: collection, options: nil)
            var dict = [String: Int](minimumCapacity: fetched.count)
            fetched.enumerateObjects { asset, index, _ in
                dict[asset.localIdentifier] = index
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard self.customOrderIndexCache.isEmpty else { return }
                self.customOrderIndexCache = dict
                self.collectionView.reloadData()
            }
        }
    }
    internal func preloadDateTextCache() {
        guard dateTextCache.isEmpty else { return }
        var dict = [String: (creation: String, modification: String)](minimumCapacity: assets.count)
        for asset in assets {
            let creation = Self.displayDateFormatter.string(from: asset.creationDate ?? Date())
            let modification = Self.displayDateFormatter.string(from: asset.modificationDate ?? asset.creationDate ?? Date())
            dict[asset.localIdentifier] = (creation: creation, modification: modification)
        }
        dateTextCache = dict
    }

    /// 批量预计算层级信息并写入缓存（一次计算整表，避免滚动时每 cell 重复 O(n) 计算）
    internal func prewarmHierarchyCache(for visible: [PHAsset]) {
        guard supportsHierarchyNumbering, albumSession != nil else { return }
        guard !assets.isEmpty else {
            hierarchyCache.removeAll()
            return
        }
        // 不可再用「缓存条数 >= assets 条数」跳过：删除相片后 assets 变少但旧缓存仍多，会沿用错误编号
        hierarchyCache.removeAll()
        guard let session = albumSession else { return }
        let (numbers, collapsed) = session.computeNumbersAndCollapsed(for: assets)
        for asset in assets {
            let id = asset.localIdentifier
            let text = numbers[id]
            let isCollapsed = collapsed[id] ?? false
            hierarchyCache[id] = (text: text, isCollapsed: isCollapsed)
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

}

// MARK: - UICollectionViewDataSource
extension PhotoGridView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return visibleAssets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = visibleAssets[indexPath.item]
        let isSelected = selectionState.contains(photo.localIdentifier)

        // 列数多时 cell 很小，跳过不可见的 UI 计算（层级、媒体图标、收藏等）
        let isCompact = columns >= 7

        if isCompact {
            cell.configure(
                with: photo,
                isSelected: isSelected,
                selectionIndex: nil,
                selectionMode: selectionMode,
                showFieldPrefixes: overlaySettings.showFieldPrefixes,
                compact: true
            )
        } else {
            let assetID = photo.localIdentifier
            let selectionIndex = selectionState.rank(for: assetID)
            let isAnchor = anchorPhoto?.localIdentifier == photo.localIdentifier
            var hierarchyText: String?
            var isHierarchyCollapsed: Bool = false

            if sortPreference == .custom, supportsHierarchyNumbering {
                if let cached = hierarchyCache[assetID] {
                    hierarchyText = cached.text
                    isHierarchyCollapsed = cached.isCollapsed
                } else {
                    // 缓存未命中时一次性计算整表并填满缓存，避免每次 cell 都做 O(n) 计算
                    if let session = albumSession {
                        let (numbers, collapsed) = session.computeNumbersAndCollapsed(for: assets)
                        for a in assets {
                            let id = a.localIdentifier
                            hierarchyCache[id] = (numbers[id], collapsed[id] ?? false)
                        }
                        hierarchyText = numbers[assetID]
                        isHierarchyCollapsed = collapsed[assetID] ?? false
                    }
                }
            }

            let customOrderNumber: Int?
            let creationDateText: String?
            let modificationDateText: String?
            switch sortPreference {
            case .creationDate, .modificationDate, .recentDate, .oldest, .newest:
                let orderIndex = getCustomOrderIndex(for: photo)
                if overlaySettings.overlayEnabled && overlaySettings.showCustomOrderInDateSort {
                    customOrderNumber = orderIndex >= 0 ? (orderIndex + 1) : nil
                } else {
                    customOrderNumber = nil
                }
                creationDateText = nil
                modificationDateText = nil
            case .custom:
                customOrderNumber = indexPath.item + 1
                if overlaySettings.overlayEnabled {
                    let texts = dateTextCache[assetID]
                    creationDateText = overlaySettings.showCreationDateInCustom ? texts?.creation : nil
                    modificationDateText = overlaySettings.showModificationDateInCustom ? texts?.modification : nil
                } else {
                    creationDateText = nil
                    modificationDateText = nil
                }
            }

            cell.configure(
                with: photo,
                isSelected: isSelected,
                selectionIndex: selectionIndex,
                selectionMode: selectionMode,
                customOrderNumber: customOrderNumber,
                creationDateText: creationDateText,
                modificationDateText: modificationDateText,
                showFieldPrefixes: overlaySettings.showFieldPrefixes,
                isAnchor: isAnchor,
                hierarchyText: hierarchyText,
                isHierarchyCollapsed: isHierarchyCollapsed
            )
        }
        return cell
    }
}

