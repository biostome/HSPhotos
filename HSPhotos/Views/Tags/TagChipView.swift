//
//  TagChipView.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//

import UIKit

/// 标签胶囊按钮，支持选中/未选中两种状态
final class TagChipView: UIControl {

    var tag_id: String = ""

    private let label = UILabel()
    private let checkmark = UIImageView()

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.95, y: 0.95)
                    : .identity
            }
        }
    }

    init(name: String, tagID: String) {
        super.init(frame: .zero)
        self.tag_id = tagID
        label.text = name
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        clipsToBounds = true

        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        checkmark.image = UIImage(systemName: "checkmark")
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true

        let stack = UIStackView(arrangedSubviews: [checkmark, label])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            checkmark.widthAnchor.constraint(equalToConstant: 12),
            checkmark.heightAnchor.constraint(equalToConstant: 12),
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            backgroundColor = .systemBlue
            layer.borderColor = UIColor.systemBlue.cgColor
            label.textColor = .white
            checkmark.tintColor = .white
            checkmark.isHidden = false
        } else {
            backgroundColor = .secondarySystemBackground
            layer.borderColor = UIColor.separator.cgColor
            label.textColor = .label
            checkmark.isHidden = true
        }
    }

    func updateName(_ name: String) {
        label.text = name
    }
}
