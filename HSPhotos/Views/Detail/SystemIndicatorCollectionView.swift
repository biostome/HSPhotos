import UIKit

/// UILabel 扩展，支持文字内边距
class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                     height: size.height + textInsets.top + textInsets.bottom)
    }
}

/// 委托协议，用于获取当前滚动位置对应的照片信息
protocol CustomVerticalScrollIndicatorDelegate: AnyObject {
    /// 获取当前滚动位置对应的照片信息
    /// - Parameter scrollProgress: 滚动进度 (0.0 到 1.0)
    /// - Returns: 显示的文字内容
    func scrollIndicator(_ indicator: CustomVerticalScrollIndicator, textForScrollProgress scrollProgress: CGFloat) -> String?
}

/// 自定义垂直滚动指示器
class CustomVerticalScrollIndicator: UIView {
    //轨道
    private let trackView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 指示器
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 8
        view.layer.borderColor = UIColor.systemGray5.withAlphaComponent(0.4).cgColor
        view.alpha = 0.8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// 文字标签
    private let textLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0.0
        return label
    }()
    
    private let indicatorWidth: CGFloat = 60
    
    // 约束属性
    private var indicatorTopConstraint: NSLayoutConstraint?
    private var indicatorHeightConstraint: NSLayoutConstraint?
    private var textLabelTopConstraint: NSLayoutConstraint?
    
    // 委托
    weak var delegate: CustomVerticalScrollIndicatorDelegate?
    
    // 滚动相关属性
    private weak var scrollView: UIScrollView?
    private var isConfigured = false
    
    // 滚动状态跟踪
    private var lastContentOffset: CGPoint = .zero
    private var isDragging = false
    private var isDecelerating = false
    
    // 拖动手势相关
    private var isIndicatorDragging = false
    private var initialIndicatorOffset: CGFloat = 0
    private var initialTouchPoint: CGPoint = .zero
    
    init() {
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setupScrollViewObserver()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !isConfigured {
            configureWithScrollView()
            indicatorView.layer.cornerRadius = indicatorView.bounds.size.width / 2
        }
    }

    private func setupUI() {
        addSubview(trackView)
        addSubview(indicatorView)
        addSubview(textLabel)
        setupIndicatorGesture()
    }
    
    /// 设置指示器拖动手势
    private func setupIndicatorGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleIndicatorPan(_:)))
        indicatorView.addGestureRecognizer(panGesture)
        indicatorView.isUserInteractionEnabled = true
    }
    
    /// 处理指示器拖动手势
    @objc private func handleIndicatorPan(_ gesture: UIPanGestureRecognizer) {
        guard let scrollView = scrollView else { return }
        
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            isIndicatorDragging = true
            initialIndicatorOffset = indicatorTopConstraint?.constant ?? 0
            initialTouchPoint = gesture.location(in: self)
            
            // 取消自动隐藏，确保指示器在拖拽时保持显示
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideIndicator), object: nil)
            show()
            
            print("🎯 开始拖动指示器")
            
        case .changed:
            // 计算新的指示器位置
            let newOffset = initialIndicatorOffset + translation.y
            let maxOffset = frame.height - (indicatorHeightConstraint?.constant ?? indicatorWidth)
            let clampedOffset = max(0, min(maxOffset, newOffset))
            
            // 更新指示器位置
            indicatorTopConstraint?.constant = clampedOffset
            
            // 计算对应的 contentOffset
            let scrollProgress = clampedOffset / maxOffset
            let contentHeight = scrollView.contentSize.height
            let visibleHeight = scrollView.bounds.height
            let maxScrollOffset = contentHeight - visibleHeight
            let targetContentOffset = scrollProgress * maxScrollOffset
            
            // 更新 scrollView 的 contentOffset
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: targetContentOffset)
            
        case .ended, .cancelled:
            isIndicatorDragging = false
            
            // 拖拽结束后，重新设置自动隐藏
            autoHide(after: 2.0)
            
            print("🎯 结束拖动指示器")
            
        default:
            break
        }
    }
    
    private func setupConstraints() {
        // 轨道约束
        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        // 指示器约束
        indicatorTopConstraint = indicatorView.topAnchor.constraint(equalTo: topAnchor)
        indicatorHeightConstraint = indicatorView.heightAnchor.constraint(equalToConstant: indicatorWidth)
        
        NSLayoutConstraint.activate([
            indicatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            indicatorTopConstraint!,
            indicatorHeightConstraint!
        ])
        
        // 文字标签约束
        textLabelTopConstraint = textLabel.centerYAnchor.constraint(equalTo: indicatorView.centerYAnchor)
        
        NSLayoutConstraint.activate([
            textLabel.trailingAnchor.constraint(equalTo: indicatorView.leadingAnchor, constant: -8),
            textLabelTopConstraint!
        ])
    }
    
    private func setupScrollViewObserver() {
        // 移除之前的观察者
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        scrollView?.removeObserver(self, forKeyPath: "contentSize")
        
        // 查找父视图中的 UIScrollView
        scrollView = findScrollView(in: superview)
        
        // 调试信息
        print("🔍 查找滚动视图: \(scrollView != nil ? "找到" : "未找到")")
        if let scrollView = scrollView {
            print("📏 滚动视图内容大小: \(scrollView.contentSize)")
            print("📐 滚动视图边界: \(scrollView.bounds)")
        }
        
        // 添加新的观察者
        scrollView?.addObserver(self, forKeyPath: "contentOffset", options: [.new], context: nil)
        scrollView?.addObserver(self, forKeyPath: "contentSize", options: [.new], context: nil)
        
        // 立即配置
        configureWithScrollView()
    }
    
    private func findScrollView(in view: UIView?) -> UIScrollView? {
        guard let view = view else { return nil }
        
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        
        return nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            handleContentOffsetChange()
            updateScrollPosition()
        } else if keyPath == "contentSize" {
            configureWithScrollView()
        }
    }
    
    /// 处理 contentOffset 变化，自动检测滚动状态
    private func handleContentOffsetChange() {
        guard let scrollView = scrollView else { return }
        
        // 如果正在拖动指示器，不处理自动滚动检测
        if isIndicatorDragging {
            return
        }
        
        let currentOffset = scrollView.contentOffset
        let offsetChanged = currentOffset != lastContentOffset
        
        // 检测滚动开始
        if offsetChanged && !isDragging && !isDecelerating {
            // 检查是否是由用户拖拽开始的滚动
            if scrollView.isDragging {
                isDragging = true
                scrollViewWillBeginDragging()
            }
        }
        
        // 检测拖拽结束
        if isDragging && !scrollView.isDragging {
            isDragging = false
            scrollViewDidEndDragging()
            
            // 如果还在减速，设置减速状态
            if scrollView.isDecelerating {
                isDecelerating = true
            }
        }
        
        // 检测减速结束
        if isDecelerating && !scrollView.isDecelerating {
            isDecelerating = false
            scrollViewDidEndDecelerating()
        }
        
        lastContentOffset = currentOffset
    }
    
    /// 滚动开始时的处理
    private func scrollViewWillBeginDragging() {
        print("🚀 滚动开始，显示指示器")
        if scrollView?.contentSize.height ?? 0 > scrollView?.bounds.height ?? 0 {
            show()
        }
    }
    
    /// 滚动结束时的处理
    private func scrollViewDidEndDragging() {
        print("🛑 滚动结束，设置自动隐藏")
        autoHide(after: 2.0)
    }
    
    /// 滚动完全停止时的处理
    private func scrollViewDidEndDecelerating() {
        print("⏹️ 滚动完全停止，设置自动隐藏")
        autoHide(after: 2.0)
    }
    
    deinit {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        scrollView?.removeObserver(self, forKeyPath: "contentSize")
    }
    
    private func configureWithScrollView() {
        guard let scrollView = scrollView, frame.height > 0 else { 
            print("⚠️ 配置失败: scrollView=\(scrollView != nil), frame.height=\(frame.height)")
            return 
        }
        
        let contentHeight = scrollView.contentSize.height
        let visibleHeight = scrollView.bounds.height
        
        print("📊 配置指示器: contentHeight=\(contentHeight), visibleHeight=\(visibleHeight), frame.height=\(frame.height)")
        
        // 如果内容高度小于等于可见高度，隐藏指示器
        if contentHeight <= visibleHeight {
            print("📏 内容不需要滚动，隐藏指示器")
            indicatorView.isHidden = true
            alpha = 0.0
            isConfigured = true
            return
        }
        
        // 计算指示器高度（基于可见区域与总内容的比例）
        let indicatorHeight = max(indicatorWidth, (visibleHeight / contentHeight) * frame.height)
        indicatorHeightConstraint?.constant = indicatorHeight
        indicatorView.isHidden = false
        isConfigured = true
        
        print("✅ 指示器配置完成: indicatorHeight=\(indicatorHeight), 初始隐藏")
    }
    
    private func updateScrollPosition() {
        guard let scrollView = scrollView, 
              scrollView.contentSize.height > scrollView.bounds.height,
              frame.height > 0 else { 
            return 
        }
        
        let contentHeight = scrollView.contentSize.height
        let visibleHeight = scrollView.bounds.height
        let scrollOffset = scrollView.contentOffset.y
        
        // 计算滚动进度 (0.0 到 1.0)
        let maxScrollOffset = contentHeight - visibleHeight
        let scrollProgress = max(0, min(1, scrollOffset / maxScrollOffset))
        
        // 计算指示器应该移动的距离
        let indicatorHeight = indicatorHeightConstraint?.constant ?? indicatorWidth
        let maxIndicatorOffset = frame.height - indicatorHeight
        let indicatorOffset = scrollProgress * maxIndicatorOffset
        
        // 更新指示器位置
        indicatorTopConstraint?.constant = indicatorOffset
        
        // 更新文字内容
        updateTextContent(for: scrollProgress)
    }
    
    /// 更新文字内容
    private func updateTextContent(for scrollProgress: CGFloat) {
        guard let text = delegate?.scrollIndicator(self, textForScrollProgress: scrollProgress) else {
            textLabel.alpha = 0.0
            return
        }
        
        textLabel.text = text
        textLabel.alpha = 1.0
    }
    
    /// 显示指示器
    func show() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
            self.textLabel.alpha = 1.0
        }
    }
    
    /// 隐藏指示器
    func hide() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0.0
            self.textLabel.alpha = 0.0
        }
    }
    
    /// 自动隐藏指示器（延迟）
    func autoHide(after delay: TimeInterval = 2.0) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideIndicator), object: nil)
        perform(#selector(hideIndicator), with: nil, afterDelay: delay)
    }
    
    @objc private func hideIndicator() {
        hide()
    }
    
}
