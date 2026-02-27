import UIKit

extension UIAlertController {
    
    /// 显示通用弹窗
    /// - Parameters:
    ///   - title: 标题
    ///   - message: 消息
    ///   - in: 视图控制器
    static func showAlert(title: String, message: String, in viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        viewController.present(alert, animated: true)
    }
    
    /// 显示同步成功提示
    /// - Parameters:
    ///   - message: 消息
    ///   - in: 视图控制器
    static func showSyncSuccess(message: String, in viewController: UIViewController) {
        showAlert(title: "同步成功", message: message, in: viewController)
    }
    
    /// 显示同步失败提示
    /// - Parameters:
    ///   - message: 消息
    ///   - in: 视图控制器
    static func showSyncFailed(message: String, in viewController: UIViewController) {
        showAlert(title: "同步失败", message: message, in: viewController)
    }
}