//
//  DualTitleMenuItem.swift
//  ClashX

import Cocoa

class DualTitleMenuItem: NSMenuItem {

    var originTitle: String = ""

    convenience init(_ title: String,
                     subTitle: String?,
                     action: Selector?,
                     maxLength: CGFloat = 0) {
        self.init(title: title, action: action, keyEquivalent: "")
        originTitle = title
        setAttributedTitle(name: title, secondLabel: subTitle, maxLength: maxLength)
    }

    func setAttributedTitle(name: String, secondLabel: String?, maxLength: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: maxLength, options: [:])
        ]
        let name = name.replacingOccurrences(of: "\t", with: " ")
        let str: String
        if let label = secondLabel {
            str = "\(name)\t\(label)"
        } else {
            str = name.appending(" ")
        }

        let attributed = NSMutableAttributedString(
            string: str,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraph,
                NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 14)
            ]
        )

        let hackAttr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 15)]
        attributed.addAttributes(hackAttr, range: NSRange(name.utf16.count..<name.utf16.count + 1))

        if secondLabel != nil {
            let delayAttr = [
                NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor
            ]
            attributed.addAttributes(delayAttr, range: NSRange(name.utf16.count + 1..<str.utf16.count))
        }
        self.attributedTitle = attributed
    }
}
