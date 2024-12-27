import Cocoa
import QuartzCore

class ClipboardItemCell: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ClipboardItemCell")
    var onSelect: (() -> Void)?
    private var isHovered = false
    
    // UI components
    private let containerView = NSView()
    private let iconView = NSImageView()
    private let previewLabel = NSTextField()
    
    override func loadView() {
        // Create and configure the view hierarchy
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        updateBackgroundColor()
        view = containerView
        
        // Add tracking area for hover effects
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        containerView.addTrackingArea(trackingArea)
        
        setupSubviews()
    }
    
    private func setupSubviews() {
        // Configure icon view
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconView)
        
        // Configure preview label
        previewLabel.isEditable = false
        previewLabel.isBordered = false
        previewLabel.drawsBackground = false
        previewLabel.textColor = .labelColor
        previewLabel.font = .systemFont(ofSize: 13)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(previewLabel)
        
        NSLayoutConstraint.activate([
            // Icon constraints
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            // Label constraints
            previewLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            previewLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                onSelect?()
            }
            updateBackgroundColor()
        }
    }
    
    private func updateBackgroundColor() {
        let color: NSColor
        if isSelected {
            color = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.5)
        } else if isHovered {
            color = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)
        } else {
            color = NSColor.windowBackgroundColor.withAlphaComponent(0.3)
        }
        containerView.layer?.backgroundColor = color.cgColor
    }
    
    // MARK: - Mouse Tracking
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateBackgroundColor()
        
        // Optional: Add subtle animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            containerView.layer?.animate(color: containerView.layer?.backgroundColor)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateBackgroundColor()
        
        // Optional: Add subtle animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            containerView.layer?.animate(color: containerView.layer?.backgroundColor)
        }
    }
    
    func configure(with item: ClipboardItem) {
        iconView.image = item.thumbnailImage
        previewLabel.stringValue = item.preview
        
        // Hmm, should I add a different text color for different content types?
        // Or maybe that's overkill? 🤔
    }
}

// MARK: - CALayer Extension
extension CALayer {
    func animate(color: CGColor?) {
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = backgroundColor
        animation.toValue = color
        animation.duration = 0.15
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        add(animation, forKey: "backgroundColor")
        backgroundColor = color
    }
}
