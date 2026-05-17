import CoreImage
import CoreGraphics

enum QRCodeGenerator {
    static func generate(from urlString: String) -> CGImage? {
        guard !urlString.isEmpty else { return nil }
        guard let data = urlString.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale: CGFloat = 10
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        return context.createCGImage(scaled, from: scaled.extent)
    }
}
