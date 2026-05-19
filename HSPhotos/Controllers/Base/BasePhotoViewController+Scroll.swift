//
//  BasePhotoViewController extensions
//

import UIKit
import Photos
import PhotosUI

extension BasePhotoViewController: UIScrollViewDelegate {
    @objc internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else { return }
        let currentOffsetY = scrollView.contentOffset.y
        let offsetDifference = currentOffsetY - lastContentOffsetY

        let shouldShow = offsetDifference > 0 && currentOffsetY > 0
        if shouldShow != isSearchBarVisible {
            isSearchBarVisible = shouldShow
            if shouldShow {
                moveSearchBarToVisible()
            } else {
                moveSearchBarToHidden()
            }
        }
        lastContentOffsetY = currentOffsetY
    }

    private func moveSearchBarToVisible() {
        searchTextField.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.searchTextField.transform = .identity
            self.searchTextField.alpha = 1.0
        }
    }

    private func moveSearchBarToHidden() {
        let searchBarHeight = searchTextField.frame.height + 8
        UIView.animate(withDuration: 0.3, animations: {
            self.searchTextField.transform = CGAffineTransform(translationX: 0, y: -searchBarHeight)
            self.searchTextField.alpha = 0.0
        }, completion: { _ in
            self.searchTextField.isHidden = true
        })
    }
}
