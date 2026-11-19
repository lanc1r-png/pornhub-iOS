//
//  NavigationButtonViewController.swift
//  ICO-visualizer
//
//  Created by Anonymous on 28/09/21.
//

import UIKit

class NavigationButtonCollectionViewCell: FullWidthCollectionViewCell {
    @IBOutlet weak var tapView: UIView!
    @IBOutlet weak var titleView: UILabel!
    
    private var tapAction: (() -> Void)?
    
    func setup(title: String, onTap: (() -> Void)?){
        tapView.applyCardStyle(cornerRadius: 22)
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 20
        style.headIndent = 20
        self.titleView.attributedText = NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: ColorLayout.default_text,
            .paragraphStyle: style
        ])
        tapView.subviews.compactMap { $0 as? UIImageView }.first?.transform = CGAffineTransform(translationX: -18, y: 0)
        self.tapAction = onTap
        tapView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tapView.addGestureRecognizer(tap)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        self.tapAction?()
    }
}
