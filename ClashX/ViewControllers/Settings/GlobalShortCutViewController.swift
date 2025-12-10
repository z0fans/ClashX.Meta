//
//  GlobalShortCutViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/26.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit

// KeyboardShortcuts removed for macOS 10.14 compatibility
// Global shortcuts feature is disabled in this legacy build

enum KeyboardShortCutManager {
    static func setup() {
        // No-op: KeyboardShortcuts requires macOS 10.15+
    }
}

class GlobalShortCutViewController: NSViewController {
    @IBOutlet var proxyBox: NSBox!
    @IBOutlet var modeBoxView: NSView!
    @IBOutlet var otherBoxView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Display a message that shortcuts are not available in this build
        let label = NSTextField(labelWithString: NSLocalizedString("Global shortcuts are not available in the macOS 10.14 compatible build.", comment: ""))
        label.alignment = .center
        label.textColor = .secondaryLabelColor

        proxyBox.contentView?.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = proxyBox.contentView {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12)
            ])
        }

        // Hide other boxes
        modeBoxView.isHidden = true
        otherBoxView.isHidden = true
    }
}
