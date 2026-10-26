// Renders the app icon artwork: three glass orbs with glowing cores, joined by wires.
// Usage: swift scripts/render-icon.swift Resources/AppIcon.icon/Assets/art.png
import AppKit
import Metal
import SceneKit

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }

// Soft boxes and a gradient give the glass something to reflect.
func studio() -> NSImage {
    let size = NSSize(width: 2048, height: 1024)
    let image = NSImage(size: size)
    image.lockFocus()
    NSGradient(colors: [color(0.16, 0.18, 0.47), color(0.52, 0.57, 0.96), color(0.95, 0.95, 1.0)], atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!.draw(in: NSRect(origin: .zero, size: size), angle: 90)
    NSColor.white.setFill()
    for rect in [NSRect(x: 300, y: 560, width: 380, height: 220), NSRect(x: 1250, y: 620, width: 520, height: 180), NSRect(x: 800, y: 300, width: 160, height: 300)] {
        NSBezierPath(roundedRect: rect, xRadius: 40, yRadius: 40).fill()
    }
    image.unlockFocus()
    return image
}

func spot() -> NSImage {
    let image = NSImage(size: NSSize(width: 256, height: 256))
    image.lockFocus()
    NSGradient(colors: [NSColor(white: 1, alpha: 0.9), NSColor(white: 1, alpha: 0)], atLocations: [0, 1], colorSpace: .deviceRGB)!
        .draw(fromCenter: NSPoint(x: 128, y: 128), radius: 0, toCenter: NSPoint(x: 128, y: 128), radius: 128, options: [])
    image.unlockFocus()
    return image
}

func glassMaterial() -> SCNMaterial {
    let m = SCNMaterial()
    m.isDoubleSided = true
    m.writesToDepthBuffer = false
    m.transparencyMode = .aOne
    m.lightingModel = .physicallyBased
    m.diffuse.contents = color(0.60, 0.66, 1.0, 0.20)
    m.metalness.contents = 0.0
    m.roughness.contents = 0.05
    return m
}

func glowMaterial(_ c: NSColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = c
    m.emission.contents = c
    m.emission.intensity = 1.1
    m.metalness.contents = 0.0
    m.roughness.contents = 0.25
    return m
}

/// A smooth curve through the control points, built from overlapping spheres.
func cable(_ control: [SCNVector3], _ c: NSColor, radius: CGFloat) -> SCNNode {
    let pts = [control[0]] + control + [control[control.count - 1]]
    var path: [SCNVector3] = []
    for i in 1..<(pts.count - 2) {
        for s in 0..<64 {
            let t = CGFloat(s) / 64, t2 = t * t, t3 = t2 * t
            func f(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat { 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3) }
            path.append(SCNVector3(f(pts[i-1].x, pts[i].x, pts[i+1].x, pts[i+2].x), f(pts[i-1].y, pts[i].y, pts[i+1].y, pts[i+2].y), f(pts[i-1].z, pts[i].z, pts[i+1].z, pts[i+2].z)))
        }
    }
    path.append(control[control.count - 1])
    let node = SCNNode()
    let material = glowMaterial(c)
    for point in path {
        let s = SCNSphere(radius: radius); s.segmentCount = 16; s.materials = [material]
        let n = SCNNode(geometry: s); n.position = point; node.addChildNode(n)
    }
    return node
}

func orb(_ r: CGFloat, at p: SCNVector3, core: NSColor) -> SCNNode {
    let root = SCNNode(); root.position = p
    let sphere = SCNSphere(radius: r); sphere.segmentCount = 96; sphere.materials = [glassMaterial()]
    root.addChildNode(SCNNode(geometry: sphere))
    let ring = SCNTorus(ringRadius: r, pipeRadius: 0.022)
    let rm = SCNMaterial(); rm.lightingModel = .constant; rm.diffuse.contents = color(0.95, 0.95, 1); rm.transparency = 0.75
    ring.materials = [rm]
    let rn = SCNNode(geometry: ring); rn.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0); root.addChildNode(rn)
    let blob = SCNPlane(width: r * 0.95, height: r * 0.62)
    let bm = SCNMaterial(); bm.lightingModel = .constant; bm.diffuse.contents = spot(); bm.transparency = 0.7; bm.isDoubleSided = true
    blob.materials = [bm]
    let bn = SCNNode(geometry: blob); bn.position = SCNVector3(-r * 0.42, r * 0.5, r * 0.97); bn.eulerAngles = SCNVector3(0, 0, 0.6); root.addChildNode(bn)
    let nucleus = SCNSphere(radius: r * 0.3); nucleus.segmentCount = 48; nucleus.materials = [glowMaterial(core)]
    root.addChildNode(SCNNode(geometry: nucleus))
    return root
}

let yellow = color(1, 0.84, 0.04), pink = color(1, 0.37, 0.78), green = color(0.19, 0.82, 0.35), mint = color(0.37, 0.88, 0.82)
func v(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> SCNVector3 { SCNVector3(x, y, z) }

let scene = SCNScene()
scene.background.contents = NSColor.clear
scene.lightingEnvironment.contents = studio()
scene.lightingEnvironment.intensity = 1.5

let T = v(0.1, 1.5, 0), L = v(-1.6, -0.95, 0.2), R = v(1.65, -0.75, -0.2)
scene.rootNode.addChildNode(orb(1.2, at: T, core: yellow))
scene.rootNode.addChildNode(orb(1.35, at: L, core: mint))
scene.rootNode.addChildNode(orb(1.15, at: R, core: pink))
scene.rootNode.addChildNode(cable([T, v(-0.8, 2.1, 1.2), v(-1.8, 1.8, 1.5), v(-2.6, 0.9, 1.5), v(-2.1, 0.2, 1.3), v(-2.7, -0.3, 1.1), L], yellow, radius: 0.1))
scene.rootNode.addChildNode(cable([T, v(1.0, 2.2, 1.2), v(2.0, 1.9, 1.5), v(2.8, 1.1, 1.5), v(2.3, 0.4, 1.3), v(2.9, -0.1, 1.1), R], pink, radius: 0.1))
scene.rootNode.addChildNode(cable([L, v(-1.2, -2.1, 1.0), v(-0.5, -2.7, 1.4), v(0.3, -2.0, 1.6), v(1.0, -2.8, 1.4), v(1.9, -2.1, 1.0), R], green, radius: 0.1))

let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional; key.light!.intensity = 900; key.eulerAngles = SCNVector3(-0.7, 0.5, 0)
scene.rootNode.addChildNode(key)
let cam = SCNNode(); cam.camera = SCNCamera()
cam.camera!.fieldOfView = 34; cam.camera!.wantsHDR = true
cam.camera!.bloomIntensity = 0.55; cam.camera!.bloomThreshold = 0.9; cam.camera!.bloomBlurRadius = 10
cam.position = v(0, 0.25, 13); scene.rootNode.addChildNode(cam)

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice()!, options: nil)
renderer.scene = scene; renderer.pointOfView = cam
let big = renderer.snapshot(atTime: 0, with: CGSize(width: 1800, height: 1800), antialiasingMode: .multisampling4X)
let src = NSBitmapImageRep(data: big.tiffRepresentation!)!

// Measure the artwork and fit it into a safe area so nothing clips at the tile edge.
var minX = src.pixelsWide, minY = src.pixelsHigh, maxX = 0, maxY = 0
for y in stride(from: 0, to: src.pixelsHigh, by: 2) {
    for x in stride(from: 0, to: src.pixelsWide, by: 2) where (src.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.04 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let scale = 700 / max(crop.width, crop.height)
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
let w = crop.width * scale, h = crop.height * scale
NSGraphicsContext.current!.cgContext.draw(src.cgImage!.cropping(to: crop)!, in: CGRect(x: (1024 - w) / 2, y: (1024 - h) / 2, width: w, height: h))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
