import UIKit
import Photos

class GalleryViewController: BasePhotoViewController {
    
    private lazy var sortBarButton: UIBarButtonItem = {
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
    }
    
    // MARK: - 重写方法
    
    override func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 退出选择模式时，隐藏全选按钮
            navigationItem.leftBarButtonItem = nil
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton, redoBarButton, undoBarButton], animated: true)
            // 进入选择模式时，显示全选/取消全选按钮
            updateSelectAllButton()
        }
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
        
        return UIMenu(title: "操作选项", children: [delete, move, paste, copy, duplicate])
    }
}



