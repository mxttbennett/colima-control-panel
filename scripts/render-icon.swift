// Renders the app icon artwork: three glass orbs with glowing cores, joined by wires.
// Usage: swift scripts/render-icon.swift Resources/AppIcon.icon/Assets/art.png
// Renders the app icon artwork: a glass jellyfish whose tentacles are glowing wires.
// Usage: swift scripts/render-icon.swift Resources/AppIcon.icon/Assets/art.png
import AppKit
import Metal
import SceneKit
import simd

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


func bell(radius R: CGFloat, height H: CGFloat, segments: Int = 72) -> SCNGeometry {
    var profile: [(CGFloat, CGFloat)] = []
    for i in 0...24 { let a = CGFloat(i) / 24 * .pi / 2; profile.append((R * sin(a), H * cos(a))) }
    for i in 1...6 { let t = CGFloat(i) / 6; profile.append((R * (1 - 0.06 * t), -0.2 * H * sin(t * .pi / 2))) }
    for i in 1...20 { let t = CGFloat(i) / 20; profile.append((R * 0.94 * (1 - t), -0.2 * H + 0.55 * H * sin(t * .pi / 2))) }
    var vertices: [SCNVector3] = []
    for (r, y) in profile {
        for j in 0..<segments {
            let phi = CGFloat(j) / CGFloat(segments) * 2 * .pi
            vertices.append(SCNVector3(r * cos(phi), y, r * sin(phi)))
        }
    }
    var indices: [Int32] = []
    for i in 0..<(profile.count - 1) {
        for j in 0..<segments {
            let a = Int32(i * segments + j), b = Int32(i * segments + (j + 1) % segments)
            let c = Int32((i + 1) * segments + j), d = Int32((i + 1) * segments + (j + 1) % segments)
            indices += [a, c, b, b, c, d]
        }
    }
    var normals = [SIMD3<Float>](repeating: .zero, count: vertices.count)
    for t in stride(from: 0, to: indices.count, by: 3) {
        let i0 = Int(indices[t]), i1 = Int(indices[t + 1]), i2 = Int(indices[t + 2])
        func p(_ i: Int) -> SIMD3<Float> { SIMD3(Float(vertices[i].x), Float(vertices[i].y), Float(vertices[i].z)) }
        let n = simd_cross(p(i1) - p(i0), p(i2) - p(i0))
        normals[i0] += n; normals[i1] += n; normals[i2] += n
    }
    let nv = normals.map { n -> SCNVector3 in let u = simd_normalize(n); return SCNVector3(CGFloat(u.x), CGFloat(u.y), CGFloat(u.z)) }
    return SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: nv)], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
}

func tipNode(_ path: [SCNVector3], _ c: NSColor, radius: CGFloat) -> SCNNode {
    let tip = SCNSphere(radius: radius * 1.8); tip.materials = [glowMaterial(c)]
    let n = SCNNode(geometry: tip); n.position = path[path.count - 1]; return n
}

let yellow = color(1, 0.84, 0.04), pink = color(1, 0.37, 0.78), green = color(0.19, 0.82, 0.35), mint = color(0.37, 0.88, 0.82), orange = color(1, 0.62, 0.04)
func v(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> SCNVector3 { SCNVector3(x, y, z) }

let scene = SCNScene()
scene.background.contents = NSColor.clear
scene.lightingEnvironment.contents = studio()
scene.lightingEnvironment.intensity = 1.5

// Five tentacles, each in its own lane with a gentle S, so none cross.
let lanes: [CGFloat] = [-1.0, -0.5, 0, 0.5, 1.0]
let lengths: [CGFloat] = [2.3, 2.7, 3.0, 2.7, 2.3]
let colors = [yellow, pink, green, mint, orange]
let amplitude: CGFloat = 0.18, wireRadius: CGFloat = 0.11

let R: CGFloat = 1.9, H: CGFloat = 1.45
let jelly = SCNNode()
let shell = bell(radius: R, height: H)
let gm = glassMaterial(); gm.diffuse.contents = color(0.62, 0.70, 1.0, 0.24)
shell.materials = [gm]
jelly.addChildNode(SCNNode(geometry: shell))

// A thin bright rim defines the bell's edge.
let rimRing = SCNTorus(ringRadius: R * 0.985, pipeRadius: 0.03)
let rimMat = SCNMaterial(); rimMat.lightingModel = .constant; rimMat.diffuse.contents = color(0.95, 0.97, 1); rimMat.transparency = 0.8; rimRing.materials = [rimMat]
let rimNode = SCNNode(geometry: rimRing); rimNode.position = v(0, -H * 0.08, 0); jelly.addChildNode(rimNode)

// A small soft core inside the dome.
let nucleus = SCNSphere(radius: R * 0.15); nucleus.segmentCount = 48; nucleus.materials = [glowMaterial(color(1.0, 0.85, 0.96))]
let nucleusNode = SCNNode(geometry: nucleus); nucleusNode.position = v(0, H * 0.4, 0); jelly.addChildNode(nucleusNode)

// Each tentacle gets its own lane and a gentle S, so none cross.
let y0 = H * 0.12
for (i, lane) in lanes.enumerated() {
    let length = lengths[i]
    let sign: CGFloat = i % 2 == 0 ? 1 : -1
    var points: [SCNVector3] = []
    for k in 0...6 {
        let t = CGFloat(k) / 6
        let grow = sqrt(t)
        let x = lane * (R / 1.9) * (1 + 0.18 * t) + sign * amplitude * sin(t * .pi * 2.2) * grow
        points.append(v(x, y0 - length * t, 0.15 * sin(t * .pi)))
    }
    jelly.addChildNode(cable(points, colors[i], radius: wireRadius))
    jelly.addChildNode(tipNode(points, colors[i], radius: wireRadius))
}
jelly.eulerAngles = SCNVector3(0.1, 0.0, -0.12)
scene.rootNode.addChildNode(jelly)

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
