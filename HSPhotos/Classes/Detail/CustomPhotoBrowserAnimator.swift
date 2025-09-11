//
//  CustomPhotoBrowserAnimator.swift
//  HSPhotos
//
//  Created by Hans on 2025/9/11.
//

import Foundation
import SKPhotoBrowser
import UIKit

/// 自定义照片浏览器动画器，提供更符合苹果设计规范的自然动画
class CustomPhotoBrowserAnimator: NSObject, SKPhotoBrowserAnimatorDelegate {
    
    /// 在照片浏览器呈现之前调用
    /// - Parameter browser: 照片浏览器实例
    func willPresent(_ browser: SKPhotoBrowser) {
        // 可以在这里添加自定义的呈现前动画逻辑
        // 例如：准备自定义转场动画的初始状态
    }
    
    /// 在照片浏览器消失之前调用
    /// - Parameter browser: 照片浏览器实例
    func willDismiss(_ browser: SKPhotoBrowser) {
        // 可以在这里添加自定义的消失前动画逻辑
        // 例如：准备自定义转场动画的结束状态
    }
}

/// 自定义转场动画器，用于实现更自然的呈现和消失动画
class CustomTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let duration: TimeInterval = 0.5
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            presentAnimation(using: transitionContext)
        } else {
            dismissAnimation(using: transitionContext)
        }
    }
    
    private func presentAnimation(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) as? SKPhotoBrowser else { return }
        
        let containerView = transitionContext.containerView
        containerView.addSubview(toVC.view)
        toVC.view.alpha = 0.0
        
        // 使用UIViewPropertyAnimator实现更自然的动画效果
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.8) {
            toVC.view.alpha = 1.0
        }
        
        animator.addCompletion { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        animator.startAnimation()
    }
    
    private func dismissAnimation(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) as? SKPhotoBrowser else { return }
        
        // 使用UIViewPropertyAnimator实现更自然的动画效果
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.8) {
            fromVC.view.alpha = 0.0
        }
        
        animator.addCompletion { _ in
            fromVC.view.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        animator.startAnimation()
    }
}

/// 自定义转场动画代理，用于管理呈现和消失的转场动画
class CustomTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomTransitionAnimator(isPresenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomTransitionAnimator(isPresenting: false)
    }
}