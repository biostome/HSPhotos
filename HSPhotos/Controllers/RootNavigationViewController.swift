import UIKit

class RootNavigationViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 可以在这里设置导航栏的全局样式
        navigationBar.tintColor = .systemBlue
    }
}
