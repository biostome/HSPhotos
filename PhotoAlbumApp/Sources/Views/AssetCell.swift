import UIKit

final class AssetCell: UICollectionViewCell {
    static let reuseId = "AssetCell"

    let imageView = UIImageView()
    let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .tertiarySystemFill
        contentView.addSubview(imageView)

        badgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        contentView.addSubview(badgeLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        badgeLabel.text = nil
        badgeLabel.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        let badgeHeight: CGFloat = 16
        let badgeWidth: CGFloat = min(44, contentView.bounds.width - 8)
        badgeLabel.frame = CGRect(x: contentView.bounds.maxX - badgeWidth - 4, y: contentView.bounds.maxY - badgeHeight - 4, width: badgeWidth, height: badgeHeight)
    }
}

