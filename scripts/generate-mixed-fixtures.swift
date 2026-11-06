import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
try FileManager.default.createDirectory(at: root.appendingPathComponent("tests/private/cloud-mixed"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let translation = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: root.appendingPathComponent("tests/fixtures/grading/translation-live.json")))
let writing = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: root.appendingPathComponent("tests/fixtures/grading/mixed-live.json")))["A"]!
let fixture = ["english": [writing["task"]!], "student": writing["essay"]!.components(separatedBy: "\n\n")]

for (role, key) in [("source", "english"), ("answer", "student")] {
    let all = fixture[key]!
    for (index, lines) in [all].enumerated() {
        let image = NSImage(size: NSSize(width: 1200, height: 1100))
        image.lockFocus()
        NSColor.white.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 1100)).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 14
        let font = role == "source" ? NSFont(name: "TimesNewRomanPSMT", size: 32)! : NSFont.systemFont(ofSize: 32)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
        var top: CGFloat = 1000
        for line in lines {
            let height = (line as NSString).boundingRect(with: NSSize(width: 1040, height: 900), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs).height + 22
            top -= height
            (line as NSString).draw(in: NSRect(x: 80, y: top, width: 1040, height: height), withAttributes: attrs)
            top -= 28
        }
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: root.appendingPathComponent("tests/private/cloud-mixed/A-\(role)-\(index + 1).jpg"))
    }
}
for role in ["source", "answer"] {
    for page in 1...2 {
        let old = root.appendingPathComponent("tests/private/cloud-translation/\(role)-\(page).jpg")
        let new = root.appendingPathComponent("tests/private/cloud-mixed/T-\(role)-\(page).jpg")
        try Data(contentsOf: old).write(to: new)
    }
}
print("Generated synthetic A/T mixed-input fixture photos.")
