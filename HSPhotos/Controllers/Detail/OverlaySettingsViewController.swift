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
    private enum Section: Int, CaseIterable {
        case hierarchyCollapse
        case overlayDetail
    }

    private enum Row: Int, CaseIterable {
        case showCreationDateInCustom
        case showModificationDateInCustom
        case showCustomOrderInDateSort
        case showFieldPrefixes
    }

    private let settings = OverlayDisplaySettings.shared
    private let hierarchySettings = HierarchyCollapseSettings.shared

    private let hierarchySegmentTag = 991

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "详细设置"
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .hierarchyCollapse: return 1
        case .overlayDetail: return Row.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        if sec == .hierarchyCollapse {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.textLabel?.text = "无编号间隙"
            let segment: UISegmentedControl
            if let existing = cell.accessoryView as? UISegmentedControl, existing.tag == hierarchySegmentTag {
                segment = existing
            } else {
                let seg = UISegmentedControl(items: ["断开", "含间隙"])
                seg.tag = hierarchySegmentTag
                seg.apportionsSegmentWidthsByContent = true
                cell.accessoryView = seg
                segment = seg
            }
            segment.removeTarget(nil, action: nil, for: .valueChanged)
            segment.selectedSegmentIndex = hierarchySettings.spanMode == .breakAtUnnumbered ? 0 : 1
            segment.addTarget(self, action: #selector(hierarchySpanModeChanged(_:)), for: .valueChanged)
            return cell
        }

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

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .hierarchyCollapse: return "层级折叠"
        case .overlayDetail: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .hierarchyCollapse:
            return "「遇无编号断开」：中间的无层级照片会打断折叠。「折叠含间隙」：只有「后面第一个有编号」仍比折叠根更深时，该无层级图才随子编号一起隐藏；若后面已回到同级或更浅（如 3.1 与 4 之间），其间无层级图不折叠。"
        case .overlayDetail:
            return "C = 创建日期（creationDate），M = 修改日期（modificationDate），# = 自定义序号（照片在自定义排序中的位置）。"
        }
    }

    @objc private func hierarchySpanModeChanged(_ sender: UISegmentedControl) {
        let mode: HierarchyCollapseSpanMode = sender.selectedSegmentIndex == 0 ? .breakAtUnnumbered : .includeGaps
        hierarchySettings.spanMode = mode
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
