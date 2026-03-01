import UIKit

class RootNavigationViewController: UINavigationController {
    /// 注册trait变化监听
    private var traitChangeToken: UITraitChangeRegistration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 可以在这里设置导航栏的全局样式
        navigationBar.tintColor = .systemBlue
        
        // 确保导航栏标题颜色支持深色模式和浅色模式
        updateNavigationBarColors()
        
        // 设置trait变化监听
        setupTraitChangeObserver()
    }
    
    /// 设置trait变化监听
    private func setupTraitChangeObserver() {
        traitChangeToken = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: RootNavigationViewController, previousTraitCollection: UITraitCollection) in
            // 当界面模式改变时，更新导航栏标题颜色
            self.updateNavigationBarColors()
        }
    }
    
    deinit {
        // 系统会自动处理trait变化注册的清理
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
