import UIKit

final class OverlaySettingsViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case overlayEnabled
        case detail
    }

    private let settings = OverlayDisplaySettings.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "叠加信息设置"
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = Row(rawValue: indexPath.row) else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        cell.accessoryView = nil
        cell.accessoryType = .none

        switch row {
        case .overlayEnabled:
            cell.textLabel?.text = "显示叠加信息"
            let sw = UISwitch()
            sw.isOn = settings.overlayEnabled
            sw.addTarget(self, action: #selector(didToggleOverlayEnabled(_:)), for: .valueChanged)
            cell.accessoryView = sw
        case .detail:
            cell.textLabel?.text = "叠加信息详细设置"
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row), row == .detail else { return }
        navigationController?.pushViewController(OverlayDetailSettingsViewController(), animated: true)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "关闭“显示叠加信息”后，不再显示任何序号或日期。"
    }

    @objc private func didToggleOverlayEnabled(_ sender: UISwitch) {
        settings.overlayEnabled = sender.isOn
    }
}

final class OverlayDetailSettingsViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case showCreationDateInCustom
        case showModificationDateInCustom
        case showCustomOrderInDateSort
        case showFieldPrefixes
    }

    private let settings = OverlayDisplaySettings.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "详细设置"
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = Row(rawValue: indexPath.row) else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        cell.accessoryType = .none

        let sw = UISwitch()
        sw.tag = row.rawValue
        sw.addTarget(self, action: #selector(didToggleDetailOption(_:)), for: .valueChanged)

        switch row {
        case .showCreationDateInCustom:
            cell.textLabel?.text = "自定义排序时显示创建日期"
            sw.isOn = settings.showCreationDateInCustom
        case .showModificationDateInCustom:
            cell.textLabel?.text = "自定义排序时显示修改日期"
            sw.isOn = settings.showModificationDateInCustom
        case .showCustomOrderInDateSort:
            cell.textLabel?.text = "日期排序时显示自定义序号"
            sw.isOn = settings.showCustomOrderInDateSort
        case .showFieldPrefixes:
            cell.textLabel?.text = "显示字段前缀（创建/修改/序号）"
            sw.isOn = settings.showFieldPrefixes
        }

        cell.accessoryView = sw
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "C = 创建日期（creationDate），M = 修改日期（modificationDate），# = 自定义序号（照片在自定义排序中的位置）。"
    }

    @objc private func didToggleDetailOption(_ sender: UISwitch) {
        guard let row = Row(rawValue: sender.tag) else { return }
        switch row {
        case .showCreationDateInCustom:
            settings.showCreationDateInCustom = sender.isOn
        case .showModificationDateInCustom:
            settings.showModificationDateInCustom = sender.isOn
        case .showCustomOrderInDateSort:
            settings.showCustomOrderInDateSort = sender.isOn
        case .showFieldPrefixes:
            settings.showFieldPrefixes = sender.isOn
        }
    }
}
