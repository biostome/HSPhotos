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

    private var albumListItems: [AlbumListItem] = []
    private var displayedItems: [AlbumListItem] = []
    private var expandedFolderIDs: Set<String> = []
    private var targetAlbumForAddingPhotos: PHAssetCollection?
    private let backgroundGradientLayer = CAGradientLayer()
    private let collectionList: PHCollectionList?
    
    // 排序类型
    enum SortType {
        case modificationDate
        case name
        case custom
    }
    
    // 当前排序类型
    private var currentSortType: SortType = .custom
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
    
    init(collectionList: PHCollectionList? = nil) {
        self.collectionList = collectionList
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
        title = collectionList?.localizedTitle ?? "相册"
        navigationController?.navigationBar.prefersLargeTitles = true
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
        
        let listViewAction = UIAction(title: "列表视图", image: UIImage(systemName: "list.bullet")) { [weak self] _ in
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
        
        // 创建主菜单
        return UIMenu(title: "", children: [viewModeMenu, sortByModificationDateAction, sortByNameAction, sortByCustomAction])
    }
    
    // 切换到封面照片模式
    private func switchToCoverPhotoMode() {
        // 实现封面照片模式逻辑
        albumListView.layoutMode = .grid
        applyCurrentDisplayData()
        print("切换到封面照片模式")
    }
    
    // 切换到列表视图模式
    private func switchToListViewMode() {
        // 实现列表视图模式逻辑
        albumListView.layoutMode = .list
        applyCurrentDisplayData()
        print("切换到列表视图模式")
    }
    

    
    // 按修改日期排序
    private func sortByModificationDate() {
        currentSortType = .modificationDate
        loadAlbumsAsync()
    }
    
    // 按名称排序
    private func sortByName() {
        currentSortType = .name
        loadAlbumsAsync()
    }
    
    // 按自定义顺序排序
    private func sortByCustomOrder() {
        currentSortType = .custom
        loadAlbumsAsync()
    }
    
    // 异步加载相册列表
    private func loadAlbumsAsync() {
        // 在后台线程中执行加载操作
        DispatchQueue.global(qos: .userInitiated).async {
            // 加载相册数据
            var items: [AlbumListItem] = []
            
            if let collectionList = self.collectionList {
                // 加载文件夹内的子内容
                items = self.fetchItems(in: collectionList)
            } else {
                // 加载根相册列表
                // 1. 加载所有文件夹
                let folderOptions = self.getFetchOptions()
                let allFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: folderOptions)
                
                // 2. 加载所有相册
                let albumOptions = self.getFetchOptions()
                let allAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumOptions)
                
                // 3. 检查每个文件夹是否有父文件夹
                var topLevelFolders: [PHCollectionList] = []
                allFolders.enumerateObjects { collectionList, _, _ in
                    // 获取所有可能包含此文件夹的父文件夹
                    let parentFolderOptions = PHFetchOptions()
                    let parentFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: parentFolderOptions)
                    
                    var hasParent = false
                    parentFolders.enumerateObjects { parentFolder, _, stop in
                        let subCollections = PHCollection.fetchCollections(in: parentFolder, options: nil)
                        subCollections.enumerateObjects { subCollection, _, stopSub in
                            if subCollection.localIdentifier == collectionList.localIdentifier {
                                hasParent = true
                                stop.pointee = true
                                stopSub.pointee = true
                            }
                        }
                    }
                    
                    if !hasParent {
                        topLevelFolders.append(collectionList)
                    }
                }
                
                // 4. 检查每个相册是否有父文件夹
                var topLevelAlbums: [PHAssetCollection] = []
                allAlbums.enumerateObjects { collection, _, _ in
                    // 获取所有可能包含此相册的父文件夹
                    let parentFolderOptions = PHFetchOptions()
                    let parentFolders = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: parentFolderOptions)
                    
                    var hasParent = false
                    parentFolders.enumerateObjects { parentFolder, _, stop in
                        let subCollections = PHCollection.fetchCollections(in: parentFolder, options: nil)
                        subCollections.enumerateObjects { subCollection, _, stopSub in
                            if subCollection.localIdentifier == collection.localIdentifier {
                                hasParent = true
                                stop.pointee = true
                                stopSub.pointee = true
                            }
                        }
                    }
                    
                    if !hasParent {
                        topLevelAlbums.append(collection)
                    }
                }
                
                // 5. 添加顶级文件夹
                for folder in topLevelFolders {
                    items.append(AlbumListItem(type: .folder(folder)))
                }
                
                // 6. 添加顶级相册
                for album in topLevelAlbums {
                    items.append(AlbumListItem(type: .album(album)))
                }
            }
            
            // 对于自定义排序，需要特殊处理
            var sortedItems: [AlbumListItem]
            if self.currentSortType == .custom {
                // 自定义排序逻辑
                sortedItems = items
            } else {
                // 其他排序方式已经通过PHFetchOptions处理
                sortedItems = items
            }
            
            // 在主线程上更新UI
            DispatchQueue.main.async {
                self.albumListItems = sortedItems
                self.applyCurrentDisplayData(animated: false)
            }
        }
    }

    private func applyCurrentDisplayData(animated: Bool = false) {
        switch albumListView.layoutMode {
        case .grid:
            displayedItems = albumListItems
        case .list:
            var visitedFolderIDs = Set<String>()
            displayedItems = buildVisibleItems(from: albumListItems, level: 0, visitedFolderIDs: &visitedFolderIDs)
        }
        albumListView.setCollections(displayedItems, animated: animated)
        updateToggleExpandCollapseButtonState()
    }
    
    private func buildVisibleItems(from items: [AlbumListItem], level: Int, visitedFolderIDs: inout Set<String>) -> [AlbumListItem] {
        var visibleItems: [AlbumListItem] = []
        
        for item in items {
            if item.isFolder, let folder = item.collectionList {
                if visitedFolderIDs.contains(item.localIdentifier) {
                    continue
                }
                visitedFolderIDs.insert(item.localIdentifier)
                
                let childItems = fetchItems(in: folder)
                let canExpand = !childItems.isEmpty
                let isExpanded = canExpand && expandedFolderIDs.contains(item.localIdentifier)
                
                let displayItem = makeDisplayItem(from: item, level: level, canExpand: canExpand, isExpanded: isExpanded)
                visibleItems.append(displayItem)
                
                if isExpanded {
                    let childVisibleItems = buildVisibleItems(from: childItems, level: level + 1, visitedFolderIDs: &visitedFolderIDs)
                    visibleItems.append(contentsOf: childVisibleItems)
                }
            } else {
                let displayItem = makeDisplayItem(from: item, level: level, canExpand: false, isExpanded: false)
                visibleItems.append(displayItem)
            }
        }
        
        return visibleItems
    }
    
    private func makeDisplayItem(from item: AlbumListItem, level: Int, canExpand: Bool, isExpanded: Bool) -> AlbumListItem {
        let displayItem = AlbumListItem(type: item.type)
        displayItem.hierarchyLevel = level
        displayItem.canExpand = canExpand
        displayItem.isExpanded = isExpanded
        return displayItem
    }
    
    private func fetchItems(in collectionList: PHCollectionList) -> [AlbumListItem] {
        var items: [AlbumListItem] = []
        let options = getFetchOptions()
        let collections = PHCollection.fetchCollections(in: collectionList, options: options)
        
        collections.enumerateObjects { collection, _, _ in
            if let subFolder = collection as? PHCollectionList {
                items.append(AlbumListItem(type: .folder(subFolder)))
            } else if let subAlbum = collection as? PHAssetCollection {
                items.append(AlbumListItem(type: .album(subAlbum)))
            }
        }
        
        return items
    }
    
    @objc private func toggleExpandCollapse() {
        guard albumListView.layoutMode == .list else { return }
        
        let expandableFolderIDs = allExpandableFolderIDs()
        guard !expandableFolderIDs.isEmpty else { return }
        
        if expandableFolderIDs.isSubset(of: expandedFolderIDs) {
            expandedFolderIDs.subtract(expandableFolderIDs)
        } else {
            expandedFolderIDs.formUnion(expandableFolderIDs)
        }
        
        applyCurrentDisplayData(animated: true)
    }
    
    private func updateToggleExpandCollapseButtonState() {
        let isListMode = albumListView.layoutMode == .list
        let expandableFolderIDs = allExpandableFolderIDs()
        let hasExpandableFolders = !expandableFolderIDs.isEmpty
        let allExpanded = hasExpandableFolders && expandableFolderIDs.isSubset(of: expandedFolderIDs)
        
        let expandImage = UIImage(systemName: "chevron.down.circle")
        let collapseImage = UIImage(systemName: "chevron.up.circle")
        toggleExpandCollapseButton.image = allExpanded ? collapseImage : expandImage
        toggleExpandCollapseButton.accessibilityLabel = allExpanded ? "收起全部" : "展开全部"
        toggleExpandCollapseButton.isEnabled = isListMode && hasExpandableFolders
        
        var rightItems: [UIBarButtonItem] = [menuButton]
        
        if isListMode {
            rightItems.append(toggleExpandCollapseButton)
        }
        
        rightItems.append(addButton)
        
        navigationItem.setRightBarButtonItems(rightItems, animated: true)
    }
    
    private func allExpandableFolderIDs() -> Set<String> {
        var visitedFolderIDs = Set<String>()
        return collectExpandableFolderIDs(from: albumListItems, visitedFolderIDs: &visitedFolderIDs)
    }
    
    private func collectExpandableFolderIDs(from items: [AlbumListItem], visitedFolderIDs: inout Set<String>) -> Set<String> {
        var folderIDs = Set<String>()
        
        for item in items {
            guard item.isFolder, let folder = item.collectionList else { continue }
            guard !visitedFolderIDs.contains(item.localIdentifier) else { continue }
            visitedFolderIDs.insert(item.localIdentifier)
            
            let childItems = fetchItems(in: folder)
            if !childItems.isEmpty {
                folderIDs.insert(item.localIdentifier)
            }
            
            folderIDs.formUnion(collectExpandableFolderIDs(from: childItems, visitedFolderIDs: &visitedFolderIDs))
        }
        
        return folderIDs
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
        // 请求权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, status == .authorized else {
                    if let self = self {
                        self.showPermissionViewController()
                    }
                    return
                }
                
                // 创建相册
                PHPhotoLibrary.shared().performChanges {
                    // 创建新相册
                    let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                    let albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                    
                    // 如果当前在文件夹内，将新相册添加到该文件夹
                    if let collectionList = self.collectionList {
                        if let collectionListChangeRequest = PHCollectionListChangeRequest(for: collectionList) {
                            collectionListChangeRequest.addChildCollections([albumPlaceholder as Any] as NSArray)
                        }
                    }
                } completionHandler: { [weak self] success, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if success {
                            // 重新加载相册列表
                            self.albumListItems.removeAll()
                            self.loadAlbums()
                            
                            // 延迟一下，确保相册列表已经加载完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 查找新创建的相册
                                if let newAlbum = self.albumListItems.first(where: { $0.title == name }) {
                                    // 找到新相册在当前可见数组中的索引
                                    if let index = self.displayedItems.firstIndex(where: { $0.localIdentifier == newAlbum.localIdentifier }) {
                                        // 滚动到新创建的相册位置
                                        let indexPath = IndexPath(item: index, section: 0)
                                        self.albumListView.scrollToItem(at: indexPath, at: .top, animated: true)
                                    }
                                }
                            }
                        } else {
                            // 显示错误信息
                            let errorMessage = error?.localizedDescription ?? "创建相册失败"
                            let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "确定", style: .default))
                            self.present(alertController, animated: true)
                        }
                    }
                }
            }
        }
    }
    
    private func performCreateFolder(with name: String) {
        // 请求权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, status == .authorized else {
                    if let self = self {
                        self.showPermissionViewController()
                    }
                    return
                }
                
                // 创建文件夹
                PHPhotoLibrary.shared().performChanges {
                    // 创建新文件夹
                    let createFolderRequest = PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: name)
                    let folderPlaceholder = createFolderRequest.placeholderForCreatedCollectionList
                    
                    // 如果当前在文件夹内，将新文件夹添加到该文件夹
                    if let collectionList = self.collectionList {
                        if let collectionListChangeRequest = PHCollectionListChangeRequest(for: collectionList) {
                            collectionListChangeRequest.addChildCollections([folderPlaceholder as Any] as NSArray)
                        }
                    }
                } completionHandler: { [weak self] success, error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if success {
                            // 重新加载相册列表
                            self.albumListItems.removeAll()
                            self.loadAlbums()
                            
                            // 延迟一下，确保相册列表已经加载完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 查找新创建的文件夹
                                if let newFolder = self.albumListItems.first(where: { $0.title == name }) {
                                    // 找到新文件夹在当前可见数组中的索引
                                    if let index = self.displayedItems.firstIndex(where: { $0.localIdentifier == newFolder.localIdentifier }) {
                                        // 滚动到新创建的文件夹位置
                                        let indexPath = IndexPath(item: index, section: 0)
                                        self.albumListView.scrollToItem(at: indexPath, at: .top, animated: true)
                                    }
                                }
                            }
                        } else {
                            // 显示错误信息
                            let errorMessage = error?.localizedDescription ?? "创建文件夹失败"
                            let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "确定", style: .default))
                            self.present(alertController, animated: true)
                        }
                    }
                }
            }
        }
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
        // 系统会自动处理trait变化注册的清理
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
        // 调用异步加载方法
        loadAlbumsAsync()
    }
    
    // 根据当前排序类型获取PHFetchOptions
    private func getFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        
        switch currentSortType {
        case .modificationDate:
            // 按修改日期排序（降序）
            options.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        case .name:
            // 按名称排序（升序）
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        case .custom:
            // 按自定义顺序排序（默认顺序）
            options.sortDescriptors = nil
        }
        
        return options
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新渐变层的frame
        backgroundGradientLayer.frame = view.bounds
    }
}

extension AlbumListViewController: AlbumListViewDelegate {
    func albumListView(_ albumListView: AlbumListView, didSelectItemAt indexPath: IndexPath) {
    }
    
    func albumListView(_ albumListView: AlbumListView, didTapFolderDisclosureAt indexPath: IndexPath) {
        guard albumListView.layoutMode == .list else { return }
        guard indexPath.item < displayedItems.count else { return }
        
        let item = displayedItems[indexPath.item]
        guard item.isFolder else { return }
        guard item.canExpand else { return }
        
        if expandedFolderIDs.contains(item.localIdentifier) {
            expandedFolderIDs.remove(item.localIdentifier)
        } else {
            expandedFolderIDs.insert(item.localIdentifier)
        }
        
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
        let photoVC = PhotoGridViewController(collection: collection)
        navigationController?.pushViewController(photoVC, animated: true)
    }
    
    func albumListView(_ albumListView: AlbumListView, didSelectFolder collectionList: PHCollectionList) {
        // 显示文件夹内的子相册列表
        let folderVC = AlbumListViewController(collectionList: collectionList)
        navigationController?.pushViewController(folderVC, animated: true)
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
        // 请求权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async { 
                guard let self = self, status == .authorized else {
                    self?.showPermissionViewController()
                    return
                }
                
                // 根据类型更新标题
                switch item.type {
                case .album(let collection):
                    // 更新相册标题
                    PHPhotoLibrary.shared().performChanges { 
                        let changeRequest = PHAssetCollectionChangeRequest(for: collection)
                        changeRequest?.title = newTitle
                    } completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async { 
                            guard let self = self else { return }
                            
                            if success {
                                // 重新加载相册列表
                                self.loadAlbums()
                            } else {
                                // 显示错误信息
                                let errorMessage = error?.localizedDescription ?? "更新标题失败"
                                let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                                alertController.addAction(UIAlertAction(title: "确定", style: .default))
                                self.present(alertController, animated: true)
                            }
                        }
                    }
                case .folder(let collectionList):
                    // 更新文件夹标题
                    PHPhotoLibrary.shared().performChanges { 
                        let changeRequest = PHCollectionListChangeRequest(for: collectionList)
                        changeRequest?.title = newTitle
                    } completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async { 
                            guard let self = self else { return }
                            
                            if success {
                                // 重新加载相册列表
                                self.loadAlbums()
                            } else {
                                // 显示错误信息
                                let errorMessage = error?.localizedDescription ?? "更新标题失败"
                                let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                                alertController.addAction(UIAlertAction(title: "确定", style: .default))
                                self.present(alertController, animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func performDelete(for item: AlbumListItem) {
        // 请求权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async { 
                guard let self = self, status == .authorized else {
                    self?.showPermissionViewController()
                    return
                }
                
                // 根据类型删除
                switch item.type {
                case .album(let collection):
                    // 删除相册
                    PHPhotoLibrary.shared().performChanges { 
                        PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
                    } completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async { 
                            guard let self = self else { return }
                            
                            if success {
                                // 重新加载相册列表
                                self.loadAlbums()
                            } else {
                                // 显示错误信息
                                let errorMessage = error?.localizedDescription ?? "删除相册失败"
                                let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                                alertController.addAction(UIAlertAction(title: "确定", style: .default))
                                self.present(alertController, animated: true)
                            }
                        }
                    }
                case .folder(let collectionList):
                    // 删除文件夹
                    PHPhotoLibrary.shared().performChanges { 
                        PHCollectionListChangeRequest.deleteCollectionLists([collectionList] as NSArray)
                    } completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async { 
                            guard let self = self else { return }
                            
                            if success {
                                // 重新加载相册列表
                                self.loadAlbums()
                            } else {
                                // 显示错误信息
                                let errorMessage = error?.localizedDescription ?? "删除文件夹失败"
                                let alertController = UIAlertController(title: "错误", message: errorMessage, preferredStyle: .alert)
                                alertController.addAction(UIAlertAction(title: "确定", style: .default))
                                self.present(alertController, animated: true)
                            }
                        }
                    }
                }
            }
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
        let selectedIdentifiers = results.compactMap { $0.assetIdentifier }
        guard !selectedIdentifiers.isEmpty else { return }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: selectedIdentifiers, options: nil)
        var selectedAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            selectedAssets.append(asset)
        }
        guard !selectedAssets.isEmpty else { return }
        
        let existingAssets = PHAsset.fetchAssets(in: targetAlbum, options: nil)
        var existingAssetIDs = Set<String>()
        existingAssets.enumerateObjects { asset, _, _ in
            existingAssetIDs.insert(asset.localIdentifier)
        }
        
        let assetsToAdd = selectedAssets.filter { !existingAssetIDs.contains($0.localIdentifier) }
        if assetsToAdd.isEmpty {
            let alert = UIAlertController(title: "提示", message: "所选照片已在该相簿中", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        
        ensureReadWritePermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                let alert = UIAlertController(title: "权限不足", message: "请允许照片读写权限后重试", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
                return
            }
            
            let loadingAlert = UIAlertController(title: "添加中", message: "正在将照片添加到相簿...", preferredStyle: .alert)
            self.present(loadingAlert, animated: true)
            
            var finished = false
            let finish: (String, String, Bool) -> Void = { title, message, shouldShowAlert in
                guard !finished else { return }
                finished = true
                loadingAlert.dismiss(animated: true) {
                    if shouldShowAlert {
                        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                finish("添加失败", "操作超时，请稍后重试", true)
            }
            
            PHPhotoLibrary.shared().performChanges({
                guard let request = PHAssetCollectionChangeRequest(for: targetAlbum) else { return }
                request.addAssets(assetsToAdd as NSArray)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        finish("添加成功", "已添加 \(assetsToAdd.count) 张照片", false)
                    } else {
                        finish("添加失败", error?.localizedDescription ?? "添加失败，请稍后重试", true)
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
