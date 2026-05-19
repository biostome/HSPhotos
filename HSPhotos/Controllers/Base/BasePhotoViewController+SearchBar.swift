//
//  BasePhotoViewController extensions
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: SearchBarViewDelegate {
    @objc internal func searchBarView(_ searchBarView: SearchBarView, didSearchWith text: String) {
        performSearch(with: text)
    }

    func searchBarViewDidRemoveToken(_ searchBarView: SearchBarView, tagID: String) {
        filterState.selectedTagIDs.remove(tagID)
        // filterState didSet 会触发 applyTagFilter + syncSearchTokens
    }

    func searchBarViewDidTapFilter(_ searchBarView: SearchBarView) {
        didTapTagFilter()
    }
}

// MARK: - TagFilterPanelDelegate
