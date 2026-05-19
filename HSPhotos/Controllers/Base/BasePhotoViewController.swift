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

    /// 底部工具条：在可见连续选区间的头/尾之间跳转（`chevron.up` = 上一处，`chevron.down` = 下一处）。
    internal lazy var selectionQuickNavPreviousBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: self,
            action: #selector(didTapSelectionQuickNavPrevious)
        )
        button.accessibilityLabel = "上一处"
        return button
    }()

    internal lazy var selectionQuickNavNextBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(didTapSelectionQuickNavNext)
        )
        button.accessibilityLabel = "下一处"
        return button
    }()

    private lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = sortDescriptors(for: sortPreference)
        return options
    }()

    internal let collection: PHAssetCollection
    internal var albumOperations: PhotoAlbumOperations { PhotoAlbumOperations(collection: collection) }
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

    internal var lastContentOffsetY: CGFloat = 0
    internal var isSearchBarVisible = false
    internal var searchTextFieldTopConstraint: NSLayoutConstraint!
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

        // 进入相册时从 UserDefaults 加载到内存；之后每次改编号默认仍会写回（批量操作用 batch 合并写入）
        PhotoNumberingService.shared.loadForCollection(collection)

        // 同步初始排序偏好到 PhotoGridView
        gridView.sortPreference = sortPreference
        // 设置当前相册引用与层级支持（必须在loadPhoto之前设置）
        gridView.currentCollection = collection
        gridView.supportsHierarchyNumbering = supportsHierarchyNumbering

        gridView.onSelectionQuickNavToolbarRefresh = { [weak self] in
            self?.syncSelectionQuickNavBarButtonsEnabled()
        }

        loadPhoto()
        setupUndoManager()
    }

    @objc private func didTapSelectionQuickNavPrevious() {
        selectionQuickNavPerform { $0.performSelectionQuickNavPrevious() }
    }

    @objc private func didTapSelectionQuickNavNext() {
        selectionQuickNavPerform { $0.performSelectionQuickNavNext() }
    }

    private func selectionQuickNavPerform(_ action: (PhotoGridView) -> Void) {
        action(gridView)
        syncSelectionQuickNavBarButtonsEnabled()
    }

    internal func syncSelectionQuickNavBarButtonsEnabled() {
        gridView.syncSelectionQuickNavBarButtons(
            previous: selectionQuickNavPreviousBarButton,
            next: selectionQuickNavNextBarButton
        )
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

        // 初始状态下的按钮顺序
        navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton], animated: true)

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
        // 离开本页时先收起底部工具条（含 push 出子页），返回时由 viewWillAppear 再按选择模式恢复
        navigationController?.setToolbarHidden(true, animated: animated)
        if isMovingFromParent || isBeingDismissed {
            toolbarItems = nil
        }
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
                    self.loadPhoto()
                } else {
                    self.showAlert(title: "重做失败", message: error ?? "无法重做操作")
                }
                // 更新按钮状态
                self.updateUndoRedoButtons()
            }
        }
    }

    /// 重建 `PHFetchOptions`，使 `loadPhoto` 与当前 `sortPreference` 一致。
    /// 凡不经由 `onChanged` 而直接修改 `sortPreference`（例如排序同步后、粘贴后强制切到自定义）都必须调用，否则会仍按旧描述符 fetch。
    internal func refreshFetchOptionsForCurrentSortPreference() {
        let options = PHFetchOptions()
        options.sortDescriptors = sortDescriptors(for: sortPreference)
        fetchOptions = options
    }

    internal func loadPhoto() {
        // 在后台线程执行耗时操作，避免阻塞主线程造成卡顿
        let collection = self.collection
        let options = self.fetchOptions

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var newAssets: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
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
        refreshFetchOptionsForCurrentSortPreference()

        let collection = self.collection
        let options = self.fetchOptions

        // 在后台线程执行耗时操作，避免切换排序时卡顿
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var newAssets: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
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
            let originalAssets = assets
            let sortedAssets = try gridView.sort()
            assets = sortedAssets

            let loadingAlert = UIAlertController(title: "同步中", message: "正在将照片顺序同步到系统相册...", preferredStyle: .alert)
            present(loadingAlert, animated: true)

            albumOperations.syncCustomOrder(sortedAssets: sortedAssets, originalAssets: originalAssets) { [weak self] outcome in
                guard let self else { return }
                loadingAlert.dismiss(animated: true) {
                    self.applyAlbumOperationOutcome(outcome)
                    if outcome.shouldApplyCustomSort {
                        self.updateOperationMenu()
                    }
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
        let loadingAlert = UIAlertController(title: "添加中", message: "正在添加到相簿...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        let operations = PhotoAlbumOperations(collection: destinationCollection)
        operations.add(assets: assets, to: destinationCollection) { [weak self] outcome in
            loadingAlert.dismiss(animated: true) {
                guard let self else { return }
                if outcome.message == "所选照片已在目标相簿中" {
                    self.showAlert(title: "提示", message: outcome.message ?? "")
                    return
                }
                self.applyAlbumOperationOutcome(outcome, failureTitle: "添加失败")
            }
        }
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

        albumOperations.move(assets: assets, to: destinationCollection) { [weak self] outcome in
            loadingAlert.dismiss(animated: true) {
                self?.applyAlbumOperationOutcome(outcome, failureTitle: "移动失败")
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

        albumOperations.delete(assets: assets) { [weak self] outcome in
            loadingAlert.dismiss(animated: true) {
                self?.applyAlbumOperationOutcome(outcome, failureTitle: "删除失败")
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
            // 普通模式：精简为「选择 + 更多」
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton], animated: true)
            // 恢复默认的返回按钮
            navigationItem.leftBarButtonItem = nil
        } else {
            // 选择模式：取消 + 范围选择 + 更多（快速定位在底部工具条）
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton], animated: true)
            // 根据当前选择状态显示全选或取消全选按钮
            updateSelectAllButton()
        }
        updateSelectionQuickNavToolbar()
        syncSelectionQuickNavBarButtonsEnabled()
    }

    /// 选择模式下在导航控制器底部工具条显示「上一处 / 下一处」。
    internal func updateSelectionQuickNavToolbar() {
        guard let nav = navigationController else { return }
        if selectionMode == .none {
            nav.setToolbarHidden(true, animated: true)
            toolbarItems = nil
            return
        }
        let flexLeading = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flexTrailing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [flexLeading, selectionQuickNavPreviousBarButton, selectionQuickNavNextBarButton, flexTrailing]
        nav.setToolbarHidden(false, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSelectionQuickNavToolbar()
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
        if selectionMode != .none {
            syncSelectionQuickNavBarButtonsEnabled()
        }
    }

    /// 检查是否所有可见资产都已被选中
    internal func isAllAssetsSelected() -> Bool {
        gridView.selectedAssetCount == gridView.allAssets.count && !gridView.allAssets.isEmpty
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

    /// 子类（如图库首页）可覆盖，以对同一 `PhotoSortPreference` 使用与枚举默认不同的 fetch 描述符（例如「最近添加」用 `nil` 对齐系统）。
    internal func sortDescriptors(for preference: PhotoSortPreference) -> [NSSortDescriptor]? {
        preference.sortDescriptors
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

        let newestSortAction = UIAction(
            title: "按最新的排最前排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .newest ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .newest)
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
            children: [customAction, newestSortAction, creationDateAction]
        )
    }

    internal func createOperationMenu() -> UIMenu {
        let attributes: UIMenuElement.Attributes = gridView.hasSelectedAssets ? [] : .disabled
        var menuChildren: [UIMenuElement] = []

        let undoAction = UIAction(title: "撤销", image: UIImage(systemName: "arrow.uturn.left"), attributes: canUndo ? [] : .disabled) { [weak self] _ in
            self?.undoAction()
        }
        let redoAction = UIAction(title: "重做", image: UIImage(systemName: "arrow.uturn.right"), attributes: canRedo ? [] : .disabled) { [weak self] _ in
            self?.redoAction()
        }
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

        menuChildren = [undoAction, redoAction, addToAlbum, tagAction]
        if sortPreference == .custom, supportsHierarchyNumbering {
            menuChildren.append(createHierarchyMenu(attributes: attributes))
        }
        menuChildren += [delete, move, paste, copy, duplicate, sort]
        return UIMenu(title: "操作选项", children: menuChildren)
    }

    internal func createHierarchyMenu(attributes: UIMenuElement.Attributes) -> UIMenu {
        let selected = orderedSelectedAssets()
        guard !selected.isEmpty else { return UIMenu(title: "层级", children: []) }

        let hierarchy = hierarchyEditor
        let firstAsset = selected[0]
        let prevLv = hierarchy.levelBefore(firstAsset)
        let anyInHierarchy = selected.contains { PhotoNumberingService.shared.level(for: $0, in: collection) > 0 }

        // 升级选项：存在不仅是主级(Level 1)的已编号项
        let anyCanUp = selected.contains { PhotoNumberingService.shared.level(for: $0, in: collection) > 1 }

        var children: [UIMenuElement] = []

        // 1. 设置主级 (Root)
        let setMain = UIAction(title: "批量设为主级", image: UIImage(systemName: "list.number"), attributes: attributes) { [weak self] _ in
            self?.onBatchSetLevel(to: 1)
        }
        children.append(setMain)

        // 2. 提升/下降 (缩进平移)
        if anyCanUp {
            let promote = UIAction(title: "批量提升层级", image: UIImage(systemName: "arrow.left"), attributes: attributes) { [weak self] _ in
                self?.onBatchPromoteLevel()
            }
            children.append(promote)
        }

        // 下降条件：第一个选中的节点深度不能超过上方参考节点 + 1
        let firstLv = PhotoNumberingService.shared.level(for: firstAsset, in: collection)
        if firstLv < prevLv + 1 {
            let demote = UIAction(title: "批量下降层级", image: UIImage(systemName: "arrow.right"), attributes: attributes) { [weak self] _ in
                self?.onBatchDemoteLevel()
            }
            children.append(demote)
        }

        // 3. 上下文相关：设为同级/子级
        if prevLv > 0 {
            let setSame = UIAction(title: "批量设为同级", image: UIImage(systemName: "arrow.right.to.line"), attributes: attributes) { [weak self] _ in
                self?.onBatchSetLevel(to: prevLv)
            }
            children.append(setSame)

            let setSub = UIAction(title: "批量设为子级", image: UIImage(systemName: "list.bullet.indent"), attributes: attributes) { [weak self] _ in
                self?.onBatchSetLevel(to: prevLv + 1)
            }
            children.append(setSub)
        }

        // 4. 清除
        if anyInHierarchy {
            let clearAction = UIAction(title: "批量取消编号", image: UIImage(systemName: "xmark.circle"), attributes: attributes.union(.destructive)) { [weak self] _ in
                self?.onBatchClearLevel()
            }
            children.append(clearAction)
        }

        return UIMenu(title: "层级操作", children: children)
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

    private var hierarchyEditor: PhotoHierarchyBatchEditing {
        PhotoHierarchyBatchEditing(collection: collection, orderedAssets: assets)
    }

    private func onBatchSetLevel(to level: Int) {
        hierarchyEditor.applySetLevel(level, to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchPromoteLevel() {
        hierarchyEditor.applyPromote(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchDemoteLevel() {
        hierarchyEditor.applyDemote(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func onBatchClearLevel() {
        hierarchyEditor.applyClear(to: orderedSelectedAssets())
        gridView.refreshParagraphDisplay()
        updateOperationMenu()
    }

    internal func orderedSelectedAssets() -> [PHAsset] {
        let selectedIDs = gridView.selectedMembershipIdentifiers
        guard !selectedIDs.isEmpty else { return [] }
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
    @objc internal func didTapTagFilter() {
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

    /// 标签过滤状态变化后刷新操作菜单
    private func updateTagFilterButtonAppearance() {
        searchTextField.isFilterActive = filterState.isActive
        updateOperationMenu()
    }

    internal func performPaste(assets: [PHAsset], insertIndex: Int, updatedLocalAssets: [PHAsset]) {
        guard !assets.isEmpty else { return }

        let loadingAlert = UIAlertController(title: "粘贴中", message: "正在粘贴照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        PhotoChangesService.paste(assets: assets, into: collection, at: insertIndex) { [weak self] success, message in
            loadingAlert.dismiss(animated: true) {
                guard let self else { return }

                if success {
                    self.assets = updatedLocalAssets
                    self.gridView.clearSelected()
                    self.applyCustomSortPreferenceAfterPasteIfNeeded()
                    self.showAlert(title: "粘贴成功", message: "已成功粘贴 \(assets.count) 张照片")
                } else {
                    self.showAlert(title: "粘贴失败", message: message ?? "无法粘贴照片")
                }

                self.updateUndoRedoButtons()
                self.updateOperationMenu()
            }
        }
    }

    internal func applyCustomSortPreferenceAfterPasteIfNeeded() {
        applyCustomSortAfterWriteback()
    }

    internal func applyCustomSortAfterWriteback() {
        guard sortPreference != .custom else { return }
        sortPreference = .custom
        gridView.sortPreference = .custom
        PhotoSortPreference.custom.set(preference: collection)
        refreshFetchOptionsForCurrentSortPreference()
        refreshSortUIAfterPasteIfNeeded()
    }

    internal func refreshSortUIAfterPasteIfNeeded() {}

    /// 应用写操作结果：自定义排序、撤销、清选、重载与失败提示。
    internal func applyAlbumOperationOutcome(
        _ outcome: PhotoAlbumOperationOutcome,
        failureTitle: String = "操作失败"
    ) {
        if outcome.shouldApplyCustomSort {
            applyCustomSortAfterWriteback()
        }
        if let undoAction = outcome.undoAction {
            addAction(undoAction)
        }
        if outcome.shouldClearSelection {
            gridView.clearSelected()
        }
        if outcome.shouldReloadAssets {
            loadPhoto()
        }
        updateUndoRedoButtons()
        if !outcome.success, let message = outcome.message, !message.isEmpty {
            showAlert(title: failureTitle, message: message)
        }
    }
}
