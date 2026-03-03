import UIKit
import Photos

class GalleryViewController: BasePhotoViewController {
    
    private var shareButtonBottomConstraint: NSLayoutConstraint?
    
    private lazy var shareButton: UIButton = {
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "square.and.arrow.up")
        config.baseForegroundColor = UIColor.systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let button = UIButton(type: .custom)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapShareButton), for: .touchUpInside)
        button.isHidden = true
        button.isEnabled = false
        return button
    }()
    
    internal lazy var sortBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: nil, action: nil)
        button.menu = createSortMenu()
        return button
    }()
    
    init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        super.init(collection: allPhotosCollection)
    }
    
    override init(collection: PHAssetCollection) {
        super.init(collection: collection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "图库"
        
        view.addSubview(shareButton)
        shareButtonBottomConstraint = shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        NSLayoutConstraint.activate([
            shareButtonBottomConstraint!,
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.widthAnchor.constraint(equalToConstant: 44)
        ])
        updateShareButtonState()
    }
    
    // MARK: - 重写方法
    
    override func updateNavigationBar() {
        if selectionMode == .none {
            // 其他相册不显示排序按钮
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 退出选择模式时，隐藏全选按钮
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            // 选择模式下不显示排序按钮
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 进入选择模式时，显示全选/取消全选按钮
            updateSelectAllButton()
            tabBarController?.tabBar.isHidden = true
            let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
            additionalSafeAreaInsets.bottom = -tabBarHeight
        }
        view.layoutIfNeeded()
        updateShareButtonState()
    }
    
    override func createSortMenu() -> UIMenu {
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
    
    override func onChanged(sort preference: PhotoSortPreference) {
        super.onChanged(sort: preference)
        // 更新排序按钮菜单
        sortBarButton.menu = createSortMenu()
    }
    
    @objc(photoGridView:didPasteAssets:after:) override func photoGridView(_ photoGridView: PhotoGridView, didPasteAssets assets: [PHAsset], after: PHAsset) {
        // 实现粘贴功能
    }
    
    @objc(photoGridView:didSelectItemAtAsset:) override func photoGridView(_ photoGridView: PhotoGridView, didSelectItemAt asset: PHAsset) {
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
    
    override func createOperationMenu() -> UIMenu {
        let attributes: UIMenuElement.Attributes = gridView.selectedAssets.isEmpty ? .disabled : []
        
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
        
        // 隐藏排序选项
        // let sort = UIAction(title: "排序", image: UIImage(systemName: "arrow.up.arrow.down"), attributes: attributes) { [weak self] _ in
        //     self?.onOrder()
        // }
        
        let delete = UIAction(title: "删除", image: UIImage(systemName: "trash"), attributes: [attributes, .destructive].compactMap { $0 }.reduce([], { $0.union($1) })) { [weak self] _ in
            self?.onDelete()
        }
        
        let move = UIAction(title: "剪切", image: UIImage(systemName: "scissors"), attributes: attributes) { [weak self] _ in
            self?.onMove()
        }
        
        return UIMenu(title: "操作选项", children: [addToAlbum, delete, move, paste, copy, duplicate])
    }
    
    override func updateOperationMenu() {
        super.updateOperationMenu()
        updateShareButtonState()
    }
    
    override func photoGridView(_ photoGridView: PhotoGridView, didSelectedItems assets: [PHAsset]) {
        super.photoGridView(photoGridView, didSelectedItems: assets)
        updateShareButtonState()
    }
    
    @objc private func didTapShareButton() {
        let selectedAssets = gridView.selectedAssets
        guard !selectedAssets.isEmpty else { return }
        
        let addToAlbumActivity = GalleryAddToAlbumActivity { [weak self] in
            self?.showAddToAlbumPicker(for: selectedAssets)
        }
        
        let activityItems: [Any] = [makeSharePlaceholderText(for: selectedAssets.count)]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: [addToAlbumActivity])
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }
    
    internal func updateShareButtonState() {
        let inSelectionMode = selectionMode != .none
        shareButton.isHidden = !inSelectionMode
        shareButton.isEnabled = !gridView.selectedAssets.isEmpty
    }
    
    private func makeSharePlaceholderText(for count: Int) -> String {
        if count == 1 {
            return "已选择 1 张照片"
        }
        return "已选择 \(count) 张照片"
    }
}


private final class GalleryAddToAlbumActivity: UIActivity {
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.hsphotos.gallery.activity.addToAlbum")
    }
    
    override var activityTitle: String? {
        "添加到相簿"
    }
    
    override var activityImage: UIImage? {
        UIImage(systemName: "plus.rectangle.on.folder")
    }
    
    override class var activityCategory: UIActivity.Category {
        .action
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
    }
    
    override func perform() {
        activityDidFinish(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.action()
        }
    }
}
