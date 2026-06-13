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

enum PhotoGridQuickJumpMode: CaseIterable {
    case selection
    case hierarchyBranch
    case unleveled

    var title: String {
        switch self {
        case .selection:
            return "选区"
        case .hierarchyBranch:
            return "分支"
        case .unleveled:
            return "无级"
        }
    }

    var iconName: String {
        switch self {
        case .selection:
            return "checkmark.circle"
        case .hierarchyBranch:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .unleveled:
            return "0.circle"
        }
    }
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
    /// 层级快捷展开/收起：与系统列表 batch 一致的时长与曲线
    static let hierarchyBatchAnimationDuration: TimeInterval = 0.35
    static let hierarchyLargeChangeReloadThreshold = 120
}


class PhotoGridView: UIView {
    private let overlaySettings = OverlayDisplaySettings.shared
    private var overlaySettingsObserver: NSObjectProtocol?
    private var hierarchyCollapseSettingsObserver: NSObjectProtocol?
    private var hierarchyToolbarRefreshPending = false
    /// 层级快捷按钮：避免连续点击叠加重入 `performBatchUpdates`
    private var isHierarchyShortcutVisibleAssetsAnimating = false
    private var hierarchyShortcutNeedsVisibleRefresh = false
    private var isApplyingSnapshot = false

    public var assets: [PHAsset] = [] {
        didSet {
            guard !isApplyingSnapshot else { return }
            let oldAssetIDs = assetIDs
            rebuildAssetLookup()
            handleAssetsDidChange(idsChanged: oldAssetIDs != assetIDs)
        }
    }

    func apply(snapshot: PhotoCollectionSnapshot) {
        applyAssets(
            snapshot.visibleAssets,
            assetIDs: snapshot.visibleAssetIDs,
            assetByID: snapshot.assetByID
        )
    }

    private func applyAssets(
        _ assets: [PHAsset],
        assetIDs: [String],
        assetByID: [String: PHAsset]
    ) {
        let oldAssetIDs = self.assetIDs
        isApplyingSnapshot = true
        self.assets = assets
        isApplyingSnapshot = false
        self.assetIDs = assetIDs
        self.assetByID = assetByID
        assetIndexByID.removeAll(keepingCapacity: true)
        assetIndexByID.reserveCapacity(assetIDs.count)
        for (index, id) in assetIDs.enumerated() {
            assetIndexByID[id] = index
        }
        handleAssetsDidChange(idsChanged: oldAssetIDs != assetIDs)
    }

    private func handleAssetsDidChange(idsChanged: Bool) {
        if idsChanged {
            clearSelectionStateForDataSourceChange()
        }
        invalidateQuickJumpTargetCache()
        invalidateCustomOrderCache()
        invalidateDateTextCache()
        if idsChanged {
            hierarchyCache.removeAll()
            invalidateHierarchyEnablementCache()
        }
        updateVisibleAssets()
        // 删除节点后存储层级已校正，但可见序列可能不变（例如删的是折叠分支内未展示的项），须强制刷新编号 overlay
        if idsChanged, sortPreference == .custom, supportsHierarchyNumbering {
            collectionView.reloadData()
        }
        if sortPreference == .custom, supportsHierarchyNumbering {
            prewarmContextMenuHierarchyCacheIfNeeded()
            scheduleHierarchyToolbarRefresh()
        }
    }

    // 实际显示的照片（经过层级折叠过滤）
    private var visibleAssets: [PHAsset] = []
    private var assetIDs: [String] = []
    private var visibleAssetIDs: [String] = []
    private var assetByID: [String: PHAsset] = [:]
    private var assetIndexByID: [String: Int] = [:]
    private var visibleAssetIndexByID: [String: Int] = [:]

    public var delegate: PhotoGridViewDelegate?

    public weak var scrollDelegate: UIScrollViewDelegate?

    public var selectedAssets: [PHAsset] { selectedPhotos }

    public var selectedAssetIDs: [String] {
        allVisibleSelectionActive ? visibleAssetIDs : selectionState.orderedIDs
    }

    public func materializeSelectionIfNeeded() {
        expandAllVisibleSelectionIfNeeded()
    }

    public var selectedAssetCount: Int {
        allVisibleSelectionActive ? visibleAssets.count : selectionState.count
    }

    public var hasSelectedAssets: Bool { selectedAssetCount > 0 }

    public var visibleAssetCount: Int { visibleAssets.count }

    public var selectedAssetIDSet: Set<String> {
        cachedSelectedIdentifierSet()
    }

    /// 与 `selectedAssets` 成员一致，用于 O(1) 成员判断而无需构造 `[PHAsset]`。
    public var selectedMembershipIdentifiers: Set<String> {
        selectedAssetIDSet
    }

    private static let maxSelectedAssetsInDelegatePayload = 512

    /// 通知 delegate 时避免在数万选中下分配整表 `[PHAsset]`。
    private var selectedAssetsForDelegateNotification: [PHAsset] {
        if selectedAssetCount > Self.maxSelectedAssetsInDelegatePayload { return [] }
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

    /// 记录范围选择起点照片的初始选中状态，用于决定范围操作是选中还是取消选中
    internal var rangeInitialSelectionState: Bool = false

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
        if allVisibleSelectionActive {
            return visibleAssets
        }
        if selectedAssetByID.count < selectionState.count {
            for id in selectionState.orderedIDs {
                if selectedAssetByID[id] == nil, let asset = assetByID[id] {
                    selectedAssetByID[id] = asset
                }
            }
        }
        var result: [PHAsset] = []
        result.reserveCapacity(selectionState.count)
        for id in selectionState.orderedIDs {
            guard let asset = selectedAssetByID[id] else { continue }
            result.append(asset)
        }
        return result
    }

    private var selectionState = PhotoGridSelectionState()
    private var allVisibleSelectionActive = false
    /// 仅缓存「当前在选中集中」的资源，供 `selectedPhotos` 与 delegate 使用。
    private var selectedAssetByID: [String: PHAsset] = [:]
    private var selectedIdentifierSetCache: Set<String>?

    /// 快跳定位共享锚点（可见下标）；`nil` 表示按当前视口边界取下一目标。
    private var lastQuickNavJumpIndex: Int?
    private var quickJumpTargetCache: [PhotoGridQuickJumpMode: [Int]] = [:]
    private var hierarchyEffectiveLevelsCache: [String: Int]?
    private var hierarchyNodeJumpTargetsCache: [HierarchyNodeJumpTarget]?
    private var hierarchySiblingJumpIndexCache: PhotoNumberingLogic.HierarchySiblingJumpIndex?
    private var hierarchyLevelJumpDestinationCache: [HierarchyLevelJumpDestinationCacheKey: HierarchyLevelJumpDestinationCacheValue] = [:]
private var cachedCanCollapseAll: Bool?
private var cachedCanExpandAll: Bool?
    private var contextMenuPreviousLevelCache: [Int]?
    private static var didPrewarmContextMenuResources = false
    private static var contextMenuSymbolCache: [String: UIImage] = [:]
    /// 由控制器注入：锚点或目标链变化时刷新底部工具条上按钮的 `isEnabled`。
    var onQuickJumpToolbarRefresh: (() -> Void)?
    /// 旧入口保留给现有控制器代码，内部转发到统一快跳刷新。
    var onSelectionQuickNavToolbarRefresh: (() -> Void)?
    /// 由控制器注入：刷新底栏层级展开/收起按钮状态
    var onHierarchyToolbarRefresh: (() -> Void)?
    /// 旧入口保留给现有控制器代码，内部转发到统一快跳刷新。
    var onHierarchyBranchNavToolbarRefresh: (() -> Void)?

    // 当前锚点照片
    private var anchorPhoto: PHAsset?

    // 当前层级参照照片（用于“设为某项子级/插入到某级后面”）

    // 当前排序方式
    public var sortPreference: PhotoSortPreference = .custom {
        didSet {
            if oldValue != sortPreference {
                hierarchyCache.removeAll()
                invalidateQuickJumpTargetCache()
            }
        }
    }

    // 当前相册引用，用于获取自定义排序数据
    public var currentCollection: PHAssetCollection? {
        didSet {
            hierarchyCache.removeAll()
            invalidateQuickJumpTargetCache()
            customOrderIndexCache.removeAll()
            dateTextCache.removeAll()
        }
    }

    /// 是否支持层级编号功能。首页（图库）不支持，相册内支持。
    public var supportsHierarchyNumbering: Bool = true {
        didSet {
            if oldValue != supportsHierarchyNumbering {
                invalidateQuickJumpTargetCache()
            }
        }
    }

    /// 是否隐藏无层级照片（level == 0），仅对自定义排序相册生效
    public var hideUnleveledAssets: Bool = false {
        didSet {
            guard oldValue != hideUnleveledAssets else { return }
            setVisibleAssets(computeVisibleAssets(), animated: true, hierarchyNumbersUnchanged: true)
        }
    }

    private let numberingService = PhotoNumberingService.shared

    // 层级信息缓存，避免重复计算
    private var hierarchyCache: [String: (text: String?, isCollapsed: Bool)] = [:]

    // 自定义排序索引缓存：assetID -> index，O(1) 查找
    private var customOrderIndexCache: [String: Int] = [:]
    // 日期文本缓存：assetID -> (creationText, modificationText)
    private var dateTextCache: [String: (creation: String, modification: String)] = [:]
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

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
        observeOverlayAndHierarchySettings()
        prewarmContextMenuResourcesIfNeeded()
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

    private func observeOverlayAndHierarchySettings() {
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
        }
    }

    private func rebuildAssetLookup() {
        assetIDs.removeAll(keepingCapacity: true)
        assetByID.removeAll(keepingCapacity: true)
        assetIndexByID.removeAll(keepingCapacity: true)
        assetIDs.reserveCapacity(assets.count)
        assetByID.reserveCapacity(assets.count)
        assetIndexByID.reserveCapacity(assets.count)
        for (index, asset) in assets.enumerated() {
            let id = asset.localIdentifier
            assetIDs.append(id)
            assetByID[id] = asset
            assetIndexByID[id] = index
        }
    }

    private func setVisibleAssetsCache(_ assets: [PHAsset]) {
        visibleAssets = assets
        visibleAssetIDs = assets.map(\.localIdentifier)
        visibleAssetIndexByID.removeAll(keepingCapacity: true)
        visibleAssetIndexByID.reserveCapacity(visibleAssetIDs.count)
        for (index, id) in visibleAssetIDs.enumerated() {
            visibleAssetIndexByID[id] = index
        }
        contextMenuPreviousLevelCache = nil
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

    private func prewarmContextMenuResourcesIfNeeded() {
        guard !Self.didPrewarmContextMenuResources else { return }
        Self.didPrewarmContextMenuResources = true
        DispatchQueue.main.async {
            let symbolNames = [
                "anchor.slash",
                "anchor",
                "tag",
                "doc.on.clipboard",
                "trash",
                "list.number",
                "arrow.right.to.line",
                "list.bullet.indent",
                "arrow.left",
                "arrow.right",
                "xmark.circle",
                "rectangle.expand.vertical",
                "rectangle.compress.vertical"
            ]
            for name in symbolNames {
                Self.contextMenuSymbolCache[name] = UIImage(systemName: name)
            }
            _ = UIAction(title: "", image: nil) { _ in }
            _ = UIMenu(title: "", children: [])
            _ = UIDeferredMenuElement { completion in completion([]) }
        }
    }

    private func contextMenuImage(_ systemName: String) -> UIImage? {
        if let image = Self.contextMenuSymbolCache[systemName] {
            return image
        }
        let image = UIImage(systemName: systemName)
        Self.contextMenuSymbolCache[systemName] = image
        return image
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
                    panInitialSelectionState = isAssetSelected(asset)

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
                    let isCurrentlySelected = isAssetSelected(currentAsset)
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
                    let isCurrentlySelected = isAssetSelected(asset)
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

    /// 根据 collectionView 的 indexPath 获取对应资源（数据源为 visibleAssets）
    private func getAsset(at indexPath: IndexPath) -> PHAsset? {
        guard indexPath.item < visibleAssets.count else { return nil }
        return visibleAssets[indexPath.item]
    }

    private func nearestVisibleAsset(to point: CGPoint) -> PHAsset? {
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
    private func indexPathsMergingExplicitAndVisibleRankChanges(
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
    private func reloadItemsForSelectionChange(at indexPaths: [IndexPath], completion: @escaping (Bool) -> Void) {
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
    private func reloadSelectionCellsWithoutAnimation(at indexPaths: [IndexPath]) {
        guard !indexPaths.isEmpty else { return }
        UIView.performWithoutAnimation {
            self.collectionView.reloadItems(at: indexPaths)
        }
    }

    private func reloadVisibleSelectionCellsWithoutAnimation() {
        let indexPaths = collectionView.indexPathsForVisibleItems.filter { $0.section == 0 && $0.item < visibleAssets.count }
        reloadSelectionCellsWithoutAnimation(at: indexPaths)
    }

    private func invalidateSelectedIdentifierSetCache() {
        selectedIdentifierSetCache = nil
        invalidateQuickJumpTargetCache(for: .selection)
    }

    private func cachedSelectedIdentifierSet() -> Set<String> {
        if let cache = selectedIdentifierSetCache { return cache }
        if allVisibleSelectionActive {
            let ids = Set(visibleAssetIDs)
            selectedIdentifierSetCache = ids
            return ids
        }
        let ids = selectionState.selectedIdentifierSet
        selectedIdentifierSetCache = ids
        return ids
    }

    private func isAssetSelected(_ asset: PHAsset) -> Bool {
        allVisibleSelectionActive || selectionState.contains(asset.localIdentifier)
    }

    private func selectionRank(for asset: PHAsset, visibleIndex: Int? = nil) -> Int? {
        if allVisibleSelectionActive {
            if let visibleIndex { return visibleIndex + 1 }
            return visibleAssets.firstIndex(of: asset).map { $0 + 1 }
        }
        return selectionState.rank(for: asset.localIdentifier)
    }

    private func expandAllVisibleSelectionIfNeeded() {
        guard allVisibleSelectionActive else { return }
        var assetsByID: [String: PHAsset] = [:]
        assetsByID.reserveCapacity(visibleAssets.count)
        for asset in visibleAssets {
            assetsByID[asset.localIdentifier] = asset
        }
        selectionState.replaceAll(orderedIDs: visibleAssetIDs)
        selectedAssetByID = assetsByID
        allVisibleSelectionActive = false
        invalidateSelectedIdentifierSetCache()
    }

    private func clearSelectionStateForDataSourceChange() {
        allVisibleSelectionActive = false
        selectionState.clear()
        selectedAssetByID.removeAll()
        invalidateSelectedIdentifierSetCache()
        selectedStart = nil
        selectedEnd = nil
        rangeInitialSelectionState = false
        anchorPhoto = nil
    }

    /// - Returns: 序号发生变化的其它资源的 `localIdentifier`（不含本次点选的那张若其为取消选中）。
    internal func toggle(photo: PHAsset) -> [String] {
        expandAllVisibleSelectionIfNeeded()
        let id = photo.localIdentifier
        let wasSelected = selectionState.contains(id)
        if wasSelected, anchorPhoto?.localIdentifier == id {
            anchorPhoto = nil
        }
        let updatedIDs = selectionState.toggle(id: id)
        invalidateSelectedIdentifierSetCache()
        if wasSelected {
            selectedAssetByID.removeValue(forKey: id)
        } else {
            selectedAssetByID[id] = photo
        }
        return updatedIDs
    }

    /// 选择指定范围的照片（根据方向分配顺序）
    private func selectRange(from startIndex: Int, to endIndex: Int, reverse: Bool) {
        expandAllVisibleSelectionIfNeeded()
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
                invalidateSelectedIdentifierSetCache()
                selectedAssetByID[asset.localIdentifier] = asset
                indexPaths.append(IndexPath(item: index, section: 0))
            }
        }

        if !indexPaths.isEmpty {
            reloadItemsForSelectionChange(at: indexPaths) { _ in
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
        }
    }

    /// 取消选择指定范围的照片
    private func deselectRange(from startIndex: Int, to endIndex: Int) {
        expandAllVisibleSelectionIfNeeded()
        var explicitIndexPaths: [IndexPath] = []
        var idsToRemove = Set<String>()

        for index in min(startIndex, endIndex)...max(startIndex, endIndex) {
            guard index < visibleAssets.count else { continue }
            let asset = visibleAssets[index]
            let id = asset.localIdentifier
            if isAssetSelected(asset) {
                idsToRemove.insert(id)
                selectedAssetByID.removeValue(forKey: id)
                if anchorPhoto?.localIdentifier == id {
                    anchorPhoto = nil
                }
                explicitIndexPaths.append(IndexPath(item: index, section: 0))
            }
        }

        guard !idsToRemove.isEmpty else { return }

        let rankChangedIDs = Set(selectionState.removeMultiple(ids: idsToRemove))
        invalidateSelectedIdentifierSetCache()
        let toReload = indexPathsMergingExplicitAndVisibleRankChanges(
            rankChangedIDs: rankChangedIDs,
            explicit: explicitIndexPaths
        )
        reloadItemsForSelectionChange(at: toReload) { _ in
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
        }
    }

    /// O(1) 查找照片在自定义排序中的下标
    private func getCustomOrderIndex(for photo: PHAsset) -> Int {
        return customOrderIndexCache[photo.localIdentifier] ?? -1
    }

    func sort() throws -> [PHAsset] {
        expandAllVisibleSelectionIfNeeded()
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
        allVisibleSelectionActive = false
        selectionState.clear()
        invalidateSelectedIdentifierSetCache()
        selectedAssetByID.removeAll()
        selectedStart = nil
        selectedEnd = nil
        rangeInitialSelectionState = false
        anchorPhoto = nil  // 清除锚点
        delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
        reloadVisibleSelectionCellsWithoutAnimation()
    }

    /// 全选所有可见照片
    func selectAll() {
        selectedStart = nil
        selectedEnd = nil
        rangeInitialSelectionState = false
        anchorPhoto = nil

        allVisibleSelectionActive = !visibleAssets.isEmpty
        selectionState.clear()
        invalidateSelectedIdentifierSetCache()
        selectedAssetByID.removeAll(keepingCapacity: true)

        delegate?.photoGridView(self, didSelectedItems: selectedAssetsForDelegateNotification)
        reloadVisibleSelectionCellsWithoutAnimation()
    }

    // MARK: - Public Methods

    /// 更新可见资产（仅自定义排序且支持层级时应用折叠过滤）
    private func updateVisibleAssets(animated: Bool = false, completion: (() -> Void)? = nil) {
        setVisibleAssets(computeVisibleAssets(), animated: animated, completion: completion)
    }

    private func computeVisibleAssets() -> [PHAsset] {
        var result: [PHAsset]
        if sortPreference == .custom, supportsHierarchyNumbering, let collection = currentCollection {
            result = numberingService.visibleAssets(from: assets, in: collection)
            if hideUnleveledAssets {
                result = result.filter { numberingService.level(for: $0, in: collection) > 0 }
            }
        } else {
            result = assets
        }
        return result
    }

    private func setVisibleAssets(
        _ newVisibleAssets: [PHAsset],
        animated: Bool,
        hierarchyNumbersUnchanged: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let unchanged = newVisibleAssets.count == visibleAssets.count
            && newVisibleAssets.elementsEqual(visibleAssets, by: { $0.localIdentifier == $1.localIdentifier })
        guard !unchanged else {
            if sortPreference == .custom, supportsHierarchyNumbering {
                if hierarchyNumbersUnchanged {
                    syncHierarchyCacheCollapsedFlags()
                } else {
                    prewarmHierarchyCache(for: newVisibleAssets)
                }
            }
            UIView.performWithoutAnimation {
                collectionView.reloadData()
            }
            invalidateQuickJumpTargetCache()
            syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
            scheduleHierarchyToolbarRefresh()
            completion?()
            return
        }

        if !hierarchyNumbersUnchanged {
            PhotoCell.cachingManager.stopCachingImagesForAllAssets()
            preloadCustomOrderCache()
            preloadDateTextCache()
        }
        if sortPreference == .custom, supportsHierarchyNumbering {
            if hierarchyNumbersUnchanged {
                syncHierarchyCacheCollapsedFlags()
            } else {
                prewarmHierarchyCache(for: newVisibleAssets)
            }
        }

        guard animated else {
            setVisibleAssetsCache(newVisibleAssets)
            collectionView.reloadData()
            invalidateQuickJumpTargetCache()
            syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
            scheduleHierarchyToolbarRefresh()
            completion?()
            return
        }

        applyVisibleAssetsChangeAnimated(to: newVisibleAssets, completion: completion)
    }

    private func applyVisibleAssetsChangeAnimated(to newVisibleAssets: [PHAsset], completion: (() -> Void)?) {
        let oldVisible = visibleAssets
        let diff = visibleAssetsBatchChanges(from: oldVisible, to: newVisibleAssets)
        let changeCount = diff.deletes.count + diff.inserts.count
        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            self.syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset()
            self.scheduleHierarchyToolbarRefresh()
            completion?()
        }

        if changeCount > PhotoGridConstants.hierarchyLargeChangeReloadThreshold {
            UIView.transition(
                with: collectionView,
                duration: PhotoGridConstants.hierarchyBatchAnimationDuration,
                options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]
            ) { [weak self] in
                guard let self else { return }
                self.setVisibleAssetsCache(newVisibleAssets)
                self.collectionView.reloadData()
                self.invalidateQuickJumpTargetCache()
            } completion: { _ in finish() }
            return
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(PhotoGridConstants.hierarchyBatchAnimationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        collectionView.performBatchUpdates { [weak self] in
            guard let self else { return }
            self.setVisibleAssetsCache(newVisibleAssets)
            self.invalidateQuickJumpTargetCache()
            if !diff.deletes.isEmpty {
                self.collectionView.deleteItems(at: diff.deletes)
            }
            if !diff.inserts.isEmpty {
                self.collectionView.insertItems(at: diff.inserts)
            }
        } completion: { [weak self] _ in
            guard let self else { return }
            if !diff.reloads.isEmpty {
                UIView.performWithoutAnimation {
                    self.collectionView.reloadItems(at: diff.reloads)
                }
            }
            finish()
        }
        CATransaction.commit()
    }

    /// 删除用旧下标；插入用「删除后、按最终顺序」的下标；刷新在 batch 外执行，避免与 delete 冲突
    private func visibleAssetsBatchChanges(
        from oldVisible: [PHAsset],
        to newVisible: [PHAsset]
    ) -> (deletes: [IndexPath], inserts: [IndexPath], reloads: [IndexPath]) {
        let oldIDs = Set(oldVisible.map(\.localIdentifier))
        let newIDs = Set(newVisible.map(\.localIdentifier))

        let deletes = oldVisible.enumerated().compactMap { index, asset in
            newIDs.contains(asset.localIdentifier) ? nil : IndexPath(item: index, section: 0)
        }

        let insertFinalIndices = newVisible.enumerated().compactMap { index, asset in
            oldIDs.contains(asset.localIdentifier) ? nil : index
        }

        // 预计算"保留项"前缀和，使 insert IndexPath 计算从 O(n²) 降为 O(n)
        var keptPrefix = [Int](repeating: 0, count: newVisible.count + 1)
        for i in 0..<newVisible.count {
            keptPrefix[i + 1] = keptPrefix[i] + (oldIDs.contains(newVisible[i].localIdentifier) ? 1 : 0)
        }
        let inserts = insertFinalIndices.enumerated().map { (insertIdx, finalIndex) in
            IndexPath(item: keptPrefix[finalIndex] + insertIdx, section: 0)
        }

        let reloads = newVisible.enumerated().compactMap { index, asset in
            oldIDs.contains(asset.localIdentifier) ? IndexPath(item: index, section: 0) : nil
        }

        return (deletes, inserts, reloads)
    }

    private func fullOrderIndex(for assetID: String) -> Int? {
        if let cached = customOrderIndexCache[assetID] { return cached }
        return assets.firstIndex(where: { $0.localIdentifier == assetID })
    }

    /// 预构建自定义排序索引字典，将 O(n) 线性搜索降为 O(1)
    func invalidateCustomOrderCache() {
        customOrderIndexCache.removeAll()
    }
    private func invalidateDateTextCache() {
        dateTextCache.removeAll()
    }
    private func preloadCustomOrderCache() {
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
    private func preloadDateTextCache() {
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
    private func prewarmHierarchyCache(for visible: [PHAsset]) {
        guard supportsHierarchyNumbering, let collection = currentCollection else { return }
        guard !assets.isEmpty else {
            hierarchyCache.removeAll()
            return
        }
        // 不可再用「缓存条数 >= assets 条数」跳过：删除相片后 assets 变少但旧缓存仍多，会沿用错误编号
        hierarchyCache.removeAll()
        let (numbers, collapsed) = numberingService.computeNumbersAndCollapsed(for: assets, in: collection)
        for asset in assets {
            let id = asset.localIdentifier
            let text = numbers[id]
            let isCollapsed = collapsed[id] ?? false
            hierarchyCache[id] = (text: text, isCollapsed: isCollapsed)
        }
        invalidateHierarchyEnablementCache()
    }

    /// 仅折叠状态变化时同步角标，编号字符串不变
    private func syncHierarchyCacheCollapsedFlags() {
        guard supportsHierarchyNumbering, let collection = currentCollection else { return }
        if hierarchyCache.isEmpty {
            prewarmHierarchyCache(for: visibleAssets)
            return
        }
        let collapsed = numberingService.collapsedStates(in: collection)
        for (id, entry) in hierarchyCache {
            hierarchyCache[id] = (text: entry.text, isCollapsed: collapsed[id] ?? false)
        }
    }

    /// 刷新层级显示（层级/顺序变更：重算编号与可见集）
    func refreshParagraphDisplay(animated: Bool = false, completion: (() -> Void)? = nil) {
        hierarchyCache.removeAll()
        invalidateQuickJumpTargetCache()
        updateVisibleAssets(animated: animated, completion: completion)
    }

    /// 底栏快捷折叠/展开：只更新可见集与折叠角标，不重算整表编号
    private func applyHierarchyShortcutVisibilityChange(animated: Bool, completion: (() -> Void)? = nil) {
        setVisibleAssets(
            computeVisibleAssets(),
            animated: animated,
            hierarchyNumbersUnchanged: true,
            completion: completion
        )
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

        let assetsToDeleteSet = Set(assetsToDelete.map { $0.localIdentifier })

        // CollectionView 数据源是 visibleAssets，必须用 visibleAssets 的索引
        let indexPathsToDelete = visibleAssets.enumerated().compactMap { index, asset in
            assetsToDeleteSet.contains(asset.localIdentifier) ? IndexPath(item: index, section: 0) : nil
        }

        collectionView.performBatchUpdates {
            self.assets.removeAll { assetsToDeleteSet.contains($0.localIdentifier) }
            invalidateCustomOrderCache()
            if sortPreference == .custom, supportsHierarchyNumbering, let collection = currentCollection {
                let valid = Set(self.assets.map(\.localIdentifier))
                numberingService.cleanupInvalidNodes(validAssetIDs: valid, orderedAssets: self.assets, for: collection)
                hierarchyCache.removeAll()
                setVisibleAssetsCache(computeVisibleAssets())
            } else {
                setVisibleAssetsCache(assets)
            }
            invalidateQuickJumpTargetCache()

            for asset in assetsToDelete {
                let id = asset.localIdentifier
                if allVisibleSelectionActive {
                    expandAllVisibleSelectionIfNeeded()
                }
                selectionState.removeIdentifierWithoutRankShift(id: id)
                invalidateSelectedIdentifierSetCache()
                selectedAssetByID.removeValue(forKey: id)
                if anchorPhoto?.localIdentifier == id {
                    anchorPhoto = nil
                }
            }

            collectionView.deleteItems(at: indexPathsToDelete)
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
        let isSelected = isAssetSelected(photo)

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
            let selectionIndex = selectionRank(for: photo, visibleIndex: indexPath.item)
            let isAnchor = anchorPhoto?.localIdentifier == photo.localIdentifier
            var hierarchyText: String?
            var isHierarchyCollapsed: Bool = false

            if sortPreference == .custom, supportsHierarchyNumbering {
                if let cached = hierarchyCache[assetID] {
                    hierarchyText = cached.text
                    isHierarchyCollapsed = cached.isCollapsed
                } else {
                    // 缓存未命中时一次性计算整表并填满缓存，避免每次 cell 都做 O(n) 计算
                    if let collection = currentCollection {
                        let (numbers, collapsed) = numberingService.computeNumbersAndCollapsed(for: assets, in: collection)
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

// MARK: - UICollectionViewDataSourcePrefetching
extension PhotoGridView: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let cellSize = effectiveCellSize(for: collectionView)
        let scale = collectionView.window?.screen.scale ?? collectionView.traitCollection.displayScale
        let targetSize = PhotoCell.thumbnailSize(for: cellSize, scale: scale)
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
        let scale = collectionView.window?.screen.scale ?? collectionView.traitCollection.displayScale
        let targetSize = PhotoCell.thumbnailSize(for: cellSize, scale: scale)
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

        let wasSelected = isAssetSelected(photo)
        let rankChanged = Set(toggle(photo: photo))
        let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
            rankChangedIDs: rankChanged,
            explicit: [indexPath]
        )
        reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
            if wasSelected {
                self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            } else {
                self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                self.delegate?.photoGridView(self, didSelectItemAt: photo)
            }
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
        }
    }

    private func handleRangeSelection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击选择
        guard !isSlidingSelectionEnabled else { return }

        let index = indexPath.item

        if selectedStart == nil {
            // 第一次点击：记录起点和初始选中状态，toggle 提供即时反馈
            selectedStart = index
            rangeInitialSelectionState = isAssetSelected(photo)
            let rankChanged = Set(toggle(photo: photo))
            let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
                rankChangedIDs: rankChanged,
                explicit: [indexPath]
            )
            reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
                if self.rangeInitialSelectionState {
                    self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
                    self.delegate?.photoGridView(self, didDeselectItemAt: photo)
                } else {
                    self.delegate?.photoGridView(self, didSelectItemAt: indexPath)
                    self.delegate?.photoGridView(self, didSelectItemAt: photo)
                }
                self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
            }
        } else {
            // 第二次点击：根据起点初始状态决定选中还是取消选中整个范围
            selectedEnd = index
            let startIndex = min(selectedStart!, selectedEnd!)
            let endIndex = max(selectedStart!, selectedEnd!)

            if rangeInitialSelectionState {
                // 起点原本已选中 → 取消选中整个范围
                deselectRange(from: startIndex, to: endIndex)
            } else {
                // 起点原本未选中 → 选中整个范围
                let reverse = selectedEnd! < selectedStart!
                selectRange(from: startIndex, to: endIndex, reverse: reverse)
            }

            selectedStart = nil
            selectedEnd = nil
            rangeInitialSelectionState = false
        }
    }

    private func handleDeselection(at indexPath: IndexPath, in collectionView: UICollectionView, with photo: PHAsset) {
        // 如果启用了滑动选择，则不处理点击取消选择
        guard !isSlidingSelectionEnabled else { return }

        let rankChanged = Set(toggle(photo: photo))
        let reloadIndexPaths = indexPathsMergingExplicitAndVisibleRankChanges(
            rankChangedIDs: rankChanged,
            explicit: [indexPath]
        )
        reloadItemsForSelectionChange(at: reloadIndexPaths) { _ in
            self.delegate?.photoGridView(self, didDeselectItemAt: indexPath)
            self.delegate?.photoGridView(self, didDeselectItemAt: photo)
            self.delegate?.photoGridView(self, didSelectedItems: self.selectedAssetsForDelegateNotification)
        }
        selectedStart = nil
        selectedEnd = nil
        rangeInitialSelectionState = false
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
        } else {
            clearQuickJumpAnchorForUserScroll()
        }

        scrollDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    // 新增：重写 scrollViewDidEndDragging 方法来恢复滚动
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !isSlidingSelectionEnabled {
            scrollView.isScrollEnabled = true
        }
        scrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        if !decelerate {
            onQuickJumpToolbarRefresh?()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidEndDecelerating?(scrollView)
        onQuickJumpToolbarRefresh?()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
        onQuickJumpToolbarRefresh?()
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
        let assetID = visibleAssetIDs[indexPath.item]
        let visibleIndex = indexPath.item
        let isCurrentAnchor = anchorPhoto?.localIdentifier == assetID

        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [self] _ in
            var anchorGroup: [UIMenuElement] = []
            var tailGroup: [UIMenuElement] = []

            // 锚点相关操作
            if isCurrentAnchor {
                let removeAnchorAction = UIAction(title: "取消锚点", image: contextMenuImage("anchor.slash")) { [weak self] _ in
                    guard let self else { return }
                    let oldAnchorID = self.anchorPhoto?.localIdentifier
                    self.anchorPhoto = nil
                    self.reloadAnchorCells(oldID: oldAnchorID, newID: nil)
                }
                anchorGroup.append(removeAnchorAction)
            } else {
                let setAnchorAction = UIAction(title: "设为锚点", image: contextMenuImage("anchor")) { [weak self] _ in
                    guard let self else { return }
                    let oldAnchorID = self.anchorPhoto?.localIdentifier
                    self.anchorPhoto = asset
                    self.reloadAnchorCells(oldID: oldAnchorID, newID: assetID)
                    self.delegate?.photoGridView(self, didSetAnchor: asset)
                }
                anchorGroup.append(setAnchorAction)
            }

            // 其他操作：添加标签 → 粘贴到此后方 → 删除（危险操作放最后）
            let tagAction = UIAction(title: "添加标签", image: contextMenuImage("tag")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.photoGridView(self, didRequestAddTagFor: asset)
            }
            tailGroup.append(tagAction)

            let pasteAction = UIAction(title: "粘贴到此后方", image: contextMenuImage("doc.on.clipboard")) { [weak self] _ in
                if let pasteAssets = AssetPasteboard.assetsFromPasteboard(), !pasteAssets.isEmpty {
                    self?.handlePasteToAfter(asset: asset, assets: pasteAssets)
                }
            }
            tailGroup.append(pasteAction)

            let deleteAction = UIAction(title: "删除", image: contextMenuImage("trash"), attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.photoGridView(self, didRequestDelete: asset)
            }
            tailGroup.append(deleteAction)

            var rootChildren: [UIMenuElement] = []
            if !anchorGroup.isEmpty {
                rootChildren.append(UIMenu(title: "锚点", image: contextMenuImage("anchor"), options: .displayInline, children: anchorGroup))
            }
            if sortPreference == .custom, supportsHierarchyNumbering, currentCollection != nil {
                rootChildren.append(UIDeferredMenuElement { completion in
                    completion([self.makeHierarchyContextMenu(asset: asset, assetID: assetID, visibleIndex: visibleIndex)])
                })
            }
            if !tailGroup.isEmpty {
                rootChildren.append(UIMenu(title: "其他", options: .displayInline, children: tailGroup))
            }
            return UIMenu(title: "", children: rootChildren)
        }
    }

    private func contextMenuPreviousLevel(at visibleIndex: Int, levels: [String: Int]) -> Int {
        if let cached = contextMenuPreviousLevelCache, visibleIndex < cached.count {
            return cached[visibleIndex]
        }
        guard visibleIndex > 0 else { return 0 }
        for index in stride(from: visibleIndex - 1, through: 0, by: -1) {
            let level = levels[visibleAssetIDs[index]] ?? 0
            if level > 0 {
                return level
            }
        }
        return 0
    }

    private func makeHierarchyContextMenu(asset: PHAsset, assetID: String, visibleIndex: Int) -> UIMenu {
        guard sortPreference == .custom, supportsHierarchyNumbering, let collection = currentCollection else {
            return UIMenu(title: "层级", children: [])
        }

        let levels = numberingService.levels(in: collection)
        let currLv = levels[assetID] ?? 0
        let prevLv = contextMenuPreviousLevel(at: visibleIndex, levels: levels)
        var hierarchyGroup: [UIMenuElement] = []

        if currLv == 0 {
            let setMain = UIAction(title: "设为主级", image: contextMenuImage("list.number")) { [weak self] _ in
                guard let self else { return }
                self.numberingService.setLevel(1, for: asset, in: collection)
                self.refreshParagraphDisplay()
            }
            hierarchyGroup.append(setMain)

            if prevLv > 0 {
                let setSame = UIAction(title: "设为同级", image: contextMenuImage("arrow.right.to.line")) { [weak self] _ in
                    guard let self else { return }
                    self.numberingService.setLevel(prevLv, for: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                let setSub = UIAction(title: "设为子级", image: contextMenuImage("list.bullet.indent")) { [weak self] _ in
                    guard let self else { return }
                    self.numberingService.setLevel(prevLv + 1, for: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyGroup.append(setSame)
                hierarchyGroup.append(setSub)
            }
        } else {
            if currLv > 1 {
                let promote = UIAction(title: "提升层级", image: contextMenuImage("arrow.left")) { [weak self] _ in
                    guard let self else { return }
                    self.numberingService.setLevel(currLv - 1, for: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyGroup.append(promote)
            }

            if currLv < prevLv + 1 {
                let demote = UIAction(title: "下降层级", image: contextMenuImage("arrow.right")) { [weak self] _ in
                    guard let self else { return }
                    self.numberingService.setLevel(currLv + 1, for: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyGroup.append(demote)
            }

            if currLv != prevLv && prevLv > 0 {
                let setSame = UIAction(title: "设为同级", image: contextMenuImage("arrow.right.to.line")) { [weak self] _ in
                    guard let self else { return }
                    self.numberingService.setLevel(prevLv, for: asset, in: collection)
                    self.refreshParagraphDisplay()
                }
                hierarchyGroup.append(setSame)
            }

            let clearAction = UIAction(title: "取消编号", image: contextMenuImage("xmark.circle"), attributes: .destructive) { [weak self] _ in
                guard let self, let idx = self.visibleAssetIndexByID[assetID] else { return }
                let latestLevels = self.numberingService.levels(in: collection)
                self.numberingService.beginBatchUpdates(for: collection)
                defer { self.numberingService.endBatchUpdates(for: collection) }
                self.numberingService.clearLevel(for: asset, in: collection)
                for i in (idx + 1)..<self.visibleAssetIDs.count {
                    let nextID = self.visibleAssetIDs[i]
                    let nextLv = latestLevels[nextID] ?? 0
                    if nextLv == 0 || nextLv <= currLv { break }
                    if let next = self.assetByID[nextID] {
                        self.numberingService.clearLevel(for: next, in: collection)
                    }
                }
                self.refreshParagraphDisplay()
            }
            hierarchyGroup.append(clearAction)
        }

        let isCurrentHierarchyCollapsed = numberingService.isCollapsed(asset, in: collection)
        let hasHierarchyDescendants = numberingService.hasDescendants(asset, in: assets, collection: collection)
        if hasHierarchyDescendants || isCurrentHierarchyCollapsed {
            let collapseAction = UIAction(
                title: isCurrentHierarchyCollapsed ? "展开" : "折叠",
                image: contextMenuImage(isCurrentHierarchyCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
            ) { [weak self] _ in
                guard let self else { return }
                self.numberingService.toggleCollapse(asset, in: collection)
                self.refreshParagraphDisplay()
            }
            hierarchyGroup.append(collapseAction)
        }

        return UIMenu(title: "层级", options: .displayInline, children: hierarchyGroup)
    }

    private func prewarmContextMenuHierarchyCacheIfNeeded() {
        guard sortPreference == .custom, supportsHierarchyNumbering, let collection = currentCollection else { return }
        let levels = numberingService.levels(in: collection)
        DispatchQueue.main.async { [weak self] in
            self?.prewarmContextMenuHierarchyCache(levels: levels)
        }
    }

    private func prewarmContextMenuHierarchyCache(levels: [String: Int]) {
        var result: [Int] = []
        result.reserveCapacity(visibleAssetIDs.count)
        var previousLevel = 0
        for id in visibleAssetIDs {
            result.append(previousLevel)
            let level = levels[id] ?? 0
            if level > 0 {
                previousLevel = level
            }
        }
        contextMenuPreviousLevelCache = result
    }

    private func reloadAnchorCells(oldID: String?, newID: String?) {
        let ids = [oldID, newID].compactMap { $0 }
        let indexPaths = ids.compactMap { id -> IndexPath? in
            guard let index = visibleAssetIndexByID[id] else { return nil }
            return IndexPath(item: index, section: 0)
        }
        guard !indexPaths.isEmpty else { return }
        collectionView.reloadItems(at: Array(Set(indexPaths)))
    }

    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        let indexPath: IndexPath?
        if let identifier = configuration.identifier as? IndexPath {
            indexPath = identifier
        } else if let identifier = configuration.identifier as? NSIndexPath {
            indexPath = identifier as IndexPath
        } else {
            indexPath = nil
        }
        guard let indexPath, let cell = collectionView.cellForItem(at: indexPath) else { return nil }

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
        case .creationDate, .modificationDate, .recentDate, .oldest, .newest:
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
        case .creationDate,.oldest,.newest:
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

// MARK: - 快跳定位（选区 / 层级分支 / 无级）

extension PhotoGridView {

    enum QuickJumpDirection {
        case previous
        case next
    }

    enum HierarchyLevelJumpDirection {
        case shallower
        case deeper
    }

    /// 将链式锚点对齐到「选中序号最大」（最近选入）的格；无选中或非选择模式时清空。
    /// 若该格在头尾目标链上无法向两侧移动（如只选一张且唯一目标即自身），则置 `nil`，改用视口边界判断可用性，避免两键全灰。
    func syncSelectionQuickNavCurrentVisibleIndexToLastSelectedAsset() {
        var newJump: Int?
        defer {
            lastQuickNavJumpIndex = newJump
            postQuickJumpToolbarRefresh()
        }
        guard quickJumpModeIsActive(.selection), selectedAssetCount > 0 else {
            return
        }
        if selectedAssetCount == visibleAssetIDs.count {
            newJump = visibleAssetIDs.count > 1 ? visibleAssetIDs.count - 1 : nil
            return
        }
        guard
            let lastID = selectionState.lastSelectedID,
            let idx = visibleAssetIDs.firstIndex(of: lastID)
        else {
            return
        }
        let targets = quickJumpTargetIndices(for: .selection)
        let canMoveAlongTargets = targets.contains { $0 < idx } || targets.contains { $0 > idx }
        newJump = canMoveAlongTargets ? idx : nil
    }

    func isQuickJumpModeAvailable(_ mode: PhotoGridQuickJumpMode) -> Bool {
        quickJumpModeIsActive(mode)
    }

    func syncQuickJumpBarButtons(mode: PhotoGridQuickJumpMode, previous: UIBarButtonItem, next: UIBarButtonItem) {
        guard quickJumpModeIsActive(mode) else {
            quickJumpSetBarButtons(previous: previous, next: next, canPrev: false, canNext: false)
            return
        }
        if mode == .hierarchyBranch {
            let availability = hierarchyBranchQuickJumpAvailability()
            quickJumpSetBarButtons(previous: previous, next: next, canPrev: availability.canPrev, canNext: availability.canNext)
            return
        }
        let targets = quickJumpTargetIndices(for: mode)
        guard !targets.isEmpty else {
            quickJumpSetBarButtons(previous: previous, next: next, canPrev: false, canNext: false)
            return
        }
        let (vmin, vmax) = quickJumpVisibleItemBounds()
        let (canPrev, canNext) = quickJumpAvailability(targets: targets, vmin: vmin, vmax: vmax)
        quickJumpSetBarButtons(previous: previous, next: next, canPrev: canPrev, canNext: canNext)
    }

    func performQuickJump(mode: PhotoGridQuickJumpMode, direction: QuickJumpDirection) {
        guard quickJumpModeIsActive(mode) else { return }
        if mode == .hierarchyBranch {
            guard let index = hierarchyBranchQuickJumpDestination(direction: direction) else { return }
            scrollToQuickJumpIndex(index)
            return
        }
        let targets = quickJumpTargetIndices(for: mode)
        guard !targets.isEmpty else { return }

        let (vmin, vmax) = quickJumpVisibleItemBounds()
        guard let index = quickJumpDestination(targets: targets, direction: direction, vmin: vmin, vmax: vmax) else { return }

        scrollToQuickJumpIndex(index)
    }

    func syncHierarchyLevelJumpBarButtons(mode: PhotoGridQuickJumpMode, shallower: UIBarButtonItem, deeper: UIBarButtonItem) {
        guard quickJumpModeIsActive(mode), mode == .hierarchyBranch else {
            shallower.isEnabled = false
            deeper.isEnabled = false
            return
        }
        shallower.isEnabled = hierarchyLevelJumpDestination(direction: .shallower) != nil
        deeper.isEnabled = hierarchyLevelJumpDestination(direction: .deeper) != nil
    }

    func performHierarchyLevelJump(mode: PhotoGridQuickJumpMode, direction: HierarchyLevelJumpDirection) {
        guard quickJumpModeIsActive(mode), mode == .hierarchyBranch else { return }
        guard let index = hierarchyLevelJumpDestination(direction: direction) else { return }
        scrollToQuickJumpIndex(index)
    }

    func resetQuickJumpAnchor() {
        lastQuickNavJumpIndex = nil
        postQuickJumpToolbarRefresh()
    }

    private func clearQuickJumpAnchorForUserScroll() {
        guard lastQuickNavJumpIndex != nil else { return }
        lastQuickNavJumpIndex = nil
        hierarchyLevelJumpDestinationCache.removeAll()
    }

    func syncSelectionQuickNavBarButtons(previous: UIBarButtonItem, next: UIBarButtonItem) {
        syncQuickJumpBarButtons(mode: .selection, previous: previous, next: next)
    }

    func performSelectionQuickNavPrevious() {
        performQuickJump(mode: .selection, direction: .previous)
    }

    func performSelectionQuickNavNext() {
        performQuickJump(mode: .selection, direction: .next)
    }

    func syncHierarchyBranchNavBarButtons(previous: UIBarButtonItem, next: UIBarButtonItem) {
        syncQuickJumpBarButtons(mode: .hierarchyBranch, previous: previous, next: next)
    }

    func performHierarchyBranchNavPrevious() {
        performQuickJump(mode: .hierarchyBranch, direction: .previous)
    }

    func performHierarchyBranchNavNext() {
        performQuickJump(mode: .hierarchyBranch, direction: .next)
    }

    private static let quickJumpHighlightDelay: TimeInterval = 0.32

    private func quickJumpModeIsActive(_ mode: PhotoGridQuickJumpMode) -> Bool {
        switch mode {
        case .selection:
            return selectionMode == .multiple || selectionMode == .range
        case .hierarchyBranch, .unleveled:
            return sortPreference == .custom && supportsHierarchyNumbering && currentCollection != nil
        }
    }

    private func quickJumpTargetIndices(for mode: PhotoGridQuickJumpMode) -> [Int] {
        guard quickJumpModeIsActive(mode) else { return [] }
        if mode == .hierarchyBranch {
            return hierarchyBranchQuickJumpTargetIndices()
        }
        if let cached = quickJumpTargetCache[mode] {
            return cached
        }
        let targets: [Int]
        switch mode {
        case .selection:
            targets = selectionQuickJumpTargetIndices()
        case .hierarchyBranch:
            targets = hierarchyBranchQuickJumpTargetIndices()
        case .unleveled:
            targets = unleveledQuickJumpTargetIndices()
        }
        quickJumpTargetCache[mode] = targets
        return targets
    }

    /// 所有连续选中块：每块贡献「头」；块内多于一张时再贡献「尾」。按可见顺序去重排序。
    private func selectionQuickJumpTargetIndices() -> [Int] {
        if selectedAssetCount == visibleAssetIDs.count {
            guard visibleAssetIDs.count > 1 else { return visibleAssetIDs.isEmpty ? [] : [0] }
            return [0, visibleAssetIDs.count - 1]
        }
        let ids = cachedSelectedIdentifierSet()
        return contiguousBlockEdgeIndices { ids.contains(visibleAssetIDs[$0]) }
    }

    /// 层级同级快跳：在当前父节点下，只沿同级兄弟前后跳。
    private func hierarchyBranchQuickJumpTargetIndices() -> [Int] {
        guard let collection = currentCollection else { return [] }
        guard let current = currentHierarchyBranchJumpTarget() else { return [] }
        let levels = hierarchyEffectiveLevels(in: collection)
        return hierarchySiblingJumpIndex(levels: levels).siblingTargets(referenceIndex: current.visibleIndex)
    }

    private func hierarchyBranchQuickJumpDestination(direction: QuickJumpDirection) -> Int? {
        guard let collection = currentCollection else { return nil }
        guard let current = currentHierarchyBranchJumpTarget() else { return nil }
        let levels = hierarchyEffectiveLevels(in: collection)
        return hierarchySiblingJumpIndex(levels: levels).jumpTarget(
            referenceIndex: current.visibleIndex,
            direction: direction == .previous ? -1 : 1
        )
    }

    private func hierarchyBranchQuickJumpAvailability() -> (canPrev: Bool, canNext: Bool) {
        (
            hierarchyBranchQuickJumpDestination(direction: .previous) != nil,
            hierarchyBranchQuickJumpDestination(direction: .next) != nil
        )
    }

    /// 无级快跳：连续 level == 0 的段落贡献头尾，间隔开的段落逐段跳。
    private func unleveledQuickJumpTargetIndices() -> [Int] {
        guard let collection = currentCollection else { return [] }
        let levels = hierarchyEffectiveLevels(in: collection)
        return contiguousBlockEdgeIndices {
            (levels[visibleAssetIDs[$0]] ?? 0) == 0
        }
    }

    private func contiguousBlockEdgeIndices(matching isTarget: (Int) -> Bool) -> [Int] {
        var result: [Int] = []
        var i = 0
        while i < visibleAssets.count {
            guard isTarget(i) else {
                i += 1
                continue
            }
            let start = i
            var end = i
            while end + 1 < visibleAssets.count, isTarget(end + 1) {
                end += 1
            }
            result.append(start)
            if end != start {
                result.append(end)
            }
            i = end + 1
        }
        return result
    }

    private func quickJumpVisibleItemBounds() -> (min: Int, max: Int) {
        let items = collectionView.indexPathsForVisibleItems.map(\.item)
        return (items.min() ?? 0, items.max() ?? 0)
    }

    private func quickJumpSetBarButtons(previous: UIBarButtonItem, next: UIBarButtonItem, canPrev: Bool, canNext: Bool) {
        previous.isEnabled = canPrev
        next.isEnabled = canNext
    }

    private func quickJumpDestination(targets: [Int], direction: QuickJumpDirection, vmin: Int, vmax: Int) -> Int? {
        switch direction {
        case .previous:
            return previousQuickJumpTarget(in: targets, before: lastQuickNavJumpIndex ?? vmax)
        case .next:
            return nextQuickJumpTarget(in: targets, after: lastQuickNavJumpIndex ?? vmin)
        }
    }

    private func quickJumpAvailability(targets: [Int], vmin: Int, vmax: Int) -> (canPrev: Bool, canNext: Bool) {
        let anchor = lastQuickNavJumpIndex
        return (
            previousQuickJumpTarget(in: targets, before: anchor ?? vmax) != nil,
            nextQuickJumpTarget(in: targets, after: anchor ?? vmin) != nil
        )
    }

    private func nextQuickJumpTarget(in targets: [Int], after value: Int) -> Int? {
        var low = 0
        var high = targets.count
        while low < high {
            let mid = (low + high) / 2
            if targets[mid] <= value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low < targets.count ? targets[low] : nil
    }

    private func previousQuickJumpTarget(in targets: [Int], before value: Int) -> Int? {
        var low = 0
        var high = targets.count
        while low < high {
            let mid = (low + high) / 2
            if targets[mid] < value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        let index = low - 1
        return index >= 0 ? targets[index] : nil
    }

    private struct HierarchyNodeJumpTarget {
        let visibleIndex: Int
        let assetID: String
        let level: Int
    }

    private struct HierarchyLevelJumpDestinationCacheKey: Hashable {
        let direction: HierarchyLevelJumpDirection
        let referenceAssetID: String
    }

    private enum HierarchyLevelJumpDestinationCacheValue {
        case none
        case index(Int)

        var index: Int? {
            switch self {
            case .none:
                return nil
            case .index(let index):
                return index
            }
        }
    }

    private func currentHierarchyBranchJumpTarget() -> HierarchyNodeJumpTarget? {
        guard let collection = currentCollection else { return nil }
        let targets = hierarchyNodeJumpTargets(in: collection)
        guard !targets.isEmpty else { return nil }

        let referenceIndex: Int
        if let last = lastQuickNavJumpIndex, visibleAssetIDs.indices.contains(last) {
            referenceIndex = last
        } else {
            let bounds = quickJumpVisibleItemBounds()
            referenceIndex = (bounds.min + bounds.max) / 2
        }

        return nearestHierarchyNodeJumpTarget(in: targets, to: referenceIndex)
    }

    private func nearestHierarchyNodeJumpTarget(
        in targets: [HierarchyNodeJumpTarget],
        to referenceIndex: Int
    ) -> HierarchyNodeJumpTarget? {
        var low = 0
        var high = targets.count
        while low < high {
            let mid = (low + high) / 2
            if targets[mid].visibleIndex < referenceIndex {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let after = low < targets.count ? targets[low] : nil
        let beforeIndex = low - 1
        let before = beforeIndex >= 0 ? targets[beforeIndex] : nil
        switch (before, after) {
        case (nil, let target?):
            return target
        case (let target?, nil):
            return target
        case (let lhs?, let rhs?):
            return abs(lhs.visibleIndex - referenceIndex) <= abs(rhs.visibleIndex - referenceIndex) ? lhs : rhs
        case (nil, nil):
            return nil
        }
    }

    private func hierarchyLevelJumpDestination(direction: HierarchyLevelJumpDirection) -> Int? {
        guard let collection = currentCollection else { return nil }
        guard let current = currentHierarchyBranchJumpTarget() else { return nil }
        let cacheKey = HierarchyLevelJumpDestinationCacheKey(
            direction: direction,
            referenceAssetID: current.assetID
        )
        if let cached = hierarchyLevelJumpDestinationCache[cacheKey] {
            return cached.index
        }
        let targets = hierarchyNodeJumpTargets(in: collection)
        let targetIDs = targets.map(\.assetID)
        let levels = Dictionary(uniqueKeysWithValues: targets.map { ($0.assetID, $0.level) })
        let referenceIndex = targets.firstIndex { $0.assetID == current.assetID } ?? 0
        let destination: Int?
        switch direction {
        case .shallower:
            destination = PhotoNumberingLogic.hierarchyLevelJumpTarget(
                visibleAssetIDs: targetIDs,
                levels: levels,
                referenceIndex: referenceIndex,
                direction: -1
            ).map { targets[$0].visibleIndex }
        case .deeper:
            destination = PhotoNumberingLogic.hierarchyLevelJumpTarget(
                visibleAssetIDs: targetIDs,
                levels: levels,
                referenceIndex: referenceIndex,
                direction: 1
            ).map { targets[$0].visibleIndex }
        }
        hierarchyLevelJumpDestinationCache[cacheKey] = destination.map { .index($0) } ?? HierarchyLevelJumpDestinationCacheValue.none
        return destination
    }

    private func hierarchyNodeJumpTargets(in collection: PHAssetCollection) -> [HierarchyNodeJumpTarget] {
        if let cached = hierarchyNodeJumpTargetsCache {
            return cached
        }
        let levels = hierarchyEffectiveLevels(in: collection)
        let targets: [HierarchyNodeJumpTarget] = visibleAssetIDs.indices.compactMap { index in
            let id = visibleAssetIDs[index]
            guard let level = levels[id], level > 0 else { return nil }
            return HierarchyNodeJumpTarget(visibleIndex: index, assetID: id, level: level)
        }
        hierarchyNodeJumpTargetsCache = targets
        return targets
    }

    private func hierarchyEffectiveLevels(in collection: PHAssetCollection) -> [String: Int] {
        if let cached = hierarchyEffectiveLevelsCache {
            return cached
        }
        let levels = numberingService.effectiveLevels(for: assets, in: collection)
        hierarchyEffectiveLevelsCache = levels
        return levels
    }

    private func hierarchySiblingJumpIndex(levels: [String: Int]) -> PhotoNumberingLogic.HierarchySiblingJumpIndex {
        if let cached = hierarchySiblingJumpIndexCache {
            return cached
        }
        let index = PhotoNumberingLogic.HierarchySiblingJumpIndex(
            visibleAssetIDs: visibleAssetIDs,
            levels: levels
        )
        hierarchySiblingJumpIndexCache = index
        return index
    }

    private func scrollToQuickJumpIndex(_ index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        lastQuickNavJumpIndex = index
        postQuickJumpToolbarRefresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.quickJumpHighlightDelay) { [weak self] in
            guard let self else { return }
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else { return }
            cell.performQuickNavigationHighlightAnimation()
        }
    }

    private func invalidateQuickJumpTargetCache(for mode: PhotoGridQuickJumpMode? = nil) {
        if let mode {
            quickJumpTargetCache[mode] = nil
            if mode == .hierarchyBranch {
                invalidateHierarchyQuickJumpCache()
            }
        } else {
            quickJumpTargetCache.removeAll()
            invalidateHierarchyQuickJumpCache()
        }
    }

    private func invalidateHierarchyQuickJumpCache() {
        hierarchyEffectiveLevelsCache = nil
        hierarchyNodeJumpTargetsCache = nil
        hierarchySiblingJumpIndexCache = nil
        hierarchyLevelJumpDestinationCache.removeAll()
        invalidateContextMenuHierarchyCache()
    }

    private func invalidateContextMenuHierarchyCache() {
        contextMenuPreviousLevelCache = nil
    }

    private func invalidateHierarchyEnablementCache() {
        cachedCanCollapseAll = nil
        cachedCanExpandAll = nil
    }

    private func validateHierarchyEnablementCache(canCollapseAll: Bool, canExpandAll: Bool) {
        cachedCanCollapseAll = canCollapseAll
        cachedCanExpandAll = canExpandAll
    }

    private func postQuickJumpToolbarRefresh() {
        onQuickJumpToolbarRefresh?()
        onSelectionQuickNavToolbarRefresh?()
        onHierarchyBranchNavToolbarRefresh?()
    }
}

// MARK: - 底栏快捷层级（可见 Cell 逐级 ±1）

extension PhotoGridView {

    /// `reloadData` 后需等布局完成，`indexPathsForVisibleItems` 才有值；否则底栏按钮会一直禁用。
    func scheduleHierarchyToolbarRefresh() {
        guard !hierarchyToolbarRefreshPending else { return }
        hierarchyToolbarRefreshPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hierarchyToolbarRefreshPending = false
            self.layoutIfNeeded()
            self.collectionView.layoutIfNeeded()
            self.onHierarchyToolbarRefresh?()
        }
    }

    func visibleAssetIDsOnScreen() -> Set<String> {
        layoutIfNeeded()
        collectionView.layoutIfNeeded()

        var ids = Set<String>()
        let visibleRect = CGRect(
            x: collectionView.contentOffset.x,
            y: collectionView.contentOffset.y,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )
        if let attributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: visibleRect) {
            for attribute in attributes where attribute.representedElementCategory == .cell {
                let indexPath = attribute.indexPath
                guard indexPath.section == 0, indexPath.item < visibleAssetIDs.count else { continue }
                ids.insert(visibleAssetIDs[indexPath.item])
            }
        }

        if ids.isEmpty {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard indexPath.section == 0, indexPath.item < visibleAssetIDs.count else { continue }
                ids.insert(visibleAssetIDs[indexPath.item])
            }
        }

        if ids.isEmpty {
            return approximateVisibleAssetIDsOnScreen()
        }
        return ids
    }

    /// `indexPathsForVisibleItems` 尚未就绪时，按 contentOffset 与格网估算视口内项
    private func approximateVisibleAssetIDsOnScreen() -> Set<String> {
        guard !visibleAssetIDs.isEmpty,
              let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return [] }
        let rowStride = layout.itemSize.height + layout.minimumLineSpacing
        let colStride = layout.itemSize.width + layout.minimumInteritemSpacing
        guard rowStride > 0, colStride > 0, columns > 0 else { return [] }

        let inset = collectionView.adjustedContentInset
        let topY = collectionView.contentOffset.y + inset.top
        let bottomY = collectionView.contentOffset.y + collectionView.bounds.height - inset.bottom
        let firstRow = max(0, Int((topY - layout.sectionInset.top) / rowStride))
        let lastRow = max(
            firstRow,
            Int(ceil((bottomY - layout.sectionInset.top) / rowStride))
        )

        var ids: Set<String> = []
        ids.reserveCapacity((lastRow - firstRow + 1) * columns)
        for row in firstRow...lastRow {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < visibleAssetIDs.count else { continue }
                ids.insert(visibleAssetIDs[index])
            }
        }
        return ids
    }

    /// 若已选中照片且选中项存在层级 → 返回选中项 ID 集合；
    /// 否则 → 返回 nil，表示应使用全量模式。
    private var selectedHierarchyModeIDs: Set<String>? {
        guard hasSelectedAssets, let collection = currentCollection else { return nil }
        let selectedIDs = cachedSelectedIdentifierSet()
        guard numberingService.containsLevel(in: selectedIDs, collection: collection) else { return nil }
        return selectedIDs
    }

    /// 选择模式下是否有含层级的选中照片，用于决定是否显示层级折叠/展开按钮。
    var hasSelectedAssetsWithHierarchy: Bool {
        selectedHierarchyModeIDs != nil
    }

    func syncHierarchyToolbarButtons(collapse: UIBarButtonItem, expand: UIBarButtonItem) {
        guard supportsHierarchyNumbering, sortPreference == .custom, let collection = currentCollection else {
            collapse.isEnabled = false
            expand.isEnabled = false
            return
        }
        if let selectedIDs = selectedHierarchyModeIDs {
            collapse.isEnabled = numberingService.canApplyVisibleHierarchyStep(
                expand: false, visibleAssetIDs: selectedIDs, orderedAssets: assets, in: collection
            )
            expand.isEnabled = numberingService.canApplyVisibleHierarchyStep(
                expand: true, visibleAssetIDs: selectedIDs, orderedAssets: assets, in: collection
            )
        } else {
            if let canCollapseAll = cachedCanCollapseAll, let canExpandAll = cachedCanExpandAll {
                collapse.isEnabled = canCollapseAll
                expand.isEnabled = canExpandAll
            } else {
                collapse.isEnabled = numberingService.canApplyAllItemsHierarchyStep(
                    expand: false, orderedAssets: assets, in: collection
                )
                expand.isEnabled = numberingService.canApplyAllItemsHierarchyStep(
                    expand: true, orderedAssets: assets, in: collection
                )
                validateHierarchyEnablementCache(canCollapseAll: collapse.isEnabled, canExpandAll: expand.isEnabled)
            }
        }
    }

    @discardableResult
    func performVisibleHierarchyShortcut(expand: Bool) -> Bool {
        guard supportsHierarchyNumbering, sortPreference == .custom, let collection = currentCollection else { return false }

        numberingService.beginBatchUpdates(for: collection)
        let changed: Bool
        if let selectedIDs = selectedHierarchyModeIDs {
            changed = numberingService.applyVisibleHierarchyStep(
                expand: expand,
                visibleAssetIDs: selectedIDs,
                orderedAssets: assets,
                in: collection
            )
        } else {
            changed = numberingService.applyAllItemsHierarchyStep(
                expand: expand,
                orderedAssets: assets,
                in: collection
            )
        }
        numberingService.endBatchUpdates(for: collection)
        guard changed else { return false }

        // 层级折叠/展开状态已变更，使缓存的按钮可用状态失效以便工具栏刷新时重新计算
        invalidateHierarchyEnablementCache()

        if isHierarchyShortcutVisibleAssetsAnimating {
            hierarchyShortcutNeedsVisibleRefresh = true
            onHierarchyToolbarRefresh?()
            return true
        }
        beginHierarchyShortcutVisibleRefresh()
        return true
    }

    private func beginHierarchyShortcutVisibleRefresh() {
        isHierarchyShortcutVisibleAssetsAnimating = true
        applyHierarchyShortcutVisibilityChange(animated: true) { [weak self] in
            self?.finishHierarchyShortcutVisibleRefresh()
        }
    }

    /// 动画结束后再合并刷新；连点多次只落到最终可见列表，避免动画互相打断
    private func finishHierarchyShortcutVisibleRefresh() {
        guard hierarchyShortcutNeedsVisibleRefresh else {
            isHierarchyShortcutVisibleAssetsAnimating = false
            onHierarchyToolbarRefresh?()
            return
        }
        hierarchyShortcutNeedsVisibleRefresh = false
        applyHierarchyShortcutVisibilityChange(animated: true) { [weak self] in
            self?.finishHierarchyShortcutVisibleRefresh()
        }
    }

    private func recenterVisualAnchor(preferredAssetID: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let collection = self.currentCollection else { return }
            let visibleIDs = Set(self.visibleAssetIDs)
            let targetID: String
            if visibleIDs.contains(preferredAssetID) {
                targetID = preferredAssetID
            } else if let preferred = self.assetByID[preferredAssetID],
                      let ancestor = self.numberingService.nearestVisibleNumberedAncestorAsset(
                          of: preferred,
                          visibleAssetIDs: visibleIDs,
                          orderedAssets: self.assets,
                          in: collection
                      ) {
                targetID = ancestor.localIdentifier
            } else if let center = self.centerVisibleAsset {
                targetID = center.localIdentifier
            } else {
                return
            }
            guard let index = self.visibleAssetIDs.firstIndex(of: targetID) else { return }
            self.collectionView.layoutIfNeeded()
            self.collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredVertically,
                animated: false
            )
        }
    }
}
