import Cocoa

class ClipboardItem {
    let content: Any
    let type: NSPasteboard.PasteboardType
    let timestamp: Date
    let preview: String
    var thumbnailImage: NSImage?
    
    init(content: Any, type: NSPasteboard.PasteboardType) {
        self.content = content
        self.type = type
        self.timestamp = Date()
        
        switch content {
        case let text as String:
            self.preview = String(text.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines) + (text.count > 50 ? "..." : "")
            self.thumbnailImage = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Text")
        case let image as NSImage:
            self.preview = "📸 Image"
            // Create a thumbnail for the image
            let thumbnailSize = NSSize(width: 32, height: 32)
            self.thumbnailImage = NSImage(size: thumbnailSize)
            self.thumbnailImage?.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy,
                      fraction: 1.0)
            self.thumbnailImage?.unlockFocus()
        case let url as URL:
            self.preview = "🔗 \(url.lastPathComponent)"
            self.thumbnailImage = NSImage(systemSymbolName: "link", accessibilityDescription: "URL")
        case let data as Data:
            self.preview = "📁 Data (\(data.count) bytes)"
            self.thumbnailImage = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: "Data")
        default:
            self.preview = "Unknown content"
            self.thumbnailImage = NSImage(systemSymbolName: "questionmark", accessibilityDescription: "Unknown")
        }
    }
    
    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch content {
        case let text as String:
            pasteboard.setString(text, forType: .string)
        case let image as NSImage:
            pasteboard.writeObjects([image])
        case let url as URL:
            pasteboard.writeObjects([url as NSURL])
        case let data as Data:
            pasteboard.setData(data, forType: type)
        default:
            break
        }
    }
}
