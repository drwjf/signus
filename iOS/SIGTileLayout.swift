//
//  SIGTileLayout.swift
//  SIG
//
//

import UIKit
import YUSKit

final class SIGTileLayout: YUSTileLayout, YUSTileLayoutHitTest {
    private let bridge: SIGPlayBridge

    var zoomedTileWidth: CGFloat {
        tileWidth * zoom
    }

    var zoomedTileHeight: CGFloat {
        tileHeight * zoom
    }

    var zoomedMapTopInset: CGFloat {
        bridge.mapTopInset(tileHeight: tileHeight) * zoom
    }

    var zoomedMapHorizontalInset: CGFloat {
        bridge.mapHorizontalInset(tileWidth: tileWidth) * zoom
    }

    var zoomedMapBottomInset: CGFloat {
        bridge.mapBottomInset(tileHeight: tileHeight) * zoom
    }

    init(bridge: SIGPlayBridge) {
        self.bridge = bridge
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SIGTileLayout does not support storyboard initialization")
    }

    override func rect(of indexPath: IndexPath) -> CGRect {
        let unzoomedRect = bridge.tileRect(
            atX: indexPath.row,
            y: indexPath.section,
            tileWidth: tileWidth,
            tileHeight: tileHeight
        )
        return unzoomedRect.applying(zoomTransform)
    }

    override var collectionViewContentSize: CGSize {
        var size = super.collectionViewContentSize
        size.width += zoomedMapHorizontalInset
        size.height += zoomedMapBottomInset
        return size
    }

    /// Visits only the tiles whose isometric position can reach `rect`, instead of filtering every
    /// cached tile on each scroll step. Mirrors `SIGPlayBridge.tileRect`: a tile's unzoomed origin is
    /// `x = inset + (mapY + x - y) * w / 2` and `y = top + (x + y - height) * h / 2` with height 0...7.
    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        guard mapX > 0, mapY > 0, tileWidth > 0, tileHeight > 0, zoom > 0,
              !rect.isNull, !rect.isInfinite else {
            let attributes = super.layoutAttributesForElements(in: rect)
            attributes?.forEach { $0.zIndex = depthIndex(for: $0.indexPath) }
            return attributes
        }
        let area = CGRect(x: rect.minX / zoom, y: rect.minY / zoom,
                          width: rect.width / zoom, height: rect.height / zoom)
        let inset = bridge.mapHorizontalInset(tileWidth: tileWidth)
        let top = bridge.mapTopInset(tileHeight: tileHeight)
        let maximumHeight = 7
        // Tile x - y: the frame's minX lies in [area.minX - tileWidth, area.maxX].
        let lowestX: CGFloat = (area.minX - tileWidth - inset) * 2 / tileWidth
        let highestX: CGFloat = (area.maxX - inset) * 2 / tileWidth
        let minimumDifference = max(Int(lowestX.rounded(.down)) - mapY - 1, 1 - mapY)
        let maximumDifference = min(Int(highestX.rounded(.up)) - mapY + 1, mapX - 1)
        // Tile x + y: the frame's minY lies in [area.minY - tileHeight, area.maxY], raised by height 0...7.
        let lowestY: CGFloat = (area.minY - tileHeight - top) * 2 / tileHeight
        let highestY: CGFloat = (area.maxY - top) * 2 / tileHeight
        let minimumSum = max(Int(lowestY.rounded(.down)) - 1, 0)
        let maximumSum = min(Int(highestY.rounded(.up)) + maximumHeight + 1, mapX + mapY - 2)
        guard minimumDifference <= maximumDifference, minimumSum <= maximumSum else { return [] }

        var attributes: [UICollectionViewLayoutAttributes] = []
        for tileSum in minimumSum...maximumSum {
            for tileDifference in minimumDifference...maximumDifference
            where (tileSum + tileDifference) % 2 == 0 {
                let x = (tileSum + tileDifference) / 2
                let y = (tileSum - tileDifference) / 2
                guard x >= 0, y >= 0, x < mapX, y < mapY,
                      let attribute = super.layoutAttributesForItem(at: IndexPath(item: x, section: y)),
                      attribute.frame.intersects(rect) else { continue }
                attribute.zIndex = depthIndex(for: attribute.indexPath)
                attributes.append(attribute)
            }
        }
        return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.layoutAttributesForItem(at: indexPath)
        attributes?.zIndex = depthIndex(for: indexPath)
        return attributes
    }

    func indexPath(at point: CGPoint) -> IndexPath? {
        let unzoomedPoint = CGPoint(x: point.x / zoom, y: point.y / zoom)
        if let aircraft = bridge.aircraftIndexPath(
            at: unzoomedPoint,
            tileWidth: tileWidth,
            tileHeight: tileHeight
        ) {
            return aircraft
        }
        let radius = zoomedTileWidth / 2
        let searchRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let matches = layoutAttributesForElements(in: searchRect)?.filter { attribute in
            attribute.representedElementCategory == .cell &&
                attribute.frame.contains(point) &&
                pointIsInsideDiamond(point, rect: attribute.frame)
        }
        return matches?.max { $0.zIndex < $1.zIndex }?.indexPath
    }

    private func depthIndex(for indexPath: IndexPath) -> Int {
        (indexPath.row + indexPath.section) * max(mapX, 1) + indexPath.row
    }

    private var zoomTransform: CGAffineTransform {
        CGAffineTransform(scaleX: zoom, y: zoom)
    }

    private func pointIsInsideDiamond(_ point: CGPoint, rect: CGRect) -> Bool {
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        guard radiusX > 0, radiusY > 0 else { return false }
        let normalizedX = abs(point.x - rect.midX) / radiusX
        let normalizedY = abs(point.y - rect.midY) / radiusY
        return normalizedX + normalizedY <= 1
    }
}
