//
//  AlbumListViewController.swift
//  HSPhotos
//
//  Created by Hans on 2025/8/27.
//

import UIKit
import Photos
import PhotosUI


class AlbumListViewController: UIViewController {

    private var displayedItems: [AlbumListItem] = []
    private var targetAlbumForAddingPhotos: PHAssetCollection?
    private let backgroundGradientLayer = CAGradientLayer()
    private let collectionList: PHCollectionList?
    private let collectionOperations = AlbumCollectionOperations()
    private lazy var viewModel = AlbumListViewModel(parentList: collectionList)
    private lazy var router = AlbumListRouter(isPickerMode: isPickerMode, onAlbumPicked: onAlbumPicked)

    private let isPickerMode: Bool
    private let onAlbumPicked: ((PHAssetCollection) -> Void)?
    private lazy var addButton: UIBarButtonItem = {
        let addAlbumAction = UIAction(title: "新建相簿", image: UIImage(systemName: "rectangle.stack.badge.plus")) { [weak self] _ in
            self?.createAlbum()
        }
        let addFolderAction = UIAction(title: "新建文件夹", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
            self?.createFolder()
        }
        let addMenu = UIMenu(title: "", children: [addAlbumAction, addFolderAction])
        return UIBarButtonItem(systemItem: .add, primaryAction: nil, menu: addMenu)
    }()
    private lazy var menuButton: UIBarButtonItem = {
        UIBarButtonItem(image: UIImage(systemName: "ellipsis"), primaryAction: nil, menu: createMenu())
    }()

    private lazy var selectBarButton: UIBarButtonItem = {
        UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(enterAlbumMultiSelectMode))
    }()
    private lazy var toggleExpandCollapseButton: UIBarButtonItem = {
        let image = UIImage(systemName: "chevron.down.circle")
        let button = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(toggleExpandCollapse)
        )
        button.accessibilityLabel = "展开全部"
        return button
    }()

    private lazy var doneMultiSelectBarButton: UIBarButtonItem = {
        let style: UIBarButtonItem.Style
        if #available(iOS 26.0, *) {
            style = .prominent
        } else {
            style = .done
        }
        return UIBarButtonItem(title: "完成", style: style, target: self, action: #selector(finishAlbumMultiSelect))
    }()

    
    init(
        collectionList: PHCollectionList? = nil,
        isPickerMode: Bool = false,
        onAlbumPicked: ((PHAssetCollection) -> Void)? = nil
    ) {
        self.collectionList = collectionList
        self.isPickerMode = isPickerMode
        self.onAlbumPicked = onAlbumPicked
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var albumListView: AlbumListView = {
        let view = AlbumListView()
        view.translatesAutoresizingMaskIntoConstraints = false;
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupTraitChangeObserver()
        registerPhotoLibraryObserver()
        viewModel.onDidUpdate = { [weak self] in
            self?.applyCurrentDisplayData(animated: false)
        }
        loadAlbums()
    }
    
    private func setupUI(){
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
        
        view.addSubview(albumListView)
        NSLayoutConstraint.activate([
            albumListView.topAnchor.constraint(equalTo: view.topAnchor),
            albumListView.leftAnchor.constraint(equalTo: view.leftAnchor),
            albumListView.rightAnchor.constraint(equalTo: view.rightAnchor),
            albumListView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupNavigationBar() {
        title = isPickerMode ? (collectionList?.localizedTitle ?? "选择相簿") : (collectionList?.localizedTitle ?? "相册")
        navigationController?.navigationBar.prefersLargeTitles = true
        
        if isPickerMode {
            if collectionList == nil {
                navigationItem.leftBarButtonItem = UIBarButtonItem(
                    title: "取消",
                    style: .plain,
                    target: self,
                    action: #selector(cancelPicker)
                )
            }
            navigationItem.rightBarButtonItems = nil
            return
        }
        updateToggleExpandCollapseButtonState()
        
        // 允许视图内容延伸到四周
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
    }
    
    // 创建菜单
    private func createMenu() -> UIMenu {
        // 创建视图模式子菜单
        
        let coverPhotoAction = UIAction(title: "封面照片", image: UIImage(systemName: "photo")) { [weak self] _ in
            self?.switchToCoverPhotoMode()
        }
        
        let listViewAction = UIAction(
            title: "列表视图",
            subtitle: "文件夹可在此展开或收起",
            image: UIImage(systemName: "list.bullet")
        ) { [weak self] _ in
            self?.switchToListViewMode()
        }
        
        let viewModeMenu = UIMenu(title: "视图模式", options: .displayInline, children: [coverPhotoAction, listViewAction])
        
        // 创建排序选项
        let sortByModificationDateAction = UIAction(title: "按修改日期排序", image: UIImage(systemName: "clock")) { [weak self] _ in
            self?.sortByModificationDate()
        }
        
        let sortByNameAction = UIAction(title: "按名称排序", image: UIImage(systemName: "textformat")) { [weak self] _ in
            self?.sortByName()
        }
        
        let sortByCustomAction = UIAction(title: "按自定义顺序排序", image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
            self?.sortByCustomOrder()
        }

        return UIMenu(title: "", children: [viewModeMenu, sortByModificationDateAction, sortByNameAction, sortByCustomAction])
    }

    @objc private func enterAlbumMultiSelectMode() {
        albumListView.setMultiSelectMode(true)
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = doneMultiSelectBarButton
        title = "选择项目"
        refreshMultiSelectToolbarForCurrentLayout()
        updateToggleExpandCollapseButtonState()
    }

    @objc private func finishAlbumMultiSelect() {
        albumListView.setMultiSelectMode(false)
        navigationItem.hidesBackButton = false
        navigationItem.leftBarButtonItem = nil
        refreshMultiSelectToolbarForCurrentLayout()
        title = isPickerMode ? (collectionList?.localizedTitle ?? "选择相簿") : (collectionList?.localizedTitle ?? "相册")
        updateToggleExpandCollapseButtonState()
    }

    private func updateMultiSelectTitle() {
        let n = albumListView.multiSelectedIdentifiers.count
        title = n == 0 ? "选择项目" : "已选 \(n) 项"
    }

    /// 多选时不使用底部工具栏（展开/收起在导航栏按钮）
    private func refreshMultiSelectToolbarForCurrentLayout() {
        navigationController?.setToolbarHidden(true, animated: true)
        toolbarItems = nil
    }

    /// 当前选中项里可展开的文件夹 ID（用于选择模式下的展开/收起）
    private func selectedExpandableFolderIDs() -> Set<String> {
        viewModel.selectedExpandableFolderIDs(
            in: displayedItems,
            selectedIdentifiers: albumListView.multiSelectedIdentifiers
        )
    }

    
    // 切换到封面照片模式
    private func switchToCoverPhotoMode() {
        albumListView.layoutMode = .grid
        applyCurrentDisplayData()
        if albumListView.isMultiSelectMode { refreshMultiSelectToolbarForCurrentLayout() }
    }
    
    // 切换到列表视图模式
    private func switchToListViewMode() {
        albumListView.layoutMode = .list
        applyCurrentDisplayData()
        if albumListView.isMultiSelectMode { refreshMultiSelectToolbarForCurrentLayout() }
    }
    

    
    // 按修改日期排序
    private func sortByModificationDate() {
        viewModel.sortKind = .modificationDate
        loadAlbums()
    }

    private func sortByName() {
        viewModel.sortKind = .name
        loadAlbums()
    }

    private func sortByCustomOrder() {
        viewModel.sortKind = .custom
        loadAlbums()
    }

    private func applyCurrentDisplayData(animated: Bool = false) {
        displayedItems = viewModel.displayedItems(layoutMode: albumListView.layoutMode)
        albumListView.setCollections(displayedItems, animated: animated)
        updateToggleExpandCollapseButtonState()
    }

    @objc private func toggleExpandCollapse() {
        guard albumListView.layoutMode == .list else { return }

        if albumListView.isMultiSelectMode {
            let ids = selectedExpandableFolderIDs()
            guard viewModel.toggleExpansion(forSelectedFolderIDs: ids) else { return }
            applyCurrentDisplayData(animated: true)
            updateToggleExpandCollapseButtonState()
            return
        }

        viewModel.toggleExpandAllFolders()
        applyCurrentDisplayData(animated: true)
    }

    @objc private func cancelPicker() {
        router.dismissPicker(from: self)
    }
    
    private func updateToggleExpandCollapseButtonState() {
        let isListMode = albumListView.layoutMode == .list
        let expandImage = UIImage(systemName: "chevron.down.circle")
        let collapseImage = UIImage(systemName: "chevron.up.circle")

        if albumListView.isMultiSelectMode {
            guard isListMode else {
                navigationItem.rightBarButtonItems = []
                return
            }
            let selectedExpandable = selectedExpandableFolderIDs()
            let hasTargets = !selectedExpandable.isEmpty
            let allSelectedExpanded = hasTargets && selectedExpandable.isSubset(of: viewModel.expandedFolderIDs)
            toggleExpandCollapseButton.image = allSelectedExpanded ? collapseImage : expandImage
            toggleExpandCollapseButton.accessibilityLabel = allSelectedExpanded ? "收起所选文件夹" : "展开所选文件夹"
            toggleExpandCollapseButton.isEnabled = hasTargets
            navigationItem.rightBarButtonItems = [toggleExpandCollapseButton]
            return
        }

        let expandableFolderIDs = viewModel.allExpandableFolderIDs()
        let hasExpandableFolders = !expandableFolderIDs.isEmpty
        let allExpanded = hasExpandableFolders && expandableFolderIDs.isSubset(of: viewModel.expandedFolderIDs)
        toggleExpandCollapseButton.image = allExpanded ? collapseImage : expandImage
        toggleExpandCollapseButton.accessibilityLabel = allExpanded ? "收起全部" : "展开全部"
        toggleExpandCollapseButton.isEnabled = isListMode && hasExpandableFolders

        var rightItems: [UIBarButtonItem] = []
        if isListMode {
            rightItems.append(selectBarButton)
        }
        rightItems.append(menuButton)
        if isListMode {
            rightItems.append(toggleExpandCollapseButton)
        }
        rightItems.append(addButton)

        navigationItem.setRightBarButtonItems(rightItems, animated: true)
    }
    
    @objc private func createAlbum() {
        // 显示输入框让用户输入相册名称
        let alertController = UIAlertController(title: "创建相册", message: "请输入相册名称", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "相册名称"
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let createAction = UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            guard let self = self, let albumName = alertController.textFields?.first?.text, !albumName.isEmpty else {
                return
            }
            
            // 创建新相册
            self.performCreateAlbum(with: albumName)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(createAction)
        
        present(alertController, animated: true)
    }
    
    private func performCreateAlbum(with name: String) {
        collectionOperations.createAlbum(titled: name, inParent: collectionList) { [weak self] outcome in
            self?.handleCollectionWriteOutcome(outcome, clearBeforeReload: true, scrollToTitle: name)
        }
    }

    private func performCreateFolder(with name: String) {
        collectionOperations.createFolder(titled: name, inParent: collectionList) { [weak self] outcome in
            self?.handleCollectionWriteOutcome(outcome, clearBeforeReload: true, scrollToTitle: name)
        }
    }

    private func handleCollectionWriteOutcome(
        _ outcome: AlbumCollectionOperationOutcome,
        clearBeforeReload: Bool = false,
        scrollToTitle: String? = nil
    ) {
        if outcome.isPermissionDenied {
            showPermissionViewController()
            return
        }
        if outcome.success {
            if clearBeforeReload {
                viewModel.clearAllItems()
            }
            loadAlbums()
            if let title = scrollToTitle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.scrollToItem(withTitle: title)
                }
            }
        } else if let message = outcome.message, !message.isEmpty {
            presentSimpleAlert(title: "错误", message: message)
        }
    }

    private func scrollToItem(withTitle title: String) {
        guard let item = viewModel.item(withTitle: title),
              let index = displayedItems.firstIndex(where: { $0.localIdentifier == item.localIdentifier }) else {
            return
        }
        albumListView.scrollToItem(at: IndexPath(item: index, section: 0), at: .top, animated: true)
    }

    private func presentSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func createFolder() {
        // 显示输入框让用户输入文件夹名称
        let alertController = UIAlertController(title: "创建文件夹", message: "请输入文件夹名称", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "文件夹名称"
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let createAction = UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            guard let self = self, let folderName = alertController.textFields?.first?.text, !folderName.isEmpty else {
                return
            }
            
            // 创建新文件夹
            self.performCreateFolder(with: folderName)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(createAction)
        
        present(alertController, animated: true)
    }
    
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AlbumListViewController, previousTraitCollection: UITraitCollection) in
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
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    /// 监听系统相册增删、相簿/文件夹结构变化等，自动刷新列表
    private func registerPhotoLibraryObserver() {
        PHPhotoLibrary.shared().register(self)
    }
    
    private func checkPermissionStatus() {
        let status = PhotoPermissionManager.shared.getCurrentPermissionStatus()
        if status == .denied {
            showPermissionViewController()
        } else if status == .authorized || status == .limited {
            loadAlbums()
        }
    }
    
    private func showPermissionViewController() {
        let permissionVC = PermissionViewController()
        permissionVC.modalPresentationStyle = .fullScreen
        present(permissionVC, animated: false)
    }
    
    private func loadAlbums() {
        viewModel.reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新渐变层的frame
        backgroundGradientLayer.frame = view.bounds
    }
}

extension AlbumListViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let status = PhotoPermissionManager.shared.getCurrentPermissionStatus()
            guard status == .authorized || status == .limited else { return }
            self.loadAlbums()
        }
    }
}

extension AlbumListViewController: AlbumListViewDelegate {
    func albumListViewDidUpdateMultiSelection(_ albumListView: AlbumListView) {
        guard albumListView.isMultiSelectMode else { return }
        updateMultiSelectTitle()
        updateToggleExpandCollapseButtonState()
    }

    func albumListView(_ albumListView: AlbumListView, didSelectItemAt indexPath: IndexPath) {
    }
    
    func albumListView(_ albumListView: AlbumListView, didTapFolderDisclosureAt indexPath: IndexPath) {
        guard albumListView.layoutMode == .list else { return }
        guard indexPath.item < displayedItems.count else { return }
        
        let item = displayedItems[indexPath.item]
        guard item.isFolder else { return }
        guard item.canExpand else { return }
        
        viewModel.toggleFolderExpansion(identifier: item.localIdentifier)
        applyCurrentDisplayData(animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didTapAddPhotosFor item: AlbumListItem) {
        guard let targetAlbum = item.assetCollection else { return }
        targetAlbumForAddingPhotos = targetAlbum
        
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        configuration.selection = .ordered
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt collection: PHAssetCollection) {
        router.openAlbum(collection, from: self)
    }

    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList) {
        router.openFolder(collectionList, from: self)
    }
    
    func albumListView(_ albumListView: AlbumListView, didTapEditTitleFor item: AlbumListItem) {
        // 显示输入框让用户编辑标题
        let alertController = UIAlertController(title: "编辑标题", message: "请输入新的标题", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.text = item.title
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let saveAction = UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self = self, let newTitle = alertController.textFields?.first?.text, !newTitle.isEmpty else {
                return
            }
            
            // 更新标题
            self.performEditTitle(for: item, newTitle: newTitle)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        present(alertController, animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didTapDeleteFor item: AlbumListItem) {
        // 显示确认对话框
        let alertController = UIAlertController(title: "删除相册", message: "确定要删除这个相册吗？", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let deleteAction = UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            // 删除相册
            self?.performDelete(for: item)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true)
    }
    
    private func performEditTitle(for item: AlbumListItem, newTitle: String) {
        collectionOperations.rename(item: item, to: newTitle) { [weak self] outcome in
            self?.handleCollectionWriteOutcome(outcome)
        }
    }

    private func performDelete(for item: AlbumListItem) {
        collectionOperations.delete(item: item) { [weak self] outcome in
            self?.handleCollectionWriteOutcome(outcome)
        }
    }
}

extension AlbumListViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let targetAlbum = targetAlbumForAddingPhotos
        targetAlbumForAddingPhotos = nil
        
        picker.dismiss(animated: true) { [weak self] in
            guard
                let self = self,
                let targetAlbum = targetAlbum
            else {
                return
            }
            self.addPickedPhotos(results, to: targetAlbum)
        }
    }
    
    private func addPickedPhotos(_ results: [PHPickerResult], to targetAlbum: PHAssetCollection) {
        guard !results.isEmpty else { return }

        let loadingAlert = UIAlertController(title: "添加中", message: "正在将照片添加到相簿...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        var finished = false
        let finish: (Bool, String, String) -> Void = { [weak self] showAlert, title, message in
            guard !finished else { return }
            finished = true
            loadingAlert.dismiss(animated: true) {
                guard let self, showAlert else { return }
                self.presentSimpleAlert(title: title, message: message)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            finish(true, "添加失败", "操作超时，请稍后重试")
        }

        collectionOperations.addPickerResults(results, to: targetAlbum) { [weak self] outcome in
            guard let self else { return }
            if outcome.message == PhotoChangesService.permissionDeniedMessage {
                loadingAlert.dismiss(animated: true) {
                    finished = true
                    self.showPermissionViewController()
                }
                return
            }
            if outcome.message == "所选照片已在该相簿中" {
                finish(true, "提示", outcome.message ?? "所选照片已在该相簿中")
                return
            }
            if outcome.success {
                finish(false, "", "")
            } else {
                finish(true, "添加失败", outcome.message ?? "添加失败，请稍后重试")
            }
        }
    }
}
