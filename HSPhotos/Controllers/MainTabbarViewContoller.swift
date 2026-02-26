import UIKit

class MainTabbarViewContoller: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
    }
    
    private func setupTabBar() {
        // 创建第一个页面：图库
        let galleryViewController = GalleryViewController()
        let galleryNavController = RootNavigationViewController(rootViewController: galleryViewController)
        galleryNavController.tabBarItem = UITabBarItem(title: "图库", image: UIImage(systemName: "photo.on.rectangle"), tag: 0)
        
        // 创建第二个页面：首页
        let homeViewController = MainViewController()
        let homeNavController = RootNavigationViewController(rootViewController: homeViewController)
        homeNavController.tabBarItem = UITabBarItem(title: "首页", image: UIImage(systemName: "house"), tag: 1)
        
        // 设置标签栏控制器的子控制器
        viewControllers = [galleryNavController, homeNavController]
    }
}
