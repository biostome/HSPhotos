//
//  BasePhotoViewController extensions
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: TagFilterPanelDelegate {
    func tagFilterPanel(_ panel: TagFilterPanelViewController, didApply state: TagFilterState) {
        filterState = state
    }
}

// MARK: - UIScrollViewDelegate
