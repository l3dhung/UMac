// Vẽ icon UMac bằng vector và xuất Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift            → Resources/AppIcon.icns
//   swift scripts/make-icon.swift <out.png>  → chỉ xuất ảnh 1024px để xem trước
//
// Thiết kế: chữ "U" có cánh phải vươn thành mũi tên đi lên ("U" + nâng cấp),
// trên khuôn squircle chuẩn macOS, tông tím–xanh lơ kế thừa từ HyperMac.
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// Squircle (siêu elip n = 5) gần giống khuôn icon của macOS: 824px giữa canvas 1024px.
func squircle(in rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = cy + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// Ngôi sao 4 cánh nhỏ (điểm nhấn "bóng loáng / dọn sạch").
func sparkle(center c: CGPoint, radius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let inner = r * 0.22
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 - .pi / 2
        let len = i % 2 == 0 ? r : inner
        let p = CGPoint(x: c.x + cos(angle) * len, y: c.y + sin(angle) * len)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

/// Glyph "U↑" dạng nét dày (toạ độ gốc trên-trái, canvas 1024): thân chữ U và mũi tên
/// là hai hình riêng, tô riêng để chỗ chồng nhau không bị trừ thành lỗ.
func glyphParts() -> [CGPath] {
    let stroke: CGFloat = 112
    let leftX: CGFloat = 362, rightX: CGFloat = 662
    let topY: CGFloat = 352, armTopY: CGFloat = 420
    let bowlCenterY: CGFloat = 572
    let radius = (rightX - leftX) / 2

    let spine = CGMutablePath()
    spine.move(to: CGPoint(x: leftX, y: topY))
    spine.addLine(to: CGPoint(x: leftX, y: bowlCenterY))
    spine.addArc(center: CGPoint(x: (leftX + rightX) / 2, y: bowlCenterY), radius: radius,
                 startAngle: .pi, endAngle: 0, clockwise: true)
    spine.addLine(to: CGPoint(x: rightX, y: armTopY))
    let body = spine.copy(strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 10)

    // Mũi tên ở đầu cánh phải.
    let head = CGMutablePath()
    let tipY: CGFloat = 226, baseY: CGFloat = 446, halfWidth: CGFloat = 132
    head.move(to: CGPoint(x: rightX, y: tipY))
    head.addLine(to: CGPoint(x: rightX + halfWidth, y: baseY))
    head.addQuadCurve(to: CGPoint(x: rightX - halfWidth, y: baseY), control: CGPoint(x: rightX, y: baseY - 34))
    head.closeSubpath()

    return [body, head]
}

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(size) / canvas
    // Toạ độ thiết kế: gốc trên-trái, đơn vị = canvas 1024.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(in: tile)
    let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

    // 1. Bóng đổ
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: color(0x000000, 0.38))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x161A45))
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Nền: gradient chéo indigo → xanh đêm, cộng hai quầng sáng
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let base = CGGradient(colorsSpace: rgb, colors: [color(0x5B3FF8), color(0x2A2398), color(0x0C1236)] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: 180, y: 120), end: CGPoint(x: 860, y: 930), options: [])
    let cyanGlow = CGGradient(colorsSpace: rgb, colors: [color(0x22D3EE, 0.55), color(0x22D3EE, 0)] as CFArray,
                              locations: [0, 1])!
    ctx.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: 770, y: 800), startRadius: 0,
                           endCenter: CGPoint(x: 770, y: 800), endRadius: 470, options: [])
    let magentaGlow = CGGradient(colorsSpace: rgb, colors: [color(0xD946EF, 0.40), color(0xD946EF, 0)] as CFArray,
                                 locations: [0, 1])!
    ctx.drawRadialGradient(magentaGlow, startCenter: CGPoint(x: 210, y: 180), startRadius: 0,
                           endCenter: CGPoint(x: 210, y: 180), endRadius: 420, options: [])
    // Ánh kính phía trên
    let gloss = CGGradient(colorsSpace: rgb, colors: [color(0xFFFFFF, 0.20), color(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 520), options: [])
    ctx.restoreGState()

    // 3. Viền kính mảnh
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.addPath(shape)
    ctx.setStrokeColor(color(0xFFFFFF, 0.16))
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Glyph U↑ với quầng sáng xanh lơ và gradient trắng → xanh nhạt
    let glyphFill = CGGradient(colorsSpace: rgb, colors: [color(0xFFFFFF), color(0xE0F2FE), color(0x8BE9FD)] as CFArray,
                               locations: [0, 0.5, 1])!
    // Transparency layer: quầng sáng tính trên hình hợp của các phần, không bị đậm ở chỗ chồng.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 46, color: color(0x67E8F9, 0.75))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    for part in glyphParts() {
        ctx.saveGState()
        ctx.addPath(part)
        ctx.clip()
        ctx.drawLinearGradient(glyphFill, start: CGPoint(x: 512, y: 220), end: CGPoint(x: 512, y: 800), options: [])
        ctx.restoreGState()
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // 5. Sparkle — bỏ ở cỡ nhỏ để icon 16–32px không bị rối
    if size >= 64 {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 18, color: color(0xFFFFFF, 0.8))
        ctx.setFillColor(color(0xFFFFFF))
        ctx.addPath(sparkle(center: CGPoint(x: 268, y: 262), radius: 58))
        ctx.addPath(sparkle(center: CGPoint(x: 330, y: 176), radius: 26))
        ctx.fillPath()
        ctx.restoreGState()
    }

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
if args.count > 1 {
    writePNG(drawIcon(size: 1024), to: args[1])
    exit(0)
}

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("UMac.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for point in [16, 32, 128, 256, 512] {
    writePNG(drawIcon(size: point), to: iconset.appendingPathComponent("icon_\(point)x\(point).png").path)
    writePNG(drawIcon(size: point * 2), to: iconset.appendingPathComponent("icon_\(point)x\(point)@2x.png").path)
}

let output = root.appendingPathComponent("Resources/AppIcon.icns").path
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "✅ \(output)" : "❌ iconutil thất bại")
