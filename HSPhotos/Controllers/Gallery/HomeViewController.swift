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
        navigationItem.setRightBarButtonItems([selectBarButton, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
    }

    override func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, tagFilterBarButton, menuBarButton, redoBarButton, undoBarButton, sortBarButton], animated: true)
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
