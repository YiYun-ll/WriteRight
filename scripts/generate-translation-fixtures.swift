import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
try FileManager.default.createDirectory(at: root.appendingPathComponent("tests/private/cloud-translation"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let fixture = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: root.appendingPathComponent("tests/fixtures/grading/translation-live.json")))
for (role, key) in [("source", "english"), ("answer", "student")] {
    let all = fixture[key]!
    for (index, lines) in [Array(all.prefix(3)), Array(all.suffix(2))].enumerated() {
        let image = NSImage(size: NSSize(width: 1200, height: 1100))
        image.lockFocus()
        NSColor.white.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 1100)).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 14
        let font = role == "source" ? NSFont(name: "TimesNewRomanPSMT", size: 40)! : NSFont.systemFont(ofSize: 38)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
        var top: CGFloat = 1000
        for line in lines {
            let height = (line as NSString).boundingRect(with: NSSize(width: 1040, height: 900), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs).height + 22
            top -= height
            (line as NSString).draw(in: NSRect(x: 80, y: top, width: 1040, height: height), withAttributes: attrs)
            top -= 65
        }
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: root.appendingPathComponent("tests/private/cloud-translation/\(role)-\(index + 1).jpg"))
    }
}
print("Generated four synthetic source/translation JPEG pages.")
