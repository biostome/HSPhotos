import UIKit

class MainTabbarViewContoller: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
    }
    
    private func setupTabBar() {
        // 创建第一个页面：图库
        let homeViewController = HomeViewController()
        let galleryNavController = RootNavigationViewController(rootViewController: homeViewController)
        galleryNavController.tabBarItem = UITabBarItem(title: "图库", image: UIImage(systemName: "photo.on.rectangle"), tag: 0)
        
        // 创建第二个页面：相册
        let albumListViewController = AlbumListViewController()
        let homeNavController = RootNavigationViewController(rootViewController: albumListViewController)
        homeNavController.tabBarItem = UITabBarItem(title: "相册", image: UIImage(systemName: "photo.stack"), tag: 1)
        
        // 设置标签栏控制器的子控制器
        viewControllers = [galleryNavController, homeNavController]
    }
}
