// Renders the app icon artwork: an octopus with eight outward-curling arms, a dotted row of suckers on each, and a small smile.
// Usage: swift scripts/render-icon.swift Resources/AppIcon.icon/Assets/art.png
import AppKit

guard CommandLine.arguments.count > 1 else { fatalError("usage: render-icon.swift <output.png>") }

let side = 1024
let navy = CGColor(srgbRed: 0x14 / 255, green: 0x31 / 255, blue: 0x6B / 255, alpha: 1)
let pale = CGColor(srgbRed: 0xDC / 255, green: 0xE8 / 255, blue: 0xFF / 255, alpha: 1)

guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }

// Work in a y-down space so the coordinates read like the design sketches, and leave a margin inside the icon shape.
context.translateBy(x: 0, y: CGFloat(side))
context.scaleBy(x: 1, y: -1)
context.translateBy(x: 512, y: 512)
context.scaleBy(x: 0.9, y: 0.9)
context.translateBy(x: -512, y: -512)

let arm = CGMutablePath()
arm.move(to: CGPoint(x: 512, y: 440))
arm.addCurve(to: CGPoint(x: 520, y: 220), control1: CGPoint(x: 470, y: 360), control2: CGPoint(x: 560, y: 290))
arm.addCurve(to: CGPoint(x: 585, y: 150), control1: CGPoint(x: 495, y: 170), control2: CGPoint(x: 540, y: 120))

context.setLineCap(.round)
context.setLineJoin(.round)

for index in 0..<8 {
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: CGFloat(index) * .pi / 4)
    context.translateBy(x: -512, y: -512)

    context.setStrokeColor(navy)
    context.setLineWidth(44)
    context.addPath(arm)
    context.strokePath()

    context.saveGState()
    context.translateBy(x: -9, y: 0)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
    context.setLineWidth(7)
    context.setLineDash(phase: 0, lengths: [150, 70])
    context.addPath(arm)
    context.strokePath()
    context.restoreGState()

    context.setStrokeColor(pale.copy(alpha: 0.55)!)
    context.setLineWidth(12)
    context.setLineDash(phase: 0, lengths: [1, 46])
    context.addPath(arm)
    context.strokePath()
    context.restoreGState()
}

context.setFillColor(navy)
context.fillEllipse(in: CGRect(x: 512 - 128, y: 512 - 128, width: 256, height: 256))

context.setFillColor(pale)
for x in [468.0, 556.0] { context.fillEllipse(in: CGRect(x: x - 20, y: 502 - 20, width: 40, height: 40)) }

let smile = CGMutablePath()
smile.move(to: CGPoint(x: 474, y: 544))
smile.addQuadCurve(to: CGPoint(x: 550, y: 544), control: CGPoint(x: 512, y: 582))
context.setStrokeColor(pale)
context.setLineWidth(10)
context.setLineDash(phase: 0, lengths: [])
context.addPath(smile)
context.strokePath()

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else { fatalError("could not encode the image") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
