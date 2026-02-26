import UIKit

class RootNavigationViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 可以在这里设置导航栏的全局样式
        navigationBar.tintColor = .systemBlue
        
        // 确保导航栏标题颜色支持深色模式和浅色模式
        updateNavigationBarColors()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 当界面模式改变时，更新导航栏标题颜色
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateNavigationBarColors()
        }
    }
    
    private func updateNavigationBarColors() {
        // 确保导航栏标题颜色支持深色模式和浅色模式
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        // 确保大标题颜色支持深色模式和浅色模式
        navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // 只有当导航控制器已经有子视图控制器时才隐藏tabbar
        if viewControllers.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}
