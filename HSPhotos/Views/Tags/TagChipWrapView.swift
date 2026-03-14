//
//  TagChipWrapView.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//

import UIKit

/// 自动换行的标签 chip 容器，根据内容高度自适应
final class TagChipWrapView: UIView {

    var onTap: ((String) -> Void)?
    var onLongPress: ((String) -> Void)?

    private var chips: [TagChipView] = []
    private let spacing: CGFloat = 8
    private var selectedIDs: Set<String>

    init(tags: [PhotoTag], selectedIDs: Set<String>) {
        self.selectedIDs = selectedIDs
        super.init(frame: .zero)
        setupChips(tags: tags)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupChips(tags: [PhotoTag]) {
        chips.forEach { $0.removeFromSuperview() }
        chips = tags.map { tag in
            let chip = TagChipView(name: tag.name, tagID: tag.id)
            chip.isSelected = selectedIDs.contains(tag.id)
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(chipLongPressed(_:)))
            chip.addGestureRecognizer(longPress)

            addSubview(chip)
            return chip
        }
        invalidateIntrinsicContentSize()
    }

    @objc private func chipTapped(_ sender: TagChipView) {
        onTap?(sender.tag_id)
    }

    @objc private func chipLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let chip = gesture.view as? TagChipView else { return }
        onLongPress?(chip.tag_id)
    }

    // MARK: - 自动换行布局

    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chips {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            chip.frame = CGRect(x: currentX, y: currentY, width: size.width, height: size.height)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    override var intrinsicContentSize: CGSize {
        let maxWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 32
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chips {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        let totalHeight = chips.isEmpty ? 0 : currentY + rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }
}
