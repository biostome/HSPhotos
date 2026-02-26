import UIKit
import Photos

class GalleryViewController: UIViewController {
    
    private lazy var searchTextField: SearchBarView = {
        let searchBarView = SearchBarView()
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.delegate = self
        searchBarView.alpha = 0.0
        return searchBarView
    }()
    
    private lazy var gridView: PhotoGridView = {
        let view = PhotoGridView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    private lazy var selectBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "选择", style: .plain, target: self, action: #selector(toggleSelectionMode))
        return button
    }()
    
    private lazy var cancelSelectBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(toggleSelectionMode))
        return button
    }()
    
    private lazy var rangeSwitchItem: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "checkmark.seal"), style: .plain, target: self, action: #selector(toggleRangeSelection))
        button.tag = 0 // 0: 未选中, 1: 选中
        return button
    }()
    
    private lazy var menuBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
        button.menu = createOperationMenu()
        return button
    }()
    
    private lazy var undoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.left"),
            style: .plain,
            target: self,
            action: #selector(undoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    private lazy var redoBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.right"),
            style: .plain,
            target: self,
            action: #selector(redoAction)
        )
        button.isEnabled = false
        return button
    }()
    
    private lazy var sortBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: nil, action: nil)
        button.menu = createSortMenu()
        return button
    }()
    
    private lazy var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = sortPreference.sortDescriptors
        return options
    }()
    
    private let collection: PHAssetCollection
    private var sortPreference: PhotoSortPreference = .custom
    private var assets: [PHAsset] = [] {
        didSet {
            self.gridView.assets = assets
        }
    }
    private var selectionMode: PhotoSelectionMode = .none {
        didSet {
            gridView.selectionMode = selectionMode
            updateNavigationBar()
            updateOperationMenu()
        }
    }
    
    private var lastContentOffsetY: CGFloat = 0
    private var searchTextFieldTopConstraint: NSLayoutConstraint!
    
    init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        self.collection = allPhotosCollection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        title = "图库"
        
        // 禁用大标题模式
        navigationItem.largeTitleDisplayMode = .never
        
        // 允许视图内容延伸到四周
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        
        // 同步初始排序偏好到 PhotoGridView
        gridView.sortPreference = sortPreference
        // 设置当前相册引用（必须在loadPhoto之前设置）
        gridView.currentCollection = collection
        
        loadPhoto()
        setupUndoManager()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        
        // 添加网格视图和搜索栏
        view.addSubview(gridView)
        view.addSubview(searchTextField)
        
        // 创建搜索条的顶部约束
        searchTextFieldTopConstraint = searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            searchTextFieldTopConstraint,
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 44),
            
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // 初始状态下的按钮顺序，包含menuBarButton和sortBarButton
        navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
        
        // 设置 gridView 的滚动委托
        gridView.scrollDelegate = self
    }
    
    private func loadPhoto() {
        // 加载所有相片
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
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
        if sortPreference == .custom {
            newAssets = PhotoOrder.apply(to: newAssets, for: collection)
        }
        
        // 清理无效的首图数据
        PhotoHeaderService.shared.cleanupInvalidHeaders(for: collection)
        
        self.assets = newAssets
    }
    
    private func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
        }
    }
    
    private func updateOperationMenu() {
        menuBarButton.menu = createOperationMenu()
    }
    
    private func createOperationMenu() -> UIMenu {
        let attributes: UIMenuElement.Attributes = gridView.selectedAssets.isEmpty ? .disabled : []
        
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
        
        return UIMenu(title: "操作选项", children: [delete, move, paste, copy, duplicate, sort])
    }
    
    private func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按照拍摄时间排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .creationDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }
        
        let modificationDateAction = UIAction(
            title: "按照最近加入时间排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .recentDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .recentDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }
        
        let customAction = UIAction(
            title: "按照自定义排序",
            image: UIImage(systemName: "hand.draw"),
            state: sortPreference == .custom ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .custom)
            self?.sortBarButton.menu = self?.createSortMenu()
        }
        
        return UIMenu(
            title: "排序方式",
            children: [customAction, modificationDateAction, creationDateAction]
        )
    }
    
    private func onChanged(sort preference: PhotoSortPreference) {
        self.sortPreference = preference
        
        let options = PHFetchOptions()
        options.sortDescriptors = preference.sortDescriptors
        fetchOptions = options
        
        loadPhoto()
        
        // 同步排序偏好到 PhotoGridView
        gridView.sortPreference = preference
    }
    
    private func onCopy() {
        // 实现复制功能
        let selectedAssets = gridView.selectedAssets
        if selectedAssets.isEmpty {
            return
        }
        
        // 复制成功，不需要提示
    }
    
    private func onDuplicate() {
        // 实现复制功能（创建副本）
        let selectedAssets = gridView.selectedAssets
        if selectedAssets.isEmpty {
            return
        }
        
        PhotoChangesService.duplicate(assets: selectedAssets, to: collection) { [weak self] success, error in
            if success {
                // 复制成功，不需要提示
                self?.loadPhoto()
            } else {
                self?.showAlert(title: "复制失败", message: error ?? "无法创建照片副本")
            }
        }
    }
    
    private func onDelete() {
        // 实现删除功能
        let selectedAssets = gridView.selectedAssets
        if selectedAssets.isEmpty {
            return
        }
        
        showDeleteConfirmationAlert(for: selectedAssets)
    }
    
    private func onPaste() {
        // 实现粘贴功能
    }
    
    private func onMove() {
        // 实现剪切功能
    }
    
    private func onOrder() {
        // 实现排序功能
    }
    
    private func showDeleteConfirmationAlert(for assets: [PHAsset]) {
        let alertController = UIAlertController(title: "删除照片", message: "确定要删除选中的照片吗？", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        let deleteAction = UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.performDelete(assets: assets)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true)
    }
    
    private func performDelete(assets: [PHAsset]) {
        let loadingAlert = UIAlertController(title: "删除中", message: "正在从相册中删除照片...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        let selectedAssets = self.gridView.selectedAssets
        // 删除照片和 Cell
        gridView.deleteAssets(assets: selectedAssets) { success in
            PhotoChangesService.delete(assets: selectedAssets, for: self.collection) { success, error in
                loadingAlert.dismiss(animated: true) {
                    if success {
                        // 记录撤销操作
                        let _ = UndoAction.delete(collection: self.collection, assets: selectedAssets)
                        // 这里可以添加撤销操作的处理
                        
                        self.gridView.clearSelected()
                        self.loadPhoto() // 重新加载照片列表
                    } else {
                        let message = error ?? "无法删除照片"
                        self.showAlert(title: "删除失败", message: message)
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "确定", style: .default))
        present(alertController, animated: true)
    }
    
    @objc private func toggleSelectionMode() {
        if selectionMode == .none {
            // 进入多选模式
            setSelectionMode(.multiple)
        } else {
            // 退出选择模式
            setSelectionMode(.none)
        }
    }
    
    @objc private func toggleRangeSelection(forceOff: Bool = false) {
        if rangeSwitchItem.tag == 1 && !forceOff {
            // 取消范围选择
            rangeSwitchItem.tag = 0
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal")
            gridView.selectedStart = nil
            gridView.selectedEnd = nil
        } else if !forceOff {
            // 开启范围选择
            rangeSwitchItem.tag = 1
            rangeSwitchItem.image = UIImage(systemName: "checkmark.seal.fill")
        }
    }
    
    private func setSelectionMode(_ mode: PhotoSelectionMode) {
        if mode == .none {
            
            gridView.clearSelected()
            gridView.selectedStart = nil
            gridView.selectedEnd = nil
            toggleRangeSelection(forceOff: true)
        }
        selectionMode = mode
    }
    
    private func setupUndoManager() {
        // 设置撤销管理器
    }
    
    @objc private func undoAction() {
        // 实现撤销功能
    }
    
    @objc private func redoAction() {
        // 实现重做功能
    }
}

extension GalleryViewController: PhotoGridViewDelegate {
    func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        // 实现粘贴功能
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {
        updateOperationMenu()
    }
    
    func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {
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
                        
                        let viewerVC = GalleryViewerViewController(assets: self.assets, initialIndex: index, sourceFrame: sourceFrame, sourceImage: sourceImage)
                        present(viewerVC, animated: true)
                    }
                }
            }
}

extension GalleryViewController: SearchBarViewDelegate {
    func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String) {
        // 实现搜索功能
    }
}

extension GalleryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 滚动时的处理
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffsetY = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 滚动结束时的处理
    }
}

