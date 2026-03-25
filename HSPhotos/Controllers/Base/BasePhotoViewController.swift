//
//  BasePhotoViewController.swift
//  HSPhotos
//
//  Created by Hans on 2026/2/27.
//

import UIKit
import Photos
import PhotosUI

class BasePhotoViewController: UIViewController {
    
    internal lazy var searchTextField: SearchBarView = {
        let searchBarView = SearchBarView()
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.delegate = self
        searchBarView.alpha = 0.0
        return searchBarView
    }()
    
    internal lazy var segmentControl: UISegmentedControl = {
        let items = ["年", "月", "日", "所有"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 3 // 默认选中"所有"
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    internal lazy var gridView: PhotoGridView = {
        let view = PhotoGridView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    internal lazy var selectBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(toggleSelectionMode))
        return button
    }()
    
    internal lazy var selectAllBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "全选", style: .plain, target: self, action: #selector(selectAllAssets))
        return button
    }()
    
    internal lazy var deselectAllBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "取消全选", style: .plain, target: self, action: #selector(deselectAllAssets))
        return button
    }()
    
    internal lazy var cancelSelectBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(toggleSelectionMode))
        return button
    }()
    
    internal lazy var rangeSwitchItem: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "checkmark.seal"), style: .plain, target: self, action: #selector(toggleRangeSelection))
        button.tag = 0 // 0: 未选中, 1: 选中
        return button
    }()
    
    internal lazy var menuBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
        button.menu = createOperationMenu()
        return button
    }()

    internal lazy var tagFilterBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "tag"),
            style: .plain,
            target: self,
            action: #selector(didTapTagFilter)
        )
        return button
    }()
    
    internal lazy var undoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.left"),
            style: .plain,
            target: self,
            action: #selector(undoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    internal lazy var redoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.right"),
            style: .plain,
            target: self,
            action: #selector(redoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    private lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = sortPreference.sortDescriptors
        return options
    }()
    
    internal let collection: PHAssetCollection
    internal var sortPreference: PhotoSortPreference = .custom

    /// 是否支持层级编号功能。首页（图库）不支持，相册内支持。
    internal var supportsHierarchyNumbering: Bool { true }

    /// 全量照片（排序后的原始数据），始终保持完整
    internal var assets: [PHAsset] = [] {
        didSet {
            applyTagFilter()
        }
    }

    /// 标签过滤状态，变化时自动重新过滤并刷新 gridView
    internal var filterState: TagFilterState = TagFilterState() {
        didSet {
            guard filterState != oldValue else { return }
            applyTagFilter()
            syncSearchTokens()
        }
    }

    internal var selectionMode: PhotoSelectionMode = .none {
        didSet {
            gridView.selectionMode = selectionMode
            updateNavigationBar()
            updateOperationMenu()
        }
    }
    
    private var lastContentOffsetY: CGFloat = 0
    private var isSearchBarVisible = false
    private var searchTextFieldTopConstraint: NSLayoutConstraint!
    private let backgroundGradientLayer = CAGradientLayer()
    
    init(collection: PHAssetCollection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = collection.localizedTitle
        
        // 禁用大标题模式
        navigationItem.largeTitleDisplayMode = .never
        
        // 允许视图内容延伸到四周
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all

        setupUI()
        setupTraitChangeObserver()
        
        // 进入相册时从 UserDefaults 加载到内存，使用期间仅读写内存
        PhotoNumberingService.shared.loadForCollection(collection)
        PhotoOrder.loadForCollection(collection)
        PhotoHeaderService.shared.loadForCollection(collection)
        
        // 同步初始排序偏好到 PhotoGridView
        gridView.sortPreference = sortPreference
        // 设置当前相册引用与层级支持（必须在loadPhoto之前设置）
        gridView.currentCollection = collection
        gridView.supportsHierarchyNumbering = supportsHierarchyNumbering
        
        loadPhoto()
        setupUndoManager()
    }
    
    private func setupUI() {
        // 配置渐变背景
        let lightColors: [CGColor] = [
            UIColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1.0).cgColor,
            UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0).cgColor,
            UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1.0).cgColor
        ]
        let darkColors: [CGColor] = [
            UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor,
            UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0).cgColor
        ]
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundGradientLayer.colors = isDark ? darkColors : lightColors
        backgroundGradientLayer.locations = [0.0, 0.45, 1.0]
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        
        view.addSubview(gridView)
        view.addSubview(searchTextField)
        searchTextField.isHidden = true
        view.addSubview(segmentControl)
        segmentControl.isHidden = true
        
        // 创建搜索条的顶部约束
        searchTextFieldTopConstraint = searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            searchTextFieldTopConstraint,
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 设置segmentControl约束
            segmentControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // 初始状态下的按钮顺序，包含menuBarButton和标签过滤按钮
        navigationItem.setRightBarButtonItems([selectBarButton, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton], animated: true)

        // 设置 gridView 的滚动委托
        gridView.scrollDelegate = self
    }
    
    private func setupUndoManager() {
        // 仅在操作后显式调用 updateUndoRedoButtons 即可，不需要定时器轮询
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新渐变层的frame
        backgroundGradientLayer.frame = view.bounds
    }
    
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: BasePhotoViewController, previousTraitCollection: UITraitCollection) in
            // 当界面模式改变时，更新渐变背景颜色
            let lightColors: [CGColor] = [
                UIColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1.0).cgColor,
                UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0).cgColor,
                UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1.0).cgColor
            ]
            let darkColors: [CGColor] = [
                UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0).cgColor
            ]
            let isDark = self.traitCollection.userInterfaceStyle == .dark
            self.backgroundGradientLayer.colors = isDark ? darkColors : lightColors
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开相册时将数据持久化到 UserDefaults
        PhotoNumberingService.shared.saveForCollection(collection)
        PhotoOrder.saveForCollection(collection)
        PhotoHeaderService.shared.saveForCollection(collection)
    }

    deinit {
        // 系统会自动处理trait变化注册的清理
    }
    
    internal func updateUndoRedoButtons() {
        undoBarButton.isEnabled = canUndo
        redoBarButton.isEnabled = canRedo
    }
    
    @objc internal func undoAction() {
        guard let action = UndoManagerService.shared.undo() else { return }
        
        let loadingAlert = UIAlertController(title: "撤销中", message: "正在撤销操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.undo(action) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    if case .sort(_, let originalAssets, _) = action.type {
                        PhotoOrder.set(order: originalAssets, for: self.collection)
                    } else if case .delete(_, let assets) = action.type {
                        var restored = self.assets
                        restored.append(contentsOf: assets)
                        PhotoOrder.set(order: restored, for: self.collection)
                    } else if case .move(let sourceCollection, _, let assets) = action.type, sourceCollection.localIdentifier == self.collection.localIdentifier {
                        var restored = self.assets
                        restored.append(contentsOf: assets)
                        PhotoOrder.set(order: restored, for: self.collection)
                    } else if case .paste(let assets, let destinationCollection, _) = action.type, destinationCollection.localIdentifier == self.collection.localIdentifier {
                        let remaining = self.assets.filter { !Set(assets.map(\.localIdentifier)).contains($0.localIdentifier) }
                        PhotoOrder.set(order: remaining, for: self.collection)
                    }
                    self.loadPhoto()
                }
                // 撤销失败不提示，仅更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    @objc internal func redoAction() {
        guard let action = UndoManagerService.shared.redo() else { return }
        
        // 对于重做操作，我们需要执行原始操作而不是撤销操作
        let loadingAlert = UIAlertController(title: "重做中", message: "正在重做操作...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.redo(action) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    if case .sort(_, _, let sortedAssets) = action.type {
                        PhotoOrder.set(order: sortedAssets, for: self.collection)
                    } else if case .delete(_, let assets) = action.type {
                        let remaining = self.assets.filter { !Set(assets.map(\.localIdentifier)).contains($0.localIdentifier) }
                        PhotoOrder.set(order: remaining, for: self.collection)
                    } else if case .move(let sourceCollection, _, let assets) = action.type, sourceCollection.localIdentifier == self.collection.localIdentifier {
                        let remaining = self.assets.filter { !Set(assets.map(\.localIdentifier)).contains($0.localIdentifier) }
                        PhotoOrder.set(order: remaining, for: self.collection)
                    } else if case .paste(let assets, let destinationCollection, let insertIndex) = action.type, destinationCollection.localIdentifier == self.collection.localIdentifier {
                        var newOrder = self.assets
                        let clampedIndex = min(insertIndex, newOrder.count)
                        newOrder.insert(contentsOf: assets, at: clampedIndex)
                        PhotoOrder.set(order: newOrder, for: self.collection)
                    }
                    self.loadPhoto()
                } else {
                    self.showAlert(title: "重做失败", message: error ?? "无法重做操作")
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    internal func loadPhoto() {
        // 在后台线程执行耗时操作，避免阻塞主线程造成卡顿
        let collection = self.collection
        let options = self.fetchOptions
        let preference = self.sortPreference
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var newAssets: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
            }
            
            // 检查是否有自定义排序数据，如果没有则创建默认的
            let customOrder = PhotoOrder.order(for: collection)
            if customOrder.isEmpty && !newAssets.isEmpty {
                print("📝 初始化自定义排序数据")
                PhotoOrder.set(order: newAssets, for: collection)
            }
            
            // 如果是自定义排序，应用自定义排序
            if preference == .custom {
                newAssets = PhotoOrder.apply(to: newAssets, for: collection)
            }
            
            let validAssetIDs = Set(newAssets.map { $0.localIdentifier })
            PhotoNumberingService.shared.cleanupInvalidNodes(validAssetIDs: validAssetIDs, for: collection)
            
            DispatchQueue.main.async {
                self.assets = newAssets
            }
        }
    }
    
    internal func onChanged(sort preference: PhotoSortPreference) {
        self.sortPreference = preference
        
        let options = PHFetchOptions()
        options.sortDescriptors = preference.sortDescriptors
        fetchOptions = options
        
        let collection = self.collection
        
        // 在后台线程执行耗时操作，避免切换排序时卡顿
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var newAssets: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
            }
            
            // 如果是自定义排序，应用自定义排序
            if preference == .custom {
                newAssets = PhotoOrder.apply(to: newAssets, for: collection)
            }
            
            DispatchQueue.main.async {
                self.assets = newAssets
                self.gridView.sortPreference = preference
                preference.set(preference: self.collection)
                self.updateOperationMenu()
            }
        }
    }

    internal func onOrder() {
        do {
            let start = Date()
            let sortedAssets = try gridView.sort()
            self.assets = sortedAssets
            
            let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)
            
            PhotoChangesService.sync(sortedAssets: sortedAssets, for: self.collection) { [weak self] success, message in
                guard let self = self else { return }
                let duration = Date().timeIntervalSince(start)
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // 保存自定义排序数据到 UserDefaults
                        PhotoOrder.set(order: sortedAssets, for: self.collection)
                        
                        // 排序后必须切换到自定义排序模式，否则再次进入相册会按日期加载丢失顺序
                        if self.sortPreference != .custom {
                            self.sortPreference = .custom
                            self.gridView.sortPreference = .custom
                            PhotoSortPreference.custom.set(preference: self.collection)
                            self.updateOperationMenu()
                        }
                        
                        // 记录撤销操作
                        let originalAssets = self.assets // 保存原始顺序用于撤销
                        let undoAction = UndoAction.sort(collection: self.collection, originalAssets: originalAssets, sortedAssets: sortedAssets)
                        self.addAction(undoAction)
                        
//                        let message = "排序耗时: \(String(format: "%.2f", duration))秒"
//                        self.syncSuccess(message: message)
                    } else {
//                        let message = "无法同步照片顺序到系统相册：\(message ?? "")"
//                        self.syncFailed(message: message)
                    }
                    // 更新按钮状态
                    self.updateUndoRedoButtons()
                }
            }
        } catch {
            gridView.clearSelected()
            showAlert(title: "排序失败", message: error.localizedDescription)
        }
    }
    
    internal func onCopy() {
        AssetPasteboard.copyAssets(gridView.selectedAssets) { [weak self] success, message in
            guard let self = self else { return }
            if !success {
                let alertMessage = message ?? "无法复制到剪切板"
                self.showAlert(title: "复制失败", message: alertMessage)
            }
        }
    }
    
    internal func onDuplicate() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "复制失败", message: "请先选择要复制的照片")
            return
        }
        
        let loadingAlert = UIAlertController(title: "复制中", message: "正在创建照片副本...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.duplicate(assets: selectedAssets, to: self.collection) { [weak self] success, message in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if !success {
                    let alertMessage = message ?? "无法创建照片副本"
                    self.showAlert(title: "复制失败", message: alertMessage)
                } else {
                    self.loadPhoto()
                    // 更新按钮状态
                    self.updateUndoRedoButtons()
                }
            }
        }
    }
    
    internal func onPaste() {
        guard let assets = AssetPasteboard.assetsFromPasteboard() else {
            showAlert(title: "粘贴失败", message: "剪切板里没有资源")
            return
        }
        AssetPasteboard.pasteAssets(assets, into: collection) { [weak self] success, error in
            guard let self = self else { return }
//            let title = success ? "粘贴成功" : "粘贴失败"
//            let message = success ? "已粘贴到相册" : (error ?? "无法粘贴到相册")
//            self.showAlert(title: title, message: message)
            if success {
                self.loadPhoto()
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    internal func onDelete() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "删除失败", message: "请先选择要删除的照片")
            return
        }
        
        showDeleteConfirmationAlert(for: selectedAssets)
    }
    
    internal func onMove() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "移动失败", message: "请先选择要移动的照片")
            return
        }
        
        // 显示相册选择器
        showAlbumPicker(for: selectedAssets)
    }
    
    internal func showAddToAlbumPicker(for assets: [PHAsset]) {
        guard !assets.isEmpty else {
            showAlert(title: "添加失败", message: "请先选择要添加的照片")
            return
        }

        let pickerVC = AlbumListViewController(isPickerMode: true) { [weak self] destinationAlbum in
            self?.performAdd(assets: assets, to: destinationAlbum)
        }
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    
    internal func performAdd(assets: [PHAsset], to destinationCollection: PHAssetCollection) {
        let existingAssets = PHAsset.fetchAssets(in: destinationCollection, options: nil)
        var existingAssetIDs = Set<String>()
        existingAssets.enumerateObjects { asset, _, _ in
            existingAssetIDs.insert(asset.localIdentifier)
        }
        
        let assetsToAdd = assets.filter { !existingAssetIDs.contains($0.localIdentifier) }
        if assetsToAdd.isEmpty {
            showAlert(title: "提示", message: "所选照片已在目标相簿中")
            return
        }
        
        let loadingAlert = UIAlertController(title: "添加中", message: "正在添加到相簿...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PHPhotoLibrary.shared().performChanges({
            guard let request = PHAssetCollectionChangeRequest(for: destinationCollection) else { return }
            request.addAssets(assetsToAdd as NSArray)
        }, completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }
                    if success {
                        self.loadPhoto()
                    } else {
                        self.showAlert(title: "添加失败", message: error?.localizedDescription ?? "无法添加照片")
                    }
                }
            }
        })
    }
    
    internal func showAlbumPicker(for assets: [PHAsset]) {
        // 获取所有用户创建的相册
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        var albumList: [PHAssetCollection] = []
        
        collections.enumerateObjects { collection, _, _ in
            // 排除当前相册
            if collection.localIdentifier != self.collection.localIdentifier {
                albumList.append(collection)
            }
        }
        
        guard !albumList.isEmpty else {
            showAlert(title: "移动失败", message: "没有找到其他相册")
            return
        }
        
        // 创建相册选择动作表
        let alert = UIAlertController(title: "选择目标相册", message: nil, preferredStyle: .actionSheet)
        
        for collection in albumList {
            let action = UIAlertAction(title: collection.localizedTitle ?? "未命名相册", style: .default) { _ in
                self.performMove(assets: assets, to: collection)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        
        // iPad适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    internal func performMove(assets: [PHAsset], to destinationCollection: PHAssetCollection) {
        let loadingAlert = UIAlertController(title: "移动中", message: "正在将照片移动到其他相册...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        PhotoChangesService.move(assets: assets, from: self.collection, to: destinationCollection) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    let undoAction = UndoAction.move(sourceCollection: self.collection, destinationCollection: destinationCollection, assets: assets)
                    self.addAction(undoAction)
                    if self.sortPreference == .custom {
                        let remaining = self.assets.filter { !Set(assets.map(\.localIdentifier)).contains($0.localIdentifier) }
                        PhotoOrder.set(order: remaining, for: self.collection)
                    }
                    self.gridView.clearSelected()
                    self.loadPhoto()
                } else {
                    let message = error ?? "无法移动照片"
                    self.showAlert(title: "移动失败", message: message)
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }
    
    internal func showDeleteConfirmationAlert(for assets: [PHAsset]) {
        let count = assets.count
        let message = count == 1 ? "确定要从相册中删除这张照片吗？" : "确定要从相册中删除这\(count)张照片吗？"
        
        let alert = UIAlertController(title: "删除照片", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performDelete(assets: assets)
        })
        
        present(alert, animated: true)
    }
    
    internal func performDelete(assets: [PHAsset]) {
        let loadingAlert = UIAlertController(title: "删除中", message: "正在从相册中删除照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        // 先执行相册库删除，成功后再刷新 UI（避免「删除失败」但列表已更新的不一致）
        PhotoChangesService.delete(assets: assets, for: self.collection) { [weak self] success, error in
            guard let self = self else { return }
            loadingAlert.dismiss(animated: true) {
                if success {
                    // 仅用户相册支持撤销（removeAssets 可 addAssets 恢复），「所有照片」删除不支持
                    if self.collection.assetCollectionSubtype != .smartAlbumUserLibrary {
                        let undoAction = UndoAction.delete(collection: self.collection, assets: assets)
                        self.addAction(undoAction)
                    }
                    if self.sortPreference == .custom {
                        let remaining = self.assets.filter { !Set(assets.map(\.localIdentifier)).contains($0.localIdentifier) }
                        PhotoOrder.set(order: remaining, for: self.collection)
                    }
                    self.gridView.clearSelected()
                    self.loadPhoto()
                } else {
                    self.showAlert(title: "删除失败", message: error ?? "无法删除照片")
                }
                self.updateUndoRedoButtons()
            }
        }
    }
    
    internal func setSelectionMode(_ mode: PhotoSelectionMode) {
        if mode == .none {
            gridView.clearSelected()
            gridView.selectedStart = nil
            gridView.selectedEnd = nil
        }
        selectionMode = mode
    }
    
    /// 切换选择模式：点击进入多选模式，再次点击退出选择模式
    @objc internal func toggleSelectionMode() {
        if selectionMode == .none {
            // 进入多选模式
            setSelectionMode(.multiple)
            // 关闭全屏侧滑返回
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        } else {
            // 退出选择模式
            setSelectionMode(.none)
            // 同时关闭范围选择
            toggleRangeSelection(forceOff: true)
            // 开启全屏侧滑返回
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
        updateNavigationBar()
    }
    
    /// 切换范围选择开关
    @objc internal func toggleRangeSelection(forceOff: Bool = false) {
        let isCurrentlyOn = rangeSwitchItem.tag == 1
        let shouldTurnOn = !isCurrentlyOn && !forceOff
        
        if shouldTurnOn {
            // 打开范围选择
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal.fill")
            rangeSwitchItem.tag = 1
            setSelectionMode(.range)
        } else {
            // 关闭范围选择
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal")
            rangeSwitchItem.tag = 0
            if selectionMode == .range {
                setSelectionMode(.multiple)
            }
        }
    }
    
    /// 全选所有资产
    @objc internal func selectAllAssets() {
        gridView.selectAll()
        // 更新按钮状态
        updateSelectAllButton()
    }
    
    /// 取消全选所有资产
    @objc internal func deselectAllAssets() {
        gridView.clearSelected()
        // 更新按钮状态
        updateSelectAllButton()
    }
    
    internal func updateNavigationBar() {
        // 根据选择模式更新按钮状态
        if selectionMode == .none {
            // 退出选择模式时，显示选择按钮，隐藏范围选择开关，使用动画效果
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 恢复默认的返回按钮
            navigationItem.leftBarButtonItem = nil
        } else {
            // 进入选择模式时，显示取消按钮和范围选择开关，使用动画效果
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 根据当前选择状态显示全选或取消全选按钮
            updateSelectAllButton()
        }
    }
    
    /// 更新全选/取消全选按钮的显示状态
    internal func updateSelectAllButton() {
        let isAllSelected = isAllAssetsSelected()
        if isAllSelected {
            // 已全选，显示取消全选按钮
            navigationItem.setLeftBarButtonItems([deselectAllBarButton], animated: true)
        } else {
            // 未全选，显示全选按钮
            navigationItem.setLeftBarButtonItems([selectAllBarButton], animated: true)
        }
    }
    
    /// 检查是否所有可见资产都已被选中
    internal func isAllAssetsSelected() -> Bool {
        return gridView.selectedAssets.count == gridView.allAssets.count && !gridView.allAssets.isEmpty
    }
    
    // MARK: - Undo Manager Helper Methods
    
    internal func addAction(_ action: UndoAction) {
        UndoManagerService.shared.addUndoAction(action)
    }
    
    internal var canUndo: Bool {
        return UndoManagerService.shared.canUndo
    }
    
    internal var canRedo: Bool {
        return UndoManagerService.shared.canRedo
    }
    
    // MARK: - Menu Creation Methods
    
    internal func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按最旧的排最前排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [unowned self] _ in
            self.onChanged(sort: .creationDate)
        }
        
        let modificationDateAction = UIAction(
            title: "按最新的排最前排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .recentDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .recentDate)
        }
        
        let customAction = UIAction(
            title: "按自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: sortPreference == .custom ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .custom)
        }
        
        return UIMenu(
            title: "排序方式",
            children: [customAction, modificationDateAction, creationDateAction]
        )
    }
    
    internal func createOperationMenu() -> UIMenu {
        let attributes: UIMenuElement.Attributes = gridView.selectedAssets.isEmpty ? .disabled : []
        var menuChildren: [UIMenuElement] = []
        
        let addToAlbum = UIAction(title: "添加到相簿", image: UIImage(systemName: "plus.rectangle.on.folder"), attributes: attributes) { [weak self] _ in
            self?.onAddToAlbumSelectedAssets()
        }
        
        let copy = UIAction(title: "拷贝", image: UIImage(systemName: "doc.on.doc"), attributes: attributes) { [weak self] _ in
            self?.onCopy()
        }
        
        let duplicate = UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc.fill"), attributes: attributes) { [weak self] _ in
            self?.onDuplicate()
        }
        
        let paste = UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.onPaste()
        }
        
        let sort = UIAction(title: "排序", image: UIImage(systemName: "arrow.up.arrow.down"), attributes: attributes) { [weak self] _ in
            self?.onOrder()
        }
        
        let delete = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: [attributes, .destructive].compactMap { $0 }.reduce([], { $0.union($1) })) { [weak self] _ in
            self?.onDelete()
        }
        
        let move = UIAction(title: "剪切", image: UIImage(systemName: "scissors"), attributes: attributes) { [weak self] _ in
            self?.onMove()
        }
        
        let tagAction = UIAction(title: "添加标签", image: UIImage(systemName: "tag"), attributes: attributes) { [weak self] _ in
            self?.onTagSelectedAssets()
        }

        menuChildren = [addToAlbum, tagAction]
        if sortPreference == .custom, supportsHierarchyNumbering {
            menuChildren.append(createHierarchyMenu(attributes: attributes))
        }
        menuChildren += [delete, move, paste, copy, duplicate, sort]
        return UIMenu(title: "操作选项", children: menuChildren)
    }

    internal func createHierarchyMenu(attributes: UIMenuElement.Attributes) -> UIMenu {
        let setLevel1 = UIAction(title: "批量设为主级", image: UIImage(systemName: "list.number"), attributes: attributes) { [weak self] _ in
            self?.onBatchSetLevel(1)
        }
        let setLevel2 = UIAction(title: "批量设为子级", image: UIImage(systemName: "list.bullet.indent"), attributes: attributes) { [weak self] _ in
            self?.onBatchSetLevel(2)
        }
        let clear = UIAction(title: "批量取消编号", image: UIImage(systemName: "xmark.circle"), attributes: attributes) { [weak self] _ in
            self?.onBatchClearLevel()
        }
        return UIMenu(title: "层级", children: [setLevel1, setLevel2, clear])
    }
    
    internal func updateOperationMenu() {
        menuBarButton.menu = createOperationMenu()
    }
    
    internal func onAddPhotos() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        configuration.selection = .ordered
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    internal func onAddToAlbumSelectedAssets() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else {
            showAlert(title: "添加失败", message: "请先选择要添加的照片")
            return
        }
        showAddToAlbumPicker(for: selectedAssets)
    }

    internal func onTagSelectedAssets() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else { return }
        showTagAssignPicker(for: selectedAssets.map { $0.localIdentifier })
    }

    /// 弹出标签分配面板（为多张照片打标签）
    internal func showTagAssignPicker(for assetIdentifiers: [String]) {
        let vc = TagAssignViewController(assetIdentifiers: assetIdentifiers)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    internal func onBatchSetLevel(_ level: Int) {
        let orderedSelected = orderedSelectedAssets()
        guard !orderedSelected.isEmpty else { return }
        for asset in orderedSelected {
            PhotoNumberingService.shared.setLevel(level, for: asset, in: collection)
        }
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchClearLevel() {
        let orderedSelected = orderedSelectedAssets()
        guard !orderedSelected.isEmpty else { return }
        for asset in orderedSelected {
            PhotoNumberingService.shared.clearLevel(for: asset, in: collection)
        }
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func orderedSelectedAssets() -> [PHAsset] {
        let selectedIDs = Set(gridView.selectedAssets.map { $0.localIdentifier })
        return assets.filter { selectedIDs.contains($0.localIdentifier) }
    }
    
    internal func syncSuccess(message: String) {
        showAlert(title: "同步成功", message: message)
    }
    
    internal func syncFailed(message: String) {
        showAlert(title: "同步失败", message: message)
    }
    
    // MARK: - Helper Methods
    
    internal func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Search Methods
    
    internal func performSearch(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if let index = Int(trimmed), index > 0 {
            // 数字：跳转到第 N 张照片
            gridView.scrollTo(index: index - 1)
            return
        }

        if trimmed.isEmpty {
            // 清空搜索：移除标签过滤
            filterState = TagFilterState()
            return
        }

        // 文本：按标签名匹配并过滤
        let allTags = PhotoTagService.shared.loadTags()
        let matchedTagIDs = Set(allTags.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }.map { $0.id })
        filterState = TagFilterState(selectedTagIDs: matchedTagIDs, matchRule: .any)
    }

    // MARK: - 标签过滤

    /// 根据 filterState 过滤 assets 并更新 gridView
    @objc internal func applyTagFilter() {
        if filterState.isActive {
            let matchedIDs = PhotoTagService.shared.filteredIdentifiers(by: filterState)
            gridView.assets = assets.filter { matchedIDs.contains($0.localIdentifier) }
        } else {
            gridView.assets = assets
        }
        updateTagFilterButtonAppearance()
        syncSearchBarVisibility()
    }

    /// 弹出标签筛选面板
    @objc private func didTapTagFilter() {
        let panel = TagFilterPanelViewController(currentState: filterState)
        panel.candidateIdentifiers = assets.map { $0.localIdentifier }
        panel.delegate = self
        if let sheet = panel.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(panel, animated: true)
    }

    /// 将 filterState 中的标签同步为搜索框 Token
    private func syncSearchTokens() {
        let tags = PhotoTagService.shared.loadTags()
        let activeTags = tags.filter { filterState.selectedTagIDs.contains($0.id) }
        searchTextField.setFilterTokens(from: activeTags)
        searchTextField.markTokensSynced()
    }

    /// 有激活过滤时搜索栏始终可见
    private func syncSearchBarVisibility() {
        if filterState.isActive {
            searchTextField.isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.searchTextField.transform = .identity
                self.searchTextField.alpha = 1.0
            }
            isSearchBarVisible = true
        }
    }

    /// 更新标签过滤按钮的激活状态外观
    private func updateTagFilterButtonAppearance() {
        tagFilterBarButton.image = filterState.isActive
            ? UIImage(systemName: "tag.fill")
            : UIImage(systemName: "tag")
        tagFilterBarButton.tintColor = filterState.isActive ? .systemBlue : nil
    }

}

extension BasePhotoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            self?.addPickedPhotosToCurrentAlbum(results)
        }
    }
    
    private func addPickedPhotosToCurrentAlbum(_ results: [PHPickerResult]) {
        let selectedIdentifiers = results.compactMap { $0.assetIdentifier }
        guard !selectedIdentifiers.isEmpty else { return }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: selectedIdentifiers, options: nil)
        var selectedAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            selectedAssets.append(asset)
        }
        guard !selectedAssets.isEmpty else { return }
        
        let existingAssets = PHAsset.fetchAssets(in: collection, options: nil)
        var existingIDs = Set<String>()
        existingAssets.enumerateObjects { asset, _, _ in
            existingIDs.insert(asset.localIdentifier)
        }
        
        let assetsToAdd = selectedAssets.filter { !existingIDs.contains($0.localIdentifier) }
        if assetsToAdd.isEmpty {
            showAlert(title: "提示", message: "所选照片已在该相簿中")
            return
        }
        
        ensureReadWritePermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.showAlert(title: "权限不足", message: "请允许照片读写权限后重试")
                return
            }
            
            let loadingAlert = UIAlertController(title: "添加中", message: "正在将照片添加到相簿...", preferredStyle: .alert)
            self.present(loadingAlert, animated: true)
            
            var finished = false
            let finish: (String, String, Bool) -> Void = { title, message, shouldReload in
                guard !finished else { return }
                finished = true
                loadingAlert.dismiss(animated: true) {
                    if shouldReload {
                        self.loadPhoto()
                    }
                    if !shouldReload {
                        self.showAlert(title: title, message: message)
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                finish("添加失败", "操作超时，请稍后重试", false)
            }
            
            PHPhotoLibrary.shared().performChanges({
                guard let request = PHAssetCollectionChangeRequest(for: self.collection) else { return }
                request.addAssets(assetsToAdd as NSArray)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        finish("添加成功", "已添加 \(assetsToAdd.count) 张照片", true)
                    } else {
                        finish("添加失败", error?.localizedDescription ?? "无法添加照片", false)
                    }
                }
            })
        }
    }
    
    private func ensureReadWritePermission(_ completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        default:
            completion(false)
        }
    }
}

// MARK: - PhotoGridViewDelegate

extension BasePhotoViewController: PhotoGridViewDelegate {
    @objc(photoGridView:didSelectItemAtIndexPath:) internal func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    @objc(photoGridView:didSelectItemAtAsset:) internal func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {
        // 打开图片浏览器
        if selectionMode == .none {
            if let index = self.assets.firstIndex(of: asset) {
                // 获取选中图片的帧和图片
                var sourceFrame: CGRect = .zero
                var sourceImage: UIImage? = nil
                
                // 尝试获取选中的cell的frame
                if let cellFrame = photoGridView.getCellFrame(for: asset) {
                    sourceFrame = view.convert(cellFrame, from: photoGridView)
                }
                
                // 尝试获取缩略图
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { (image, _) in
                    sourceImage = image
                }
                
                let nav = GalleryViewerViewController.makePresentingNavigationContainer(
                    assets: self.assets,
                    initialIndex: index,
                    sourceFrame: sourceFrame,
                    sourceImage: sourceImage
                )
                present(nav, animated: true)
            }
        }
    }
    
    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didDeselectItemAt indexPath: IndexPath) {
        updateOperationMenu()
    }
    
    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {
        updateOperationMenu()
        updateUndoRedoButtons()
        // 更新全选/取消全选按钮状态
        if selectionMode != .none {
            updateSelectAllButton()
        }
    }
    
    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didSetAnchor asset: PHAsset) {
        updateOperationMenu()
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didRequestAddTagFor asset: PHAsset) {
        showTagAssignPicker(for: [asset.localIdentifier])
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didRequestDelete asset: PHAsset) {
        showDeleteConfirmationAlert(for: [asset])
    }

    @objc internal func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        guard let index = self.assets.firstIndex(of: after) else {
            showAlert(title: "粘贴失败", message: "无法找到目标照片")
            return
        }
        
        let insertIndex = index + 1
        
        let loadingAlert = UIAlertController(title: "粘贴中", message: "正在粘贴照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // 先更新本地数据和自定义排序
        var newAssets = self.assets
        newAssets.insert(contentsOf: assets, at: insertIndex)
        
        // 立即更新自定义排序数据
        PhotoOrder.set(order: newAssets, for: self.collection)
        
        // 提交到系统相册
        PHPhotoLibrary.shared().performChanges({
            guard let changeRequest = PHAssetCollectionChangeRequest(for: self.collection) else {
                return
            }
            changeRequest.insertAssets(assets as NSArray, at: IndexSet(integer: insertIndex))
        }, completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true)
                
                guard let self = self else { return }
                
                if success {
                    // 直接使用我们维护的顺序，不重新加载
                    self.assets = newAssets
                    
                    // 记录撤销操作
                    let undoAction = UndoAction.paste(assets: assets, into: self.collection, at: insertIndex)
                    self.addAction(undoAction)
                    
                    // 清除选中状态
                    self.gridView.clearSelected()
                    
                    // 重要：粘贴操作后，自动切换到自定义排序模式
                    if self.sortPreference != .custom {
                        self.sortPreference = .custom
                        // 同步排序偏好到 PhotoGridView
                        self.gridView.sortPreference = .custom
                        // 保存排序偏好
                        PhotoSortPreference.custom.set(preference: self.collection)
                    }
                    
                    self.showAlert(title: "粘贴成功", message: "已成功粘贴 \(assets.count) 张照片")
                } else {
                    // 失败时回滚自定义排序数据
                    PhotoOrder.set(order: self.assets, for: self.collection)
                    self.showAlert(title: "粘贴失败", message: error?.localizedDescription ?? "无法粘贴照片")
                }
                
                self.updateUndoRedoButtons()
                self.updateOperationMenu()
            }
        })
    }
}

// MARK: - SearchBarViewDelegate

extension BasePhotoViewController: SearchBarViewDelegate {
    @objc internal func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String) {
        performSearch(with: text)
    }

    func searchBarViewDidRemoveToken(_ searchBarView: SearchBarView, tagID: String) {
        filterState.selectedTagIDs.remove(tagID)
        // filterState didSet 会触发 applyTagFilter + syncSearchTokens
    }
}

// MARK: - TagFilterPanelDelegate

extension BasePhotoViewController: TagFilterPanelDelegate {
    func tagFilterPanel(_ panel: TagFilterPanelViewController, didApply state: TagFilterState) {
        filterState = state
    }
}

// MARK: - UIScrollViewDelegate

extension BasePhotoViewController: UIScrollViewDelegate {
    @objc internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else { return }
        let currentOffsetY = scrollView.contentOffset.y
        let offsetDifference = currentOffsetY - lastContentOffsetY
        
        let shouldShow = offsetDifference > 0 && currentOffsetY > 0
        if shouldShow != isSearchBarVisible {
            isSearchBarVisible = shouldShow
            if shouldShow {
                moveSearchBarToVisible()
            } else {
                moveSearchBarToHidden()
            }
        }
        lastContentOffsetY = currentOffsetY
    }
    
    private func moveSearchBarToVisible() {
        searchTextField.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.searchTextField.transform = .identity
            self.searchTextField.alpha = 1.0
        }
    }

    private func moveSearchBarToHidden() {
        let searchBarHeight = searchTextField.frame.height + 8
        UIView.animate(withDuration: 0.3, animations: {
            self.searchTextField.transform = CGAffineTransform(translationX: 0, y: -searchBarHeight)
            self.searchTextField.alpha = 0.0
        }, completion: { _ in
            self.searchTextField.isHidden = true
        })
    }
}
