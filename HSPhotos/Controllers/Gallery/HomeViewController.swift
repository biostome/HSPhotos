import UIKit
import Photos

class HomeViewController: GalleryViewController {

    /// 首页（图库）不支持层级编号，仅在相册内支持
    override var supportsHierarchyNumbering: Bool { false }

    override init() {
        // 使用所有照片的集合
        let allPhotosCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject!
        super.init(collection: allPhotosCollection)
        sortPreference = PhotoSortPreference.creationDate.preference(for: allPhotosCollection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "图库"
        navigationItem.setRightBarButtonItems([selectBarButton, sortBarButton, menuBarButton], animated: true)
    }

    /// 图库「所有照片」与系统「照片」一致：`recentDate` 用系统默认顺序；`creationDate` 用纯拍摄时间升序（不用 modification 副键以免与系统展示有偏差）。
    override func sortDescriptors(for preference: PhotoSortPreference) -> [NSSortDescriptor]? {
        switch preference {
        case .recentDate:
            return nil
        case .creationDate:
            return [NSSortDescriptor(key: "creationDate", ascending: true)]
        default:
            return super.sortDescriptors(for: preference)
        }
    }

    override func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: "按拍摄日期排序",
            image: UIImage(systemName: "camera"),
            state: sortPreference == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .creationDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        let modificationDateAction = UIAction(
            title: "按最近添加排序",
            image: UIImage(systemName: "clock"),
            state: sortPreference == .recentDate ? .on : .off
        ) { [weak self] _ in
            self?.onChanged(sort: .recentDate)
            self?.sortBarButton.menu = self?.createSortMenu()
        }

        return UIMenu(
            title: "排序方式",
            children: [modificationDateAction, creationDateAction]
        )
    }

    override func updateNavigationBar() {
        if selectionMode == .none {
            navigationItem.setRightBarButtonItems([selectBarButton, sortBarButton, menuBarButton], animated: true)
            navigationItem.leftBarButtonItem = nil
            tabBarController?.tabBar.isHidden = false
            additionalSafeAreaInsets.bottom = 0
        } else {
            navigationItem.setRightBarButtonItems([cancelSelectBarButton, rangeSwitchItem, menuBarButton], animated: true)
            updateSelectAllButton()
            tabBarController?.tabBar.isHidden = true
            let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
            additionalSafeAreaInsets.bottom = -tabBarHeight
        }
        view.layoutIfNeeded()
        updateShareButtonState()
        updateSelectionQuickNavToolbar()
        syncSelectionQuickNavBarButtonsEnabled()
    }
    
    override func updateSelectAllButton() {
        super.updateSelectAllButton()
    }
}
