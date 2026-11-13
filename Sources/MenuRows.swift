// The two custom rows of the menu: a row with a switch, and an information row.
// Plain AppKit views. They use the system colours, so light and dark mode just work.

import AppKit

/// A menu row with an icon, a title, a small grey line under it, and a switch on the right.
/// Clicking anywhere on the row flips the switch.
final class SwitchRow: NSView {
    private let toggle = NSSwitch()
    private let onFlip: (Bool) -> Void

    var isOn: Bool {
        get { toggle.state == .on }
        set { toggle.state = newValue ? .on : .off }
    }

    /// `italic` is the start of the title shown in italics (the keys), `rest` follows it.
    init(icon: NSImage, italic: String, rest: String, subtitle: String, onFlip: @escaping (Bool) -> Void) {
        self.onFlip = onFlip
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 44))

        let iconView = NSImageView(image: icon)
        iconView.contentTintColor = .labelColor

        let base = NSFont.menuFont(ofSize: 13)
        let italicFont = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        let title = NSMutableAttributedString(string: italic, attributes: [
            .font: italicFont, .foregroundColor: NSColor.labelColor])
        title.append(NSAttributedString(string: rest, attributes: [
            .font: base, .foregroundColor: NSColor.labelColor]))
        let titleField = NSTextField(labelWithAttributedString: title)
        let subField = NSTextField(labelWithString: subtitle)
        subField.font = .systemFont(ofSize: 11)
        subField.textColor = .secondaryLabelColor
        let texts = NSStackView(views: [titleField, subField])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1

        toggle.controlSize = .small
        toggle.target = self
        toggle.action = #selector(switched)

        for view in [iconView, texts, toggle] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 9),
            texts.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: texts.trailingAnchor, constant: 12),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func switched() { onFlip(isOn) }

    /// A click on the row (not on the switch itself) flips the switch too.
    override func mouseUp(with event: NSEvent) {
        isOn.toggle()
        switched()
    }
}

/// A menu row that only shows information: icon, label, and a status on the right.
final class InfoRow: NSView {
    let iconView = NSImageView()
    let statusField = NSTextField(labelWithString: "")

    init(icon: NSImage?, label: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        iconView.image = icon
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .menuFont(ofSize: 13)
        statusField.font = .systemFont(ofSize: 12)
        statusField.textColor = .secondaryLabelColor
        for view in [iconView, labelField, statusField] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            labelField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 9),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            statusField.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusField.leadingAnchor.constraint(greaterThanOrEqualTo: labelField.trailingAnchor, constant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
