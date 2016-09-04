//
//  CollectionViewCell.swift
//  PhotoPicker
//
//  Created by mariano latorre on 04/09/2016.
//  Copyright © 2016 Russell Austin. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    override func awakeFromNib() {
        self.layer.borderColor = UIColor.blackColor().CGColor
        self.layer.borderWidth = 1
        self.layer.cornerRadius = 30
    }
}
