//
//  StarCollectionViewCell.swift
//  ICO-visualizer
//
//  Created by Anonymous on 03/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import UIKit
import SDWebImage

class StarCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backgroundCellView: UIView!
    @IBOutlet weak var bookmarkIcon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundCellView.applyCardStyle(cornerRadius: 28)
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 22
        thumbImageView.layer.cornerCurve = .continuous
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }

    func setup(star: Star){
        if let thumbUrl = star.starThumb, let url = URL(string: thumbUrl) {
            thumbImageView.sd_setImage(with: url, placeholderImage: nil, options: [.retryFailed, .scaleDownLargeImages], completed: nil)
        } else {
            thumbImageView.sd_cancelCurrentImageLoad()
            thumbImageView.image = nil
        }
        titleLabel.text = star.starName
        bookmarkIcon.isHidden = !UserBookmakrs.shared.checkStarBookmarksCointain(star)
    }
}
