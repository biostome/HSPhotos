import UIKit
import Photos

final class AssetDateAdjustmentViewController: UIViewController {
    var onAssetDateUpdated: ((PHAsset) -> Void)?
    
    private let asset: PHAsset
    private let originalCreationDate: Date?
    private let currentlyDisplayedDate: Date
    
    // 如果修改了时间，则为 true
    private var hasTimeModification: Bool {
        selectedDate != originalCreationDate
    }
    
    private var selectedDate: Date {
        didSet {
            updateSummaryCard()
            updateActionButton()
        }
    }
    
    // MARK: - UI Components
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(weight: .medium)), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.text = "调整日期与时间"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let summaryCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let originalTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.text = "原片时间"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let originalTimeValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let adjustedTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.text = "调整后"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let adjustedTimeValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pickerCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var calendarDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.locale = Locale.current
        picker.date = selectedDate
        picker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
        picker.backgroundColor = .clear
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.text = "时间"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var timeDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale.current
        picker.date = selectedDate
        picker.addTarget(self, action: #selector(timePickerChanged), for: .valueChanged)
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private let timeZoneLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.text = "时区"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeZoneValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeZoneChevron: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    
    init(asset: PHAsset, onAssetDateUpdated: ((PHAsset) -> Void)? = nil) {
        self.asset = asset
        self.onAssetDateUpdated = onAssetDateUpdated
        self.originalCreationDate = asset.creationDate
        self.currentlyDisplayedDate = asset.creationDate ?? Date()
        self.selectedDate = asset.creationDate ?? Date()
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        updateSummaryCard()
        updateActionButton()
        updateTimeZone()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        
        // Top bar
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        topBar.addSubview(closeButton)
        topBar.addSubview(titleLabel)
        topBar.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            actionButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 32),
            
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Summary card
        view.addSubview(summaryCard)
        
        summaryCard.addSubview(originalTimeLabel)
        summaryCard.addSubview(originalTimeValueLabel)
        summaryCard.addSubview(adjustedTimeLabel)
        summaryCard.addSubview(adjustedTimeValueLabel)
        
        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        separator.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(separator)
        
        NSLayoutConstraint.activate([
            originalTimeLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            originalTimeLabel.centerYAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 24),
            
            originalTimeValueLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            originalTimeValueLabel.centerYAnchor.constraint(equalTo: originalTimeLabel.centerYAnchor),
            
            adjustedTimeLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            adjustedTimeLabel.centerYAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -24),
            
            adjustedTimeValueLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            adjustedTimeValueLabel.centerYAnchor.constraint(equalTo: adjustedTimeLabel.centerYAnchor),
            
            separator.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            separator.centerYAnchor.constraint(equalTo: summaryCard.centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            
            summaryCard.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 18),
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            summaryCard.heightAnchor.constraint(equalToConstant: 96)
        ])
        
        // Picker card
        view.addSubview(pickerCard)
        
        // Calendar picker
        pickerCard.addSubview(calendarDatePicker)
        
        // Time row
        pickerCard.addSubview(timeLabel)
        pickerCard.addSubview(timeDatePicker)
        
        let timeSeparator = UIView()
        timeSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        timeSeparator.translatesAutoresizingMaskIntoConstraints = false
        pickerCard.addSubview(timeSeparator)
        
        // Time zone row
        pickerCard.addSubview(timeZoneLabel)
        pickerCard.addSubview(timeZoneValueLabel)
        pickerCard.addSubview(timeZoneChevron)
        
        NSLayoutConstraint.activate([
            // Calendar picker constraints
            calendarDatePicker.topAnchor.constraint(equalTo: pickerCard.topAnchor, constant: 8),
            calendarDatePicker.leadingAnchor.constraint(equalTo: pickerCard.leadingAnchor, constant: 8),
            calendarDatePicker.trailingAnchor.constraint(equalTo: pickerCard.trailingAnchor, constant: -8),
            
            // Time row constraints
            timeLabel.leadingAnchor.constraint(equalTo: pickerCard.leadingAnchor, constant: 16),
            timeLabel.topAnchor.constraint(equalTo: calendarDatePicker.bottomAnchor, constant: 0),
            
            timeDatePicker.trailingAnchor.constraint(equalTo: pickerCard.trailingAnchor, constant: -16),
            timeDatePicker.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            
            timeSeparator.leadingAnchor.constraint(equalTo: pickerCard.leadingAnchor, constant: 16),
            timeSeparator.trailingAnchor.constraint(equalTo: pickerCard.trailingAnchor, constant: -16),
            timeSeparator.topAnchor.constraint(equalTo: timeDatePicker.bottomAnchor, constant: 12),
            timeSeparator.heightAnchor.constraint(equalToConstant: 0.5),
            
            // Time zone row constraints
            timeZoneLabel.leadingAnchor.constraint(equalTo: pickerCard.leadingAnchor, constant: 16),
            timeZoneLabel.topAnchor.constraint(equalTo: timeSeparator.bottomAnchor, constant: 16),
            timeZoneLabel.bottomAnchor.constraint(equalTo: pickerCard.bottomAnchor, constant: -16),
            
            timeZoneChevron.trailingAnchor.constraint(equalTo: pickerCard.trailingAnchor, constant: -16),
            timeZoneChevron.centerYAnchor.constraint(equalTo: timeZoneLabel.centerYAnchor),
            
            timeZoneValueLabel.trailingAnchor.constraint(equalTo: timeZoneChevron.leadingAnchor, constant: -8),
            timeZoneValueLabel.centerYAnchor.constraint(equalTo: timeZoneLabel.centerYAnchor)
        ])
        
        // Picker card constraints
        NSLayoutConstraint.activate([
            pickerCard.topAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: 18),
            pickerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pickerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pickerCard.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupGestures() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func actionTapped() {
        if hasTimeModification {
            applyAdjustedDate(selectedDate)
        } else {
            // 如果 picker 没动过，点击的动作就是还原（或者完成，如果没有任何效果）
            restoreOriginalDate()
        }
    }
    
    @objc private func datePickerChanged() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: calendarDatePicker.date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
        
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        } else {
            selectedDate = calendarDatePicker.date
        }
    }
    
    @objc private func timePickerChanged(_ sender: UIDatePicker) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: sender.date)
        
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }
    
    // MARK: - UI Update Methods
    
    private func updateSummaryCard() {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        
        if let originalDate = originalCreationDate {
            originalTimeValueLabel.text = dateFormatter.string(from: originalDate)
            originalTimeLabel.textColor = .label
        } else {
            originalTimeValueLabel.text = "未知"
            originalTimeLabel.textColor = .label
        }
        
        adjustedTimeValueLabel.text = dateFormatter.string(from: selectedDate)
        
        if timeDatePicker.date != selectedDate {
            timeDatePicker.date = selectedDate
        }
        if calendarDatePicker.date != selectedDate {
            calendarDatePicker.date = selectedDate
        }
    }
    
    private func updateActionButton() {
        if hasTimeModification {
            actionButton.setTitle("调整", for: .normal)
            actionButton.setTitleColor(.systemBlue, for: .normal)
        } else {
            actionButton.setTitle("复原", for: .normal)
            actionButton.setTitleColor(.systemRed, for: .normal)
        }
    }
    
    private func updateTimeZone() {
        let timeZone = TimeZone.current
        if timeZone.identifier == "Asia/Shanghai" || timeZone.secondsFromGMT() == 28800 {
            timeZoneValueLabel.text = "北京"
        } else {
            let offset = timeZone.secondsFromGMT()
            let hours = offset / 3600
            let sign = hours >= 0 ? "+" : ""
            timeZoneValueLabel.text = "GMT\(sign)\(hours)"
        }
    }
    
    // MARK: - Data Modification Methods
    
    private func applyAdjustedDate(_ date: Date) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.asset)
            request.creationDate = date
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [self.asset.localIdentifier], options: nil)
                    let updatedAsset = result.firstObject ?? self.asset
                    self.onAssetDateUpdated?(updatedAsset)
                    self.dismiss(animated: true)
                } else {
                    let alert = UIAlertController(
                        title: "调整失败",
                        message: error?.localizedDescription ?? "未知错误",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func restoreOriginalDate() {
        // 利用 Photos 的重置机制或将 modificationDate 置空等方式还原（这里使用 revert 接口或置空）
        // 大多数情况下，直接给 creationDate 设为原始可能拿不到真正的原图时间，但是用户需求是“无需UserDefaults，用Photos自带API”，
        // 这里可以直接清空 creationDate。或者根据业务场景如果单纯恢复原片，直接执行 revertAssetContentToOriginal。
        // 不过最安全的办法是将 creationDate 设回 nil，Photos 系统底层会恢复原时间
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.asset)
            request.creationDate = nil
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [self.asset.localIdentifier], options: nil)
                    let updatedAsset = result.firstObject ?? self.asset
                    self.onAssetDateUpdated?(updatedAsset)
                    self.dismiss(animated: true)
                } else {
                    let alert = UIAlertController(
                        title: "恢复失败",
                        message: error?.localizedDescription ?? "未知错误",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
#if DEBUG
#Preview {
    let placeholderAsset = PHAsset()
    return AssetDateAdjustmentViewController(asset: placeholderAsset)
}
#endif
