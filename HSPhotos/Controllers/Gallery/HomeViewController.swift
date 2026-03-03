import UIKit
import Photos

class HomeViewController: GalleryViewController {
    
    override init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        super.init(collection: allPhotosCollection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "图库"
        // 初始状态下的按钮顺序，包含menuBarButton
        navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
        
    }
    
    
    override func updateNavigationBar() {
        if selectionMode == .none {
            // 首页图库显示排序按钮
            navigationItem.setRightBarButtonItems([selectBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
            // 退出选择模式时，隐藏全选按钮
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            // 选择模式下不显示排序按钮
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
            tabBarController?.tabBar.isHidden = true
            let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
            additionalSafeAreaInsets.bottom = -tabBarHeight
        }
        view.layoutIfNeeded()
        updateShareButtonState()
    }
    
    override func updateSelectAllButton() {
        
    }
}
