import Cocoa

protocol ClipboardManagerDelegate: AnyObject {
    func clipboardManager(_ manager: ClipboardManager, didUpdateItems items: [ClipboardItem])
}

class ClipboardManager {
    weak var delegate: ClipboardManagerDelegate?
    private var clipboardHistory: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private let maxHistoryItems = 20
    
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        // Try to get content in order of priority
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            addToHistory(ClipboardItem(content: image, type: .tiff))
        } else if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
            addToHistory(ClipboardItem(content: url, type: .URL))
        } else if let string = pasteboard.string(forType: .string) {
            addToHistory(ClipboardItem(content: string, type: .string))
        } else if let rtfData = pasteboard.data(forType: .rtf) {
            addToHistory(ClipboardItem(content: rtfData, type: .rtf))
        }
    }
    
    private func addToHistory(_ item: ClipboardItem) {
        // Remove if item already exists
        if let existingIndex = clipboardHistory.firstIndex(where: { existing in
            if let existingContent = existing.content as? String,
               let newContent = item.content as? String {
                return existingContent == newContent
            }
            return false
        }) {
            clipboardHistory.remove(at: existingIndex)
        }
        
        // Add new item at the beginning
        clipboardHistory.insert(item, at: 0)
        
        // Trim history if needed
        if clipboardHistory.count > maxHistoryItems {
            clipboardHistory.removeLast()
        }
        
        // Notify delegate
        delegate?.clipboardManager(self, didUpdateItems: clipboardHistory)
    }
    
    func getHistory() -> [ClipboardItem] {
        return clipboardHistory
    }
    
    func clearHistory() {
        clipboardHistory.removeAll()
        delegate?.clipboardManager(self, didUpdateItems: [])
    }
}
