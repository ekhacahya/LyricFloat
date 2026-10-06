import CoreGraphics
import Foundation

public enum WindowAnchor: String {
    case topLeft, topRight, bottomLeft, bottomRight

    public static func nearest(to frame: CGRect, on screen: CGRect) -> WindowAnchor {
        let right = abs(screen.maxX - frame.maxX) < abs(frame.minX - screen.minX)
        let bottom = abs(frame.minY - screen.minY) < abs(screen.maxY - frame.maxY)
        if bottom { return right ? .bottomRight : .bottomLeft }
        return right ? .topRight : .topLeft
    }

    public func resized(_ frame: CGRect, to size: CGSize, within screen: CGRect?) -> CGRect {
        let right = self == .topRight || self == .bottomRight
        let bottom = self == .bottomLeft || self == .bottomRight
        var result = CGRect(x: right ? frame.maxX - size.width : frame.minX,
                            y: bottom ? frame.minY : frame.maxY - size.height,
                            width: size.width, height: size.height)
        if let screen {
            result.origin.x = max(screen.minX, min(result.minX, screen.maxX - size.width))
            result.origin.y = max(screen.minY, min(result.minY, screen.maxY - size.height))
        }
        return result
    }
}
