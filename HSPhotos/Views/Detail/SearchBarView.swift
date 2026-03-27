//
//  SearchBarView.swift
//  HSPhotos
//
//  Created by Hans on 2025/9/3.
//

import UIKit

protocol SearchBarViewDelegate: AnyObject {
    func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String)
    func searchBarViewDidRemoveToken(_ searchBarView: SearchBarView, tagID: String)
    func searchBarViewDidTapFilter(_ searchBarView: SearchBarView)
}

extension SearchBarViewDelegate {
    func searchBarViewDidRemoveToken(_ searchBarView: SearchBarView, tagID: String) {}
    func searchBarViewDidTapFilter(_ searchBarView: SearchBarView) {}
}

class SearchBarView: UIView {

    // MARK: - Properties

    weak var delegate: SearchBarViewDelegate?

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.clipsToBounds = true

        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true

        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.3)
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.layer.cornerRadius = 10
        overlayView.clipsToBounds = true

        view.addSubview(blurView)
        view.addSubview(overlayView)

        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.08
        view.layer.shadowRadius = 8
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.systemGray5.withAlphaComponent(0.4).cgColor

        return view
    }()

    /// 使用 UISearchTextField 以支持原生 UISearchToken
    private lazy var searchTextField: UISearchTextField = {
        let field = UISearchTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "搜索照片"
        field.delegate = self
        field.returnKeyType = .search
        field.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        field.textColor = .label
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.attributedPlaceholder = NSAttributedString(
            string: "搜索照片",
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        // 监听 token 删除
        field.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return field
    }()

    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        button.tintColor = .secondaryLabel
        button.addTarget(self, action: #selector(didTapFilterButton), for: .touchUpInside)
        return button
    }()

    var text: String? {
        get { return searchTextField.text }
        set { searchTextField.text = newValue }
    }

    var activeTokenIDs: [String] {
        return searchTextField.tokens.compactMap { $0.representedObject as? String }
    }

    var isFilterActive: Bool = false {
        didSet { updateFilterButtonAppearance() }
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
        addSubview(backgroundView)
        addSubview(searchTextField)
        addSubview(filterButton)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            searchTextField.topAnchor.constraint(equalTo: topAnchor),
            searchTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            searchTextField.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -6),
            searchTextField.bottomAnchor.constraint(equalTo: bottomAnchor),

            filterButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            filterButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: 26),
            filterButton.heightAnchor.constraint(equalToConstant: 26),
        ])
        updateFilterButtonAppearance()
    }

    // MARK: - Token 管理

    /// 设置当前激活的过滤 token（同步外部 filterState 到 UI）
    func setFilterTokens(from tags: [PhotoTag]) {
        // 保留文字输入，只刷新 tokens
        searchTextField.tokens = tags.map { tag in
            let token = UISearchToken(icon: UIImage(systemName: "tag.fill"), text: tag.name)
            token.representedObject = tag.id as NSString
            return token
        }
    }

    func clearTokens() {
        searchTextField.tokens = []
    }

    // MARK: - Public Methods

    override func resignFirstResponder() -> Bool {
        return searchTextField.resignFirstResponder()
    }

    override func becomeFirstResponder() -> Bool {
        return searchTextField.becomeFirstResponder()
    }

    // MARK: - Private

    @objc private func textFieldDidChange() {
        // 检测 token 是否被用户手动删除（系统退格键删除 token 时触发）
        // 对比现有 token 与上次记录的差异
        // 此处简单通知上层重新同步状态
        syncRemovedTokens()
    }

    private var lastKnownTokenIDs: Set<String> = []

    private func syncRemovedTokens() {
        let currentIDs = Set(activeTokenIDs)
        let removed = lastKnownTokenIDs.subtracting(currentIDs)
        removed.forEach { tagID in
            delegate?.searchBarViewDidRemoveToken(self, tagID: tagID)
        }
        lastKnownTokenIDs = currentIDs
    }

    /// 上层调用，每次同步完 token 后更新记录
    func markTokensSynced() {
        lastKnownTokenIDs = Set(activeTokenIDs)
    }

    @objc private func didTapFilterButton() {
        delegate?.searchBarViewDidTapFilter(self)
    }

    private func updateFilterButtonAppearance() {
        filterButton.tintColor = isFilterActive ? .systemBlue : .secondaryLabel
        let imageName = isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        filterButton.setImage(UIImage(systemName: imageName), for: .normal)
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
