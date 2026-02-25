//
//  SearchBarView.swift
//  HSPhotos
//
//  Created by Hans on 2025/9/3.
//

import UIKit

protocol SearchBarViewDelegate: AnyObject {
    func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String)
}

class SearchBarView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: SearchBarViewDelegate?
    
//    private lazy var backgroundView: UIVisualEffectView = {
//        let blurEffect = UIBlurEffect(style: .systemThickMaterialLight)
//        let visualEffectView = UIVisualEffectView(effect: blurEffect)
//        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
//        visualEffectView.layer.cornerRadius = 10
//        visualEffectView.clipsToBounds = true
//        return visualEffectView
//    }()
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        
        // 创建真正的磨砂玻璃效果
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        // 添加半透明覆盖层增强磨砂效果
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.3)
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.layer.cornerRadius = 10
        overlayView.clipsToBounds = true
        
        view.addSubview(blurView)
        view.addSubview(overlayView)
        
        // 添加微妙的阴影效果增强磨砂玻璃质感
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 8
        
        // 添加微妙的边框
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.systemGray5.withAlphaComponent(0.4).cgColor
        
        return view
    }()
    
    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "搜索照片"
        textField.delegate = self
        textField.layer.cornerRadius = 10
        textField.returnKeyType = .search
        textField.clearButtonMode = .whileEditing
        textField.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        textField.textColor = .label
        textField.backgroundColor = .clear
        textField.attributedPlaceholder = .init(string: "搜索照片", attributes: [NSAttributedString.Key.foregroundColor : UIColor.secondaryLabel])
        // 添加左侧放大镜图标
        let magnifyingGlassImageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        magnifyingGlassImageView.tintColor = .secondaryLabel
        magnifyingGlassImageView.contentMode = .scaleAspectFit
        magnifyingGlassImageView.frame = CGRect(x: (44 - 16) / 2, y: (44 - 16) / 2, width: 16, height: 16)
        
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        leftView.addSubview(magnifyingGlassImageView)
        magnifyingGlassImageView.center = leftView.center
        
        textField.leftView = leftView
        textField.leftViewMode = .always
        
        // 设置内边距
        textField.layer.borderWidth = 0
        textField.borderStyle = .none
        
        return textField
    }()
    
    var text: String? {
        get { return textField.text }
        set { textField.text = newValue }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // 先添加磨砂背景
        addSubview(backgroundView)
        
        // 再添加文本字段，确保在磨砂背景之上
        addSubview(textField)
        
        NSLayoutConstraint.activate([
            // 磨砂背景约束
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 文本框约束
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    // MARK: - Public Methods
    
    func resignFirstResponder() {
        textField.resignFirstResponder()
    }
    
    func becomeFirstResponder() {
        textField.becomeFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension SearchBarView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else {
            textField.resignFirstResponder()
            return false
        }
        delegate?.searchBarView(self, didSearchWith: text)
        textField.resignFirstResponder()
        return true
    }
}
