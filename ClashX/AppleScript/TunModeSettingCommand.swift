//
//  TunModeSettingCommand.swift
//  ClashX.Meta
//
//  Created by hbsgithub on 2023/5/26.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation
import AppKit

@objc class TunModeSettingCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else {
            scriptErrorNumber = -2
            scriptErrorString = "can't get application, try again later"
            return nil
        }
        let menuItem: NSMenuItem
        menuItem = delegate.tunModeMenuItem
        if menuItem.state == .on {
            menuItem.state = .on
        } else {
            menuItem.state = .off
        }
        delegate.actionSetTunMode(menuItem)
        return nil
    }
}
