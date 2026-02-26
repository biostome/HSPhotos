import UIKit

/// 网格→全屏共享元素转场
final class HeroPhotoTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let sourceFrame: CGRect
    let sourceImage: UIImage?
    let isPresenting: Bool

    init(sourceFrame: CGRect, sourceImage: UIImage?, isPresenting: Bool) {
        self.sourceFrame = sourceFrame
        self.sourceImage = sourceImage
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss(using: transitionContext)
        }
    }

    private func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) as? GalleryViewerViewController,
              let fromVC = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        // 创建过渡快照视图
        let snapshotView: UIImageView
        if let image = sourceImage {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.frame = sourceFrame
            snapshotView = iv
        } else {
            let iv = UIImageView()
            iv.frame = sourceFrame
            iv.backgroundColor = .systemGray4
            snapshotView = iv
        }
        container.addSubview(snapshotView)
        
        // 创建黑色背景，从透明渐变到不透明
        let blackBackground = UIView(frame: container.bounds)
        blackBackground.backgroundColor = .black
        blackBackground.alpha = 0
        container.insertSubview(blackBackground, belowSubview: snapshotView)

        // 计算目标 frame（保持宽高比，居中显示）
        let destFrame = calculateDestinationFrame(for: sourceImage, in: container.bounds)
        
        // 执行动画
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            // 快照从源位置放大到目标位置
            snapshotView.frame = destFrame
            snapshotView.contentMode = .scaleAspectFit
            // 背景从透明变为不透明
            blackBackground.alpha = 1
        } completion: { _ in
            // 动画完成后，添加真实的视图控制器
            toVC.view.frame = container.bounds
            container.addSubview(toVC.view)
            
            // 移除过渡元素
            snapshotView.removeFromSuperview()
            blackBackground.removeFromSuperview()
            
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    // 计算图片在屏幕中的最终显示 frame（保持宽高比）
    private func calculateDestinationFrame(for image: UIImage?, in containerBounds: CGRect) -> CGRect {
        guard let image = image else {
            return containerBounds
        }
        
        let imageSize = image.size
        let containerSize = containerBounds.size
        
        // 计算缩放比例（保持宽高比）
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        // 计算最终尺寸
        let finalWidth = imageSize.width * scale
        let finalHeight = imageSize.height * scale
        
        // 居中
        let x = (containerSize.width - finalWidth) / 2
        let y = (containerSize.height - finalHeight) / 2
        
        return CGRect(x: x, y: y, width: finalWidth, height: finalHeight)
    }

    private func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) as? GalleryViewerViewController,
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        let snapshotView: UIView
        if let image = sourceImage {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.frame = container.bounds
            snapshotView = iv
        } else {
            snapshotView = fromVC.view.snapshotView(afterScreenUpdates: false) ?? UIView()
            snapshotView.frame = container.bounds
        }
        container.insertSubview(snapshotView, aboveSubview: fromVC.view)
        fromVC.view.alpha = 0

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            snapshotView.frame = self.sourceFrame
        } completion: { _ in
            snapshotView.removeFromSuperview()
            fromVC.view.alpha = 1
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

/// 持有 source 信息，供 present/dismiss 使用
final class HeroPhotoTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    var sourceFrame: CGRect = .zero
    var sourceImage: UIImage?

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        HeroPhotoTransitionAnimator(sourceFrame: sourceFrame, sourceImage: sourceImage, isPresenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        HeroPhotoTransitionAnimator(sourceFrame: sourceFrame, sourceImage: sourceImage, isPresenting: false)
    }
}
