import UIKit
import ObjectiveC

extension UICollectionView {
    var isEditing: Bool {
        get { return (objc_getAssociatedObject(self, &AssocKey.editing) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &AssocKey.editing, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private enum AssocKey {
    static var editing: UInt8 = 0
}

