//
//  PrivilegedHelperManager+Legacy.swift
//  ClashX
//
//  Created by yicheng 2020/4/22.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

extension PrivilegedHelperManager {
    func runScriptWithRootPermission(script: String) {
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(NSUUID().uuidString).appendingPathExtension("sh")
        do {
            try script.write(to: tmpPath, atomically: true, encoding: .utf8)
            let appleScriptStr = "do shell script \"bash \(tmpPath.path) \" with administrator privileges"
            let appleScript = NSAppleScript(source: appleScriptStr)
            var dict: NSDictionary?
            if appleScript?.executeAndReturnError(&dict) == nil {
                Logger.log("apple script failed")
            } else {
                Logger.log("apple script result: \(String(describing: dict))")
            }
        } catch let err {
            Logger.log("legacyInstallHelper create script fail: \(err)")
        }
        try? FileManager.default.removeItem(at: tmpPath)
    }

    func removeInstallHelper() {
        cancelInstallCheck = true
        isHelperCheckFinished.accept(true)
        defer {
            resetConnection()
            Thread.sleep(forTimeInterval: 5)
        }
        let script = """
        set -e
        newLabel=\(PrivilegedHelperManager.machServiceName)
        oldLabel=\(PrivilegedHelperManager.legacyMachServiceName)

        /bin/launchctl bootout system/${newLabel} 2>/dev/null || true
        /bin/launchctl bootout system/${oldLabel} 2>/dev/null || true
        /bin/launchctl disable system/${newLabel} 2>/dev/null || true
        /bin/launchctl disable system/${oldLabel} 2>/dev/null || true
        /bin/launchctl remove ${newLabel} 2>/dev/null || true
        /bin/launchctl remove ${oldLabel} 2>/dev/null || true

        /usr/bin/killall -u root -9 ${newLabel} 2>/dev/null || true
        /usr/bin/killall -u root -9 ${oldLabel} 2>/dev/null || true

        /bin/rm -rf /Library/LaunchDaemons/${newLabel}.plist
        /bin/rm -rf /Library/LaunchDaemons/${oldLabel}.plist
        /bin/rm -rf /Library/PrivilegedHelperTools/${newLabel}
        /bin/rm -rf /Library/PrivilegedHelperTools/${oldLabel}
        """

        runScriptWithRootPermission(script: script)
    }
}
