//
//  VideoCollectionViewCell.swift
//  ICO-visualizer
//
//  Created by Anonymous on 03/11/21.
//  Copyright © 2021 Anonymous. All rights reserved.
//

import UIKit
import SDWebImage

class VideoCollectionViewCell: FullWidthCollectionViewCell {
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backgroundCellView: UIView!
    @IBOutlet weak var viewsLabel: UILabel!
    @IBOutlet weak var starLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var bookmarkIcon: UIImageView!
    
    let gradient: CAGradientLayer = {
        return CAGradientLayer()
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundCellView.applyCardStyle(cornerRadius: 28)
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 20
        thumbImageView.layer.cornerCurve = .continuous
        gradientView.isHidden = true
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        starLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        starLabel.textColor = ColorLayout.default_orange
        viewsLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        viewsLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        durationLabel.textColor = .white
        Glass.attachBadge(behind: durationLabel, in: backgroundCellView)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func setup(video: Video){
        if let thumbUrl = video.thumb{
            thumbImageView.sd_setImage(with: URL(string: thumbUrl)!, completed: nil)
        }
        titleLabel.text = video.title
        viewsLabel.text = ""
        var viewsText = ""
        if let views = video.views {
            viewsText += "\(Double(views).shortStringRepresentation) Views"
        }
        if let rating = video.rating?.ratingString, let ratingDouble = Double(rating) {
            viewsText += " | \(String(format: "%.0f", ratingDouble))%"
        }
        self.viewsLabel.text = viewsText
        self.starLabel.text = video.pornstars?.first?.pornstarName ?? ""
        self.durationLabel.text = video.duration ?? ""
        bookmarkIcon.isHidden = !UserBookmakrs.shared.checkVideoBookmarksCointain(video)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.gradient.frame = self.gradientView.bounds
            self.gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]

            self.gradientView.layer.insertSublayer(self.gradient, at: 0)
        }
    }
}
