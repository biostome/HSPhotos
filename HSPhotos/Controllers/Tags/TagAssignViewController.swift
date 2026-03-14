//
//  TagAssignViewController.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//

import UIKit

/// 为照片打标签的面板（区别于过滤面板，此处直接修改持久化数据）
final class TagAssignViewController: UIViewController {

    private let assetIdentifiers: [String]
    private var allTags: [PhotoTag] = []

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
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("完成", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "TagCell")
        return tv
    }()

    // MARK: - Init

    init(assetIdentifiers: [String]) {
        self.assetIdentifiers = assetIdentifiers
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(doneButton)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadData() {
        allTags = PhotoTagService.shared.loadTags()
        let count = assetIdentifiers.count
        titleLabel.text = count == 1 ? "添加标签" : "为 \(count) 张照片添加标签"
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func didTapDone() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension TagAssignViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return allTags.count }
        return 1 // 创建新标签
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "选择标签" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)

        if indexPath.section == 1 {
            var config = cell.defaultContentConfiguration()
            config.text = "创建新标签..."
            config.image = UIImage(systemName: "plus.circle.fill")
            config.imageProperties.tintColor = .systemBlue
            config.textProperties.color = .systemBlue
            cell.contentConfiguration = config
            cell.accessoryType = .none
            return cell
        }

        let tag = allTags[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = tag.name
        config.image = UIImage(systemName: "tag")
        cell.contentConfiguration = config

        // 判断当前所选照片中有多少已有此标签
        let taggedCount = assetIdentifiers.filter { tag.assetIdentifiers.contains($0) }.count
        if taggedCount == assetIdentifiers.count {
            // 全部已打标签
            cell.accessoryType = .checkmark
        } else if taggedCount > 0 {
            // 部分已打标签（用虚线圆圈表示）
            let partial = UIImageView(image: UIImage(systemName: "minus.circle"))
            partial.tintColor = .systemBlue
            cell.accessoryView = partial
        } else {
            cell.accessoryType = .none
            cell.accessoryView = nil
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            showCreateTagAlert()
            return
        }

        let tag = allTags[indexPath.row]
        let taggedCount = assetIdentifiers.filter { tag.assetIdentifiers.contains($0) }.count

        if taggedCount == assetIdentifiers.count {
            // 全部已有 → 全部移除
            PhotoTagService.shared.removeAssets(assetIdentifiers, fromTag: tag.id)
        } else {
            // 部分或全无 → 全部添加
            PhotoTagService.shared.addAssets(assetIdentifiers, toTag: tag.id)
        }

        allTags = PhotoTagService.shared.loadTags()
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    private func showCreateTagAlert() {
        let alert = UIAlertController(title: "创建标签", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "标签名称" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建并添加", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { return }
            let newTag = PhotoTagService.shared.createTag(name: name)
            PhotoTagService.shared.addAssets(self.assetIdentifiers, toTag: newTag.id)
            self.loadData()
        })
        present(alert, animated: true)
    }
}
