import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let master = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(master as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    throw CocoaError(.fileReadCorruptFile)
}

func icnsChunk(_ type: String, _ payload: Data) -> Data {
    var chunk = Data(type.utf8)
    var length = UInt32(payload.count + 8).bigEndian
    withUnsafeBytes(of: &length) { chunk.append(contentsOf: $0) }
    chunk.append(payload)
    return chunk
}

// ICNS stores PNGs under distinct four-character types for standard and Retina sizes.
let representations = [
    ("icp4", 16), ("icp5", 32), ("ic07", 128), ("ic08", 256), ("ic09", 512),
    ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512), ("ic10", 1024),
]
var contents = Data()
for (type, pixels) in representations {
 let unit = CGFloat(pixels) / 1024
 // Classic ICNS art includes its own tile. Native appearance layers are full bleed.
 let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
 let radius = 184 * unit
 let png = NSMutableData()
 guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                               bytesPerRow: pixels * 4, space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
       let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
     throw CocoaError(.fileWriteUnknown)
 }
 context.interpolationQuality = .high
 context.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
 context.clip()
 context.draw(image, in: tile)
 guard let rendered = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
 CGImageDestinationAddImage(destination, rendered, nil)
 guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
 contents.append(icnsChunk(type, png as Data))
}
try icnsChunk("icns", contents).write(to: output, options: .atomic)
