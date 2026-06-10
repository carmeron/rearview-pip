import Foundation
import UIKit

/// Renders parking guide line overlays as CAShapeLayer instances.
final class GuideLineRenderer {
    /// Whether the guide lines are currently visible
    private(set) var isVisible: Bool = true

    /// Current guide line style
    private(set) var currentStyle: GuideLineStyle = .standard

    /// The layer containing all guide line paths
    private let containerLayer = CAShapeLayer()

    /// Guide line color
    var lineColor: UIColor = .green {
        didSet { containerLayer.strokeColor = lineColor.cgColor }
    }

    /// Guide line width
    var lineWidth: CGFloat = 2.0 {
        didSet { containerLayer.lineWidth = lineWidth }
    }

    init() {
        containerLayer.fillColor = UIColor.clear.cgColor
        containerLayer.strokeColor = lineColor.cgColor
        containerLayer.lineWidth = lineWidth
        containerLayer.opacity = 0.8
    }

    // MARK: - Public API

    /// Create a CAShapeLayer containing guide lines for the given style and frame size.
    /// - Parameters:
    ///   - style: The guide line style
    ///   - frameSize: The size of the video frame to draw within
    /// - Returns: A CAShapeLayer ready to be added to a view hierarchy
    func createGuideLines(style: GuideLineStyle, frameSize: CGSize) -> CAShapeLayer {
        currentStyle = style

        let path = UIBezierPath()
        let width = frameSize.width
        let height = frameSize.height

        switch style {
        case .standard:
            drawStandardLines(path: path, width: width, height: height)
        case .wide:
            drawWideLines(path: path, width: width, height: height)
        case .parking:
            drawParkingLines(path: path, width: width, height: height)
        }

        containerLayer.path = path.cgPath
        containerLayer.frame = CGRect(origin: .zero, size: frameSize)

        return containerLayer
    }

    /// Update the guide line style and redraw.
    func updateStyle(_ style: GuideLineStyle) {
        currentStyle = style
        // The path will be redrawn on next createGuideLines call with the current frame size
    }

    /// Show or hide guide lines.
    func setVisible(_ visible: Bool) {
        isVisible = visible
        containerLayer.isHidden = !visible
    }

    // MARK: - Private Drawing Methods

    /// Standard trajectory lines: two side lines converging toward center, with distance markers.
    private func drawStandardLines(path: UIBezierPath, width: CGFloat, height: CGFloat) {
        let centerX = width / 2
        let carWidth: CGFloat = width * 0.5  // Car width representation

        // Left trajectory line — starts from bottom-left, angles toward center-top
        let leftStart = CGPoint(x: centerX - carWidth / 2, y: height)
        let leftEnd = CGPoint(x: centerX - carWidth / 6, y: height * 0.1)

        path.move(to: leftStart)
        path.addLine(to: leftEnd)

        // Right trajectory line — starts from bottom-right, angles toward center-top
        let rightStart = CGPoint(x: centerX + carWidth / 2, y: height)
        let rightEnd = CGPoint(x: centerX + carWidth / 6, y: height * 0.1)

        path.move(to: rightStart)
        path.addLine(to: rightEnd)

        // Horizontal distance markers
        let markerPositions: [CGFloat] = [0.25, 0.5, 0.75]  // Fractional positions from bottom
        for fraction in markerPositions {
            let y = height * (1 - fraction)
            let markerWidth = carWidth / 2 + (carWidth / 6 - carWidth / 2) * (1 - fraction)

            let markerLeft = CGPoint(x: centerX - markerWidth, y: y)
            let markerRight = CGPoint(x: centerX + markerWidth, y: y)

            path.move(to: markerLeft)
            path.addLine(to: markerRight)
        }

        // Center vertical guideline
        path.move(to: CGPoint(x: centerX, y: height))
        path.addLine(to: CGPoint(x: centerX, y: height * 0.1))
    }

    /// Wide-body vehicle lines: wider spacing to represent a larger vehicle.
    private func drawWideLines(path: UIBezierPath, width: CGFloat, height: CGFloat) {
        let centerX = width / 2
        let carWidth: CGFloat = width * 0.7  // Wider vehicle representation

        // Left wide line
        let leftStart = CGPoint(x: centerX - carWidth / 2, y: height)
        let leftMid = CGPoint(x: centerX - carWidth / 3, y: height * 0.3)
        let leftEnd = CGPoint(x: centerX - carWidth / 8, y: height * 0.1)

        path.move(to: leftStart)
        path.addLine(to: leftMid)
        path.addLine(to: leftEnd)

        // Right wide line
        let rightStart = CGPoint(x: centerX + carWidth / 2, y: height)
        let rightMid = CGPoint(x: centerX + carWidth / 3, y: height * 0.3)
        let rightEnd = CGPoint(x: centerX + carWidth / 8, y: height * 0.1)

        path.move(to: rightStart)
        path.addLine(to: rightMid)
        path.addLine(to: rightEnd)

        // Extended boundary lines at the sides
        // Left boundary
        path.move(to: CGPoint(x: centerX - carWidth / 2, y: height))
        path.addLine(to: CGPoint(x: centerX - carWidth / 2, y: height * 0.3))

        // Right boundary
        path.move(to: CGPoint(x: centerX + carWidth / 2, y: height))
        path.addLine(to: CGPoint(x: centerX + carWidth / 2, y: height * 0.3))

        // Distance markers
        for fraction in stride(from: 0.25, through: 0.75, by: 0.25) {
            let y = height * (1 - CGFloat(fraction))
            let t = CGFloat(fraction)
            let markerWidth = carWidth / 2 * (1 - t * 0.7)
            path.move(to: CGPoint(x: centerX - markerWidth, y: y))
            path.addLine(to: CGPoint(x: centerX + markerWidth, y: y))
        }

        // Center line
        path.move(to: CGPoint(x: centerX, y: height))
        path.addLine(to: CGPoint(x: centerX, y: height * 0.1))
    }

    /// Parking spot alignment lines: box-like guides for parking spaces.
    private func drawParkingLines(path: UIBezierPath, width: CGFloat, height: CGFloat) {
        let centerX = width / 2
        let spotWidth: CGFloat = width * 0.55
        let spotHeight: CGFloat = height * 0.7
        let spotTop = height * 0.15
        let spotLeft = centerX - spotWidth / 2

        // Parking spot rectangle (open at the bottom)
        // Top edge
        path.move(to: CGPoint(x: spotLeft, y: spotTop))
        path.addLine(to: CGPoint(x: spotLeft + spotWidth, y: spotTop))

        // Left edge
        path.move(to: CGPoint(x: spotLeft, y: spotTop))
        path.addLine(to: CGPoint(x: spotLeft, y: spotTop + spotHeight))

        // Right edge
        path.move(to: CGPoint(x: spotLeft + spotWidth, y: spotTop))
        path.addLine(to: CGPoint(x: spotLeft + spotWidth, y: spotTop + spotHeight))

        // Bottom corner markers (angled)
        let cornerLength: CGFloat = 30
        // Left corner
        path.move(to: CGPoint(x: spotLeft, y: spotTop + spotHeight - cornerLength))
        path.addLine(to: CGPoint(x: spotLeft, y: spotTop + spotHeight))
        path.addLine(to: CGPoint(x: spotLeft + cornerLength, y: spotTop + spotHeight))

        // Right corner
        path.move(to: CGPoint(x: spotLeft + spotWidth, y: spotTop + spotHeight - cornerLength))
        path.addLine(to: CGPoint(x: spotLeft + spotWidth, y: spotTop + spotHeight))
        path.addLine(to: CGPoint(x: spotLeft + spotWidth - cornerLength, y: spotTop + spotHeight))

        // Center guide line (dashed effect via short segments)
        let dashLength: CGFloat = 20
        let gapLength: CGFloat = 15
        var dashY = spotTop + spotHeight
        path.move(to: CGPoint(x: centerX, y: dashY))
        while dashY > spotTop {
            let segmentEnd = max(dashY - dashLength, spotTop)
            path.addLine(to: CGPoint(x: centerX, y: segmentEnd))
            dashY = segmentEnd - gapLength
            if dashY > spotTop {
                path.move(to: CGPoint(x: centerX, y: dashY))
            }
        }

        // Side reference marks at mid-height
        let midY = spotTop + spotHeight / 2
        path.move(to: CGPoint(x: spotLeft, y: midY))
        path.addLine(to: CGPoint(x: spotLeft + 15, y: midY))
        path.move(to: CGPoint(x: spotLeft + spotWidth, y: midY))
        path.addLine(to: CGPoint(x: spotLeft + spotWidth - 15, y: midY))
    }
}
