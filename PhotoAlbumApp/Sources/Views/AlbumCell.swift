import UIKit

final class AlbumCell: UICollectionViewCell {
    static let reuseId = "AlbumCell"

    let imageView = UIImageView()
    let titleLabel = UILabel()
    let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 6
        imageView.backgroundColor = .tertiarySystemFill

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabel

        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(countLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let padding: CGFloat = 6
        let imageSide = contentView.bounds.width
        imageView.frame = CGRect(x: 0, y: 0, width: imageSide, height: imageSide)
        titleLabel.frame = CGRect(x: padding, y: imageView.frame.maxY + 6, width: contentView.bounds.width - padding * 2, height: 18)
        countLabel.frame = CGRect(x: padding, y: titleLabel.frame.maxY + 2, width: contentView.bounds.width - padding * 2, height: 16)
    }
}

