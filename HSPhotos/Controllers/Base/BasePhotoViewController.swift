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

    internal lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = sortDescriptors(for: sortPreference)
        return options
    }()

    internal let viewModel: PhotoGridViewModel

    internal lazy var gridRouter: PhotoGridRouter = {
        let router = PhotoGridRouter()
        router.host = self
        return router
    }()

    /// Model 状态（层级 API、PhotoGridView.bind）；请优先经 `viewModel` 改成员与筛选。
    internal var session: AlbumSession { viewModel.session }

    internal var collection: PHAssetCollection { viewModel.collection }

    internal var albumOperations: PhotoAlbumOperations { viewModel.albumOperations }

    internal var sortPreference: PhotoSortPreference {
        get { viewModel.sortPreference }
        set { viewModel.sortPreference = newValue }
    }

    /// 是否支持层级编号功能。首页（图库）不支持，相册内支持。
    internal var supportsHierarchyNumbering: Bool {
        get { viewModel.supportsHierarchyNumbering }
        set { viewModel.supportsHierarchyNumbering = newValue }
    }

    /// 全量照片（排序后的原始数据），始终保持完整
    internal var assets: [PHAsset] {
        get { viewModel.memberAssets }
        set { viewModel.memberAssets = newValue }
    }

    /// 标签过滤状态，变化时自动重新过滤并刷新 gridView
    internal var filterState: TagFilterState {
        get { viewModel.filterState }
        set {
            let previous = viewModel.filterState
            viewModel.filterState = newValue
            if previous != newValue {
                syncSearchTokens()
            }
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
        viewModel = PhotoGridViewModel(collection: collection)
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

        viewModel.onGridNeedsRefresh = { [weak self] in
            self?.refreshGridFromSession()
        }

        viewModel.loadNumberingFromStorage()
        gridView.bind(to: viewModel.session)

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
        viewModel.saveNumberingToStorage()
        // 离开本页时先收起底部工具条（含 push 出子页），返回时由 viewWillAppear 再按选择模式恢复
        navigationController?.setToolbarHidden(true, animated: animated)
        if isMovingFromParent || isBeingDismissed {
            toolbarItems = nil
        }
    }

    deinit {
        // 系统会自动处理trait变化注册的清理
    }

    // MARK: - 子类可覆盖（须在主类文件中声明，extension 中无法 override）

    internal func sortDescriptors(for preference: PhotoSortPreference) -> [NSSortDescriptor]? {
        preference.sortDescriptors
    }

    internal func createSortMenu() -> UIMenu {
        AlbumGridMenuBuilder.makeSortMenu(state: gridMenuState(), actions: gridMenuActions())
    }

    internal func createOperationMenu() -> UIMenu {
        AlbumGridMenuBuilder.makeOperationMenu(state: gridMenuState(), actions: gridMenuActions())
    }

    internal func updateOperationMenu() {
        menuBarButton.menu = createOperationMenu()
    }

    internal func onChanged(sort preference: PhotoSortPreference) {
        self.sortPreference = preference
        refreshFetchOptionsForCurrentSortPreference()

        let collection = self.collection
        let options = self.fetchOptions

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var newAssets: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                newAssets.append(asset)
            }

            DispatchQueue.main.async {
                self.assets = newAssets
                self.refreshGridFromSession()
                preference.set(preference: self.collection)
                self.updateOperationMenu()
            }
        }
    }

    internal func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton], animated: true)
            navigationItem.leftBarButtonItem = nil
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton], animated: true)
            updateSelectAllButton()
        }
        updateSelectionQuickNavToolbar()
        syncSelectionQuickNavBarButtonsEnabled()
    }

    internal func updateSelectAllButton() {
        let isAllSelected = isAllAssetsSelected()
        if isAllSelected {
            navigationItem.setLeftBarButtonItems([deselectAllBarButton], animated: true)
        } else {
            navigationItem.setLeftBarButtonItems([selectAllBarButton], animated: true)
        }
        if selectionMode != .none {
            syncSelectionQuickNavBarButtonsEnabled()
        }
    }

    internal func refreshSortUIAfterPasteIfNeeded() {}
}
