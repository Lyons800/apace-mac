import ApaceClients
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension ScreenCaptureClient {
    /// Captures the main display and returns downscaled PNG data. Needs the Screen
    /// Recording permission; returns nil until it's granted (or if capture fails).
    /// Downscaled so the screenshot doesn't blow up the vision model's token count.
    public static let live = ScreenCaptureClient {
        guard let full = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }
        let image = downscaled(full, maxWidth: 1536) ?? full
        return png(from: image)
    }

    private static func downscaled(_ image: CGImage, maxWidth: Int) -> CGImage? {
        guard image.width > maxWidth else { return image }
        let scale = Double(maxWidth) / Double(image.width)
        let width = maxWidth
        let height = Int(Double(image.height) * scale)
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func png(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
