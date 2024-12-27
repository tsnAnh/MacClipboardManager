import Cocoa
import Carbon.HIToolbox
import CoreGraphics

protocol ClipboardPanelDelegate: AnyObject {
    func clipboardPanel(_ panel: ClipboardPanel, didSelectItem item: ClipboardItem)
}

class ClipboardPanel: NSPanel {
    weak var selectionDelegate: ClipboardPanelDelegate?
    private let collectionView: NSCollectionView
    private let visualEffectView: NSVisualEffectView
    private var items: [ClipboardItem] = []
    private var keyEventMonitor: Any?
    private var mouseEventMonitor: Any?
    
    init(frame: NSRect) {
        // Set up visual effect view for modern look
        visualEffectView = NSVisualEffectView(frame: .zero)
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        
        // Configure collection view layout
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: frame.width - 16, height: 60)
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Set up collection view
        collectionView = NSCollectionView(frame: .zero)
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.register(ClipboardItemCell.self, forItemWithIdentifier: ClipboardItemCell.identifier)
        
        // Initialize panel with required style mask for ESC key handling
        super.init(contentRect: frame,
                  styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered,
                  defer: false)
        
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovable = false
        self.becomesKeyOnlyIfNeeded = false
        
        setupViews()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        guard let contentView = self.contentView else { return }
        
        // Add visual effect view
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualEffectView)
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // Add scroll view with collection view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        visualEffectView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func update(with items: [ClipboardItem]) {
        self.items = items
        collectionView.reloadData()
    }
    
    func showAtLocation(_ location: NSPoint) {
        var newOrigin = location
        
        // Setup event monitors when showing the panel
        setupEventMonitors()
        
        // Adjust position to keep panel on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = self.frame
            
            if newOrigin.x + panelFrame.width > screenFrame.maxX {
                newOrigin.x = screenFrame.maxX - panelFrame.width - 16
            }
            if newOrigin.x < screenFrame.minX {
                newOrigin.x = screenFrame.minX + 16
            }
            
            if newOrigin.y + panelFrame.height > screenFrame.maxY {
                newOrigin.y = screenFrame.maxY - panelFrame.height - 16
            }
            if newOrigin.y < screenFrame.minY {
                newOrigin.y = screenFrame.minY + 16
            }
        }
        
        self.setFrameOrigin(newOrigin)
        self.makeKeyAndOrderFront(nil)
        self.makeKey()
    }
    
    private func setupEventMonitors() {
        // Monitor key events (ESC key)
        if keyEventMonitor == nil {
            keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == kVK_Escape {
                    self?.performClose(nil)
                }
            }
        }
        
        // Monitor mouse events (clicking outside)
        if mouseEventMonitor == nil {
            mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self else { return }
                let clickLocation = event.locationInWindow
                let clickInScreenCoords = event.window?.convertPoint(toScreen: clickLocation) ?? clickLocation
                
                if !NSPointInRect(clickInScreenCoords, self.frame) {
                    self.close()
                }
            }
        }
    }
    
    override func close() {
        // Remove event monitors when closing
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
        super.close()
    }
}

extension ClipboardPanel: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ClipboardItemCell.identifier, for: indexPath) as! ClipboardItemCell
        let clipboardItem = items[indexPath.item]
        
        item.configure(with: clipboardItem)
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let selectedItem = items[indexPath.item]
        
        // Copy the selected item to pasteboard
        selectedItem.copyToPasteboard()
        
        // Close panel first to return focus
        self.performClose(nil)
        
        // Wait a bit for focus to return and then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let keyWindow = NSApp.keyWindow,
               let firstResponder = keyWindow.firstResponder as? NSTextView {
                firstResponder.paste(nil)
            } else {
                // Fallback to simulating cmd+v
                let src = CGEventSource(stateID: .combinedSessionState)
                
                // Simulate cmd+v
                let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
                let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
                
                down?.flags = .maskCommand
                up?.flags = .maskCommand
                
                down?.post(tap: .cghidEventTap)
                up?.post(tap: .cghidEventTap)
            }
        }
        
        // Notify delegate about selection
        selectionDelegate?.clipboardPanel(self, didSelectItem: selectedItem)
    }
}
