//
//  TagFilterPanelViewController.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//

import UIKit

protocol TagFilterPanelDelegate: AnyObject {
    func tagFilterPanel(_ panel: TagFilterPanelViewController, didApply state: TagFilterState)
}

final class TagFilterPanelViewController: UIViewController {

    weak var delegate: TagFilterPanelDelegate?

    // 当前所有照片的 identifier，用于预览数量
    var candidateIdentifiers: [String] = []

    // 当前面板状态（外部传入的初始状态）
    private var filterState: TagFilterState

    private var allTags: [PhotoTag] = []
    private var recentTags: [PhotoTag] = []
    private var filteredTags: [PhotoTag] = []
    private var isSearching = false

    // MARK: - UI

    private lazy var handleBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        view.layer.cornerRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "按标签筛选"
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var searchField: UISearchTextField = {
        let field = UISearchTextField()
        field.placeholder = "搜索标签"
        field.font = UIFont.systemFont(ofSize: 15)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        return field
    }()

    private lazy var matchRuleControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["满足任一标签", "满足所有标签"])
        control.selectedSegmentIndex = filterState.matchRule == .any ? 0 : 1
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(matchRuleChanged), for: .valueChanged)
        return control
    }()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        sv.keyboardDismissMode = .onDrag
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var applyButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.title = "应用筛选"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemBlue
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapApply), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    init(currentState: TagFilterState) {
        self.filterState = currentState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        loadTags()
        updateApplyButton()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(resetButton)
        view.addSubview(searchField)
        view.addSubview(scrollView)
        view.addSubview(applyButton)

        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            resetButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 40),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: applyButton.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            applyButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Data

    private func loadTags() {
        allTags = PhotoTagService.shared.loadTags()
        recentTags = PhotoTagService.shared.recentlyUsedTags()
        rebuildChips()
    }

    private func rebuildChips() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if isSearching {
            if filteredTags.isEmpty {
                let empty = makeEmptyLabel("未找到相关标签")
                contentStack.addArrangedSubview(empty)
            } else {
                let section = makeChipSection(title: "搜索结果", tags: filteredTags)
                contentStack.addArrangedSubview(section)
            }
        } else {
            if !recentTags.isEmpty {
                let recent = makeChipSection(title: "最近使用", tags: recentTags)
                contentStack.addArrangedSubview(recent)
            }

            if allTags.isEmpty {
                let empty = makeEmptyLabel("还没有标签，点击下方按钮创建")
                contentStack.addArrangedSubview(empty)
            } else {
                let all = makeChipSection(title: "全部标签", tags: allTags)
                contentStack.addArrangedSubview(all)
            }
        }

        // 匹配规则
        let ruleStack = UIStackView(arrangedSubviews: [matchRuleControl])
        ruleStack.axis = .vertical
        ruleStack.spacing = 8
        let ruleLabel = UILabel()
        ruleLabel.text = "匹配规则"
        ruleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        ruleLabel.textColor = .secondaryLabel
        ruleStack.insertArrangedSubview(ruleLabel, at: 0)
        contentStack.addArrangedSubview(ruleStack)

        // 创建新标签
        let createButton = makeCreateTagButton()
        contentStack.addArrangedSubview(createButton)
    }

    private func makeChipSection(title: String, tags: [PhotoTag]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let wrapView = TagChipWrapView(tags: tags, selectedIDs: filterState.selectedTagIDs)
        wrapView.translatesAutoresizingMaskIntoConstraints = false
        wrapView.onTap = { [weak self] tagID in
            self?.toggleTag(tagID)
        }
        wrapView.onLongPress = { [weak self] tagID in
            self?.showTagManageMenu(tagID: tagID)
        }

        container.addSubview(label)
        container.addSubview(wrapView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            wrapView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            wrapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wrapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wrapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private func makeCreateTagButton() -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = "创建新标签"
        config.image = UIImage(systemName: "plus")
        config.imagePadding = 6
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(didTapCreateTag), for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    private func toggleTag(_ tagID: String) {
        if filterState.selectedTagIDs.contains(tagID) {
            filterState.selectedTagIDs.remove(tagID)
        } else {
            filterState.selectedTagIDs.insert(tagID)
        }
        rebuildChips()
        updateApplyButton()
    }

    private func updateApplyButton() {
        let count = PhotoTagService.shared.previewCount(in: candidateIdentifiers, state: filterState)
        if filterState.isActive {
            applyButton.configuration?.title = "应用筛选（\(count) 张照片）"
        } else {
            applyButton.configuration?.title = "显示全部照片（\(candidateIdentifiers.count) 张）"
        }
    }

    @objc private func didTapApply() {
        delegate?.tagFilterPanel(self, didApply: filterState)
        dismiss(animated: true)
    }

    @objc private func didTapReset() {
        filterState.selectedTagIDs.removeAll()
        filterState.matchRule = .any
        matchRuleControl.selectedSegmentIndex = 0
        rebuildChips()
        updateApplyButton()
    }

    @objc private func matchRuleChanged() {
        filterState.matchRule = matchRuleControl.selectedSegmentIndex == 0 ? .any : .all
        updateApplyButton()
    }

    @objc private func searchTextChanged() {
        let query = searchField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if query.isEmpty {
            isSearching = false
            filteredTags = []
        } else {
            isSearching = true
            filteredTags = allTags.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        rebuildChips()
    }

    @objc private func didTapCreateTag() {
        searchField.resignFirstResponder()
        let alert = UIAlertController(title: "创建标签", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "标签名称"
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { return }
            let newTag = PhotoTagService.shared.createTag(name: name)
            self.allTags = PhotoTagService.shared.loadTags()
            self.recentTags = PhotoTagService.shared.recentlyUsedTags()
            // 自动选中新建标签
            self.filterState.selectedTagIDs.insert(newTag.id)
            self.rebuildChips()
            self.updateApplyButton()
        })
        present(alert, animated: true)
    }

    private func showTagManageMenu(tagID: String) {
        guard let tag = allTags.first(where: { $0.id == tagID }) else { return }
        let alert = UIAlertController(title: tag.name, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "重命名", style: .default) { [weak self] _ in
            self?.showRenameAlert(tagID: tagID, currentName: tag.name)
        })
        alert.addAction(UIAlertAction(title: "删除标签", style: .destructive) { [weak self] _ in
            PhotoTagService.shared.deleteTag(id: tagID)
            self?.filterState.selectedTagIDs.remove(tagID)
            self?.loadTags()
            self?.updateApplyButton()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func showRenameAlert(tagID: String, currentName: String) {
        let alert = UIAlertController(title: "重命名标签", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = currentName
            field.selectAll(nil)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let newName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !newName.isEmpty else { return }
            PhotoTagService.shared.renameTag(id: tagID, newName: newName)
            self.loadTags()
        })
        present(alert, animated: true)
    }
}
