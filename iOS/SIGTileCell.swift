//
//  SIGTileCell.swift
//  SIG
//
//

import QuartzCore
import UIKit

final class SIGTileCell: UICollectionViewCell {
    private let solidLayer = CALayer()
    private let transparentLayer = CALayer()
    private let selectionLayer = CALayer()
    private var snapshot: SIGTileSnapshot?
    private var zoom: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        [solidLayer, transparentLayer, selectionLayer].forEach(contentView.layer.addSublayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SIGTileCell does not support storyboard initialization")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applySnapshot()
    }

    func configure(with snapshot: SIGTileSnapshot, zoom: CGFloat) {
        self.snapshot = snapshot
        self.zoom = zoom
        applySnapshot()
    }

    private func applySnapshot() {
        guard let snapshot else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solidLayer.contents = snapshot.solidImage?.cgImage
        solidLayer.frame = snapshot.solidFrame.applying(zoomTransform)
        transparentLayer.contents = snapshot.transparentImage?.cgImage
        transparentLayer.frame = snapshot.transparentFrame.applying(zoomTransform)
        selectionLayer.contents = snapshot.selectionImage?.cgImage
        selectionLayer.frame = snapshot.selectionFrame.applying(zoomTransform)
        CATransaction.commit()
    }

    private var zoomTransform: CGAffineTransform {
        CGAffineTransform(scaleX: zoom, y: zoom)
    }
}
